import 'dart:async';

import '../../domain/models/raz_voice_control_signal.dart';
import '../../domain/models/raz_voice_state.dart';
import '../../domain/repositories/raz_speech_recognizer.dart';
import '../../domain/repositories/raz_speech_synthesizer.dart';
import '../../domain/repositories/raz_voice_permissions.dart';
import '../../domain/repositories/raz_wake_word_engine.dart';

/// The real orchestration brain behind Voice OS — a plain Dart class,
/// deliberately **not** a Riverpod `Notifier` itself, so it stays
/// testable with simple constructor injection and has no Riverpod
/// dependency of its own. `RazVoiceController` is the thin `Notifier`
/// shell that owns one of these and forwards state changes from into
/// `ref`-watchable `RazVoiceState`.
///
/// **RC2.1 — Audio Session Ownership:**
/// Implements a strict single-owner protocol for the microphone:
///   1. Before STT starts → pause wake-word engine.
///   2. After STT ends + question submitted → enter thinking.
///   3. Before TTS starts → ensure wake-word is paused.
///   4. After TTS completes → resume wake-word engine (if armed).
///
/// No simultaneous microphone sessions. No duplicate callbacks.
/// No repeated recognizer loops. No system beep loops.
class RazConversationManager {
  RazConversationManager({
    required this.recognizer,
    required this.synthesizer,
    required this.wakeWordEngine,
    required this.permissions,
    required this.askRaz,
    required this.onStateChanged,
  }) {
    _wakeWordSub = wakeWordEngine.onWakeWordDetected.listen((_) {
      // Wake word detected → pause the engine, then start listening.
      // The pause ensures no mic contention with speech_to_text.
      unawaited(_handleWakeWordDetected());
    });
    _wakeWordErrorSub = wakeWordEngine.errors.listen((error) {
      _emit((s) => s.copyWith(lastError: error, wakeWordArmed: false, wakeWordListening: false));
    });
  }

  final RazSpeechRecognizer recognizer;
  final RazSpeechSynthesizer synthesizer;
  final RazWakeWordEngine wakeWordEngine;
  final RazVoicePermissions permissions;

  /// The *only* path to an answer — always `RazConversationController
  /// .ask()` in practice, injected here so this class never imports
  /// Riverpod or knows a `RazAudience` exists.
  final Future<String?> Function(
    String question, {
    required void Function(String sentence) onSentence,
  })
  askRaz;

  final void Function(RazVoiceState state) onStateChanged;

  static const _thinkingLabel = "Checking your data…";

  StreamSubscription<void>? _wakeWordSub;
  StreamSubscription<String>? _wakeWordErrorSub;
  StreamSubscription<String>? _partialSub;
  RazVoiceState _state = const RazVoiceState();
  bool _askInFlight = false;
  int _askGeneration = 0;

  RazVoiceState get state => _state;

  void _emit(RazVoiceState Function(RazVoiceState) transform) {
    _state = transform(_state);
    onStateChanged(_state);
  }

  /// Handles wake-word detection: pause the engine, then start listening.
  Future<void> _handleWakeWordDetected() async {
    await wakeWordEngine.pause();
    _emit((s) => s.copyWith(wakeWordListening: false));
    await startListening();
  }

  /// Starts one push-to-talk (or wake-word-triggered) listen session.
  /// Checks/requests microphone permission first — a real denied or
  /// permanently-denied state is surfaced, never silently swallowed.
  ///
  /// **RC2.1:** Pauses wake-word engine before starting STT to prevent
  /// microphone contention.
  Future<void> startListening() async {
    if (_state.isListening) return;

    final status = await permissions.request();
    if (status != RazPermissionStatus.granted) {
      _emit(
        (s) => s.copyWith(
          permissionStatus: status,
          lastError: switch (status) {
            RazPermissionStatus.permanentlyDenied =>
              "Microphone access is off. Enable it in Settings to talk to RAZ.",
            RazPermissionStatus.unsupported => "Voice isn't available on this platform yet.",
            RazPermissionStatus.denied || RazPermissionStatus.granted =>
              "RAZ needs microphone access to hear you.",
          },
        ),
      );
      return;
    }

    // Pause wake-word engine before starting STT — single mic owner.
    if (_state.wakeWordArmed) {
      await wakeWordEngine.pause();
      _emit((s) => s.copyWith(wakeWordListening: false));
    }

    _emit(
      (s) => s.copyWith(
        isListening: true,
        permissionStatus: status,
        captionText: '',
        clearError: true,
      ),
    );

    _partialSub = recognizer.partialResults.listen((text) {
      _emit((s) => s.copyWith(captionText: text));
    });

    await recognizer.listen(
      onFinalResult: (text) => unawaited(_handleTranscript(text)),
      listenFor: const Duration(seconds: 20),
      pauseFor: const Duration(seconds: 3),
    );
  }

  Future<void> stopListening() async {
    await recognizer.stop();
    await _partialSub?.cancel();
    _partialSub = null;
    _emit((s) => s.copyWith(isListening: false));

    // Resume wake-word if armed and nothing else is happening
    if (_state.wakeWordArmed && !_askInFlight && !_state.isSpeaking) {
      await _resumeWakeWord();
    }
  }

  Future<void> _handleTranscript(String text) async {
    await _partialSub?.cancel();
    _partialSub = null;
    _emit((s) => s.copyWith(isListening: false, captionText: text));

    final signal = classifyVoiceTranscript(
      text,
      isSpeaking: _state.isSpeaking,
      askInFlight: _askInFlight,
    );

    switch (signal) {
      case RazVoiceControlSignal.stopSpeaking:
        await stopSpeaking();
      case RazVoiceControlSignal.cancelPending:
        _askGeneration++;
        _askInFlight = false;
        _emit((s) => s.copyWith(isThinking: false));
        await _ask(text);
      case RazVoiceControlSignal.ignore:
        // Nothing to do — resume wake word if armed
        if (_state.wakeWordArmed) await _resumeWakeWord();
      case RazVoiceControlSignal.forward:
        await _ask(text);
    }
  }

  /// Speaks the answer sentence-by-sentence as it streams in.
  ///
  /// **RC2.1:** Wake-word engine stays paused during TTS to prevent
  /// the microphone from picking up RAZ's own voice.
  Future<void> _ask(String question) async {
    final generation = ++_askGeneration;
    _askInFlight = true;
    _emit((s) => s.copyWith(isThinking: true, thinkingLabel: _thinkingLabel));

    var speechChain = Future<void>.value();
    var startedSpeaking = false;

    await askRaz(
      question,
      onSentence: (sentence) {
        if (generation != _askGeneration) return;
        if (!startedSpeaking) {
          startedSpeaking = true;
          speechChain = synthesizer.stop().then((_) {
            if (generation != _askGeneration) return Future<void>.value();
            _emit((s) => s.copyWith(isThinking: false, thinkingLabel: '', isSpeaking: true));
            return synthesizer.speakSentence(sentence);
          });
        } else {
          speechChain = speechChain.then((_) {
            if (generation != _askGeneration) return Future<void>.value();
            return synthesizer.speakSentence(sentence);
          });
        }
      },
    );

    if (generation != _askGeneration) return;
    _askInFlight = false;
    await speechChain;
    if (generation == _askGeneration) {
      _emit((s) => s.copyWith(isThinking: false, thinkingLabel: '', isSpeaking: false));
      // TTS complete — resume wake word if armed
      if (_state.wakeWordArmed) await _resumeWakeWord();
    }
  }

  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    // Pause wake word during TTS
    if (_state.wakeWordArmed) {
      await wakeWordEngine.pause();
      _emit((s) => s.copyWith(wakeWordListening: false));
    }
    _emit((s) => s.copyWith(isSpeaking: true));
    await synthesizer.speak(text);
    _emit((s) => s.copyWith(isSpeaking: false));
    // Resume wake word after TTS
    if (_state.wakeWordArmed) await _resumeWakeWord();
  }

  Future<void> stopSpeaking() async {
    await synthesizer.stop();
    _emit((s) => s.copyWith(isSpeaking: false));
    // Resume wake word after stopping TTS
    if (_state.wakeWordArmed) await _resumeWakeWord();
  }

  Future<void> replay(String text) => speak(text);

  Future<void> armWakeWord() async {
    if (_state.wakeWordArmed) return;
    _emit((s) => s.copyWith(wakeWordArmed: true));
    await wakeWordEngine.arm();
    // Only mark as listening if arm succeeded (engine might report error)
    if (wakeWordEngine.isArmed) {
      _emit((s) => s.copyWith(wakeWordListening: wakeWordEngine.isListening));
    } else {
      _emit((s) => s.copyWith(wakeWordArmed: false));
    }
  }

  Future<void> disarmWakeWord() async {
    _emit((s) => s.copyWith(wakeWordArmed: false, wakeWordListening: false));
    await wakeWordEngine.disarm();
  }

  /// Resumes wake-word detection — only called when nothing else is
  /// using the microphone.
  Future<void> _resumeWakeWord() async {
    if (!_state.wakeWordArmed || _state.isListening || _state.isSpeaking) return;
    await wakeWordEngine.resume();
    _emit((s) => s.copyWith(wakeWordListening: wakeWordEngine.isListening));
  }

  void dispose() {
    _wakeWordSub?.cancel();
    _wakeWordErrorSub?.cancel();
    _partialSub?.cancel();
    if (_state.isListening) unawaited(recognizer.stop());
    if (_state.isSpeaking) unawaited(synthesizer.stop());
    if (_state.wakeWordArmed) unawaited(wakeWordEngine.disarm());
    unawaited(wakeWordEngine.dispose());
  }
}
