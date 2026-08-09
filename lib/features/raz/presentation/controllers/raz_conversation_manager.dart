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
/// shell that owns one of these and forwards its state into
/// `ref`-watchable `RazVoiceState`.
///
/// Kept deliberately separate from `RazVoiceController` (not folded in,
/// even though today's responsibilities are modest) because this is the
/// class designed to grow into coordinating push-to-talk, foreground
/// wake word, multi-turn conversations, future hardware voice commands,
/// interruption, and context continuity — optimizing for where Vikzar's
/// voice surface is going, not just what this phase needs.
///
/// **Never bypasses RazEngine.** [askRaz] is the *only* way this class
/// ever gets an answer — it never talks to Cloud Functions, Gemini, or
/// anything else directly, and the control-word matcher
/// ([classifyVoiceTranscript]) only ever decides *whether* to forward a
/// transcript to [askRaz], never answers anything itself.
///
/// **Honest scope on interruption:** "barge-in" here means *tap to
/// interrupt* ([stopSpeaking]), not detecting spoken "stop" while RAZ is
/// simultaneously speaking — this app has no echo-cancelled full-duplex
/// audio path (a phone's own speaker being picked back up by its own
/// mic without echo cancellation is a genuine hardware-dependent
/// problem, not something to fake). Spoken "stop"/"wait"/"actually" are
/// recognized at the *next* listen session (a wake-word re-trigger, or
/// the user tapping to talk again), not mid-utterance. See
/// `RAZ_VOICE_ARCHITECTURE.md`.
class RazConversationManager {
  RazConversationManager({
    required this.recognizer,
    required this.synthesizer,
    required this.wakeWordEngine,
    required this.permissions,
    required this.askRaz,
    required this.onStateChanged,
  }) {
    _wakeWordSub = wakeWordEngine.onWakeWordDetected.listen((_) => unawaited(startListening()));
  }

  final RazSpeechRecognizer recognizer;
  final RazSpeechSynthesizer synthesizer;
  final RazWakeWordEngine wakeWordEngine;
  final RazVoicePermissions permissions;

  /// The *only* path to an answer — always `RazConversationController
  /// .ask()` in practice, injected here so this class never imports
  /// Riverpod or knows a `RazAudience` exists. [onSentence] fires once
  /// per complete sentence as the answer streams in, letting this class
  /// start speaking before the full answer has finished generating —
  /// see [_ask].
  final Future<String?> Function(
    String question, {
    required void Function(String sentence) onSentence,
  })
  askRaz;

  final void Function(RazVoiceState state) onStateChanged;

  /// A single real, honest status while RAZ gathers this athlete's
  /// context and reasons about it, before the model call even starts —
  /// not a rotating set of phrases invented to look busy (see
  /// `RazVoiceState.thinkingLabel`'s own doc comment).
  static const _thinkingLabel = "Checking your data…";

  StreamSubscription<void>? _wakeWordSub;
  StreamSubscription<String>? _partialSub;
  RazVoiceState _state = const RazVoiceState();
  bool _askInFlight = false;
  int _askGeneration = 0;

  RazVoiceState get state => _state;

  void _emit(RazVoiceState Function(RazVoiceState) transform) {
    _state = transform(_state);
    onStateChanged(_state);
  }

  /// Starts one push-to-talk (or wake-word-triggered) listen session.
  /// Checks/requests microphone permission first — a real denied or
  /// permanently-denied state is surfaced, never silently swallowed.
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

    _emit(
      (s) => s.copyWith(
        isListening: true,
        permissionStatus: status,
        captionText: '',
        clearError: true,
      ),
    );
    // Live captions — see this subscription's own scoping note: it only
    // ever runs for the duration of *this* listen session. The wake-word
    // engine's own background cycles share the same recognizer/stream
    // but never overlap with this one (`ContinuousListeningWakeWordEngine`
    // refuses to start a cycle while `recognizer.isListening` is already
    // true), so this never shows a stray "hey raz" caption from
    // background wake-word detection.
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
        // Invalidates the in-flight _ask()'s continuation (see below) —
        // its network call still completes, but the stale answer is
        // discarded rather than spoken, and the new question is asked
        // immediately.
        _askGeneration++;
        _askInFlight = false;
        _emit((s) => s.copyWith(isThinking: false));
        await _ask(text);
      case RazVoiceControlSignal.ignore:
        break;
      case RazVoiceControlSignal.forward:
        await _ask(text);
    }
  }

  /// Speaks the answer sentence-by-sentence as it streams in, rather
  /// than waiting for the complete text — the moment the first sentence
  /// is recognized, this stops any prior utterance once (the same
  /// barge-in guarantee [speak] gives a complete answer) and starts
  /// speaking immediately; every sentence after that is enqueued on
  /// [synthesizer] in arrival order via [_speechChain] so playback stays
  /// naturally paced without ever blocking the network stream that's
  /// still bringing in the rest of the answer.
  Future<void> _ask(String question) async {
    final generation = ++_askGeneration;
    _askInFlight = true;
    _emit((s) => s.copyWith(isThinking: true, thinkingLabel: _thinkingLabel));

    var speechChain = Future<void>.value();
    var startedSpeaking = false;

    await askRaz(
      question,
      onSentence: (sentence) {
        if (generation != _askGeneration) return; // superseded by "actually..."
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

    if (generation != _askGeneration) return; // superseded by "actually..."
    _askInFlight = false;
    await speechChain; // let whatever's already queued finish naturally
    if (generation == _askGeneration) {
      _emit((s) => s.copyWith(isThinking: false, thinkingLabel: '', isSpeaking: false));
    }
  }

  // Extension point (not implemented): a future intent-classification
  // step could inspect the transcript in `_handleTranscript` before it
  // reaches `_ask` and route recognized device/session commands (e.g.
  // "Raz, start my session", "Raz, check Pod battery") to a not-yet-
  // built command dispatcher instead of `askRaz`. `lib/features/
  // devices/` is empty today — there is nothing real to route such a
  // command to yet, so every spoken utterance is treated as a
  // conversational question, exactly like today. This is this class's
  // stated future home for that responsibility (see class doc comment).

  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    _emit((s) => s.copyWith(isSpeaking: true));
    await synthesizer.speak(text);
    _emit((s) => s.copyWith(isSpeaking: false));
  }

  /// The real, working "stop talking over me" — a tap, not spoken
  /// barge-in (see class doc comment).
  Future<void> stopSpeaking() async {
    await synthesizer.stop();
    _emit((s) => s.copyWith(isSpeaking: false));
  }

  /// Re-speaks already-known text (the caller supplies the last RAZ
  /// response — this class holds no conversation history of its own,
  /// that remains `RazConversationController`'s job).
  Future<void> replay(String text) => speak(text);

  Future<void> armWakeWord() async {
    if (_state.wakeWordArmed) return;
    _emit((s) => s.copyWith(wakeWordArmed: true));
    await wakeWordEngine.arm();
  }

  Future<void> disarmWakeWord() async {
    _emit((s) => s.copyWith(wakeWordArmed: false));
    await wakeWordEngine.disarm();
  }

  /// Mirrors `RazVoiceController.didChangeAppLifecycleState`'s background
  /// teardown — this is not a redundant safety net, it is the *only*
  /// teardown path when this manager is disposed other than by the app
  /// backgrounding (e.g. a future `ref.invalidate` on the owning
  /// provider). Nothing that [startListening]/[speak]/[armWakeWord]
  /// started should be left running past disposal.
  void dispose() {
    _wakeWordSub?.cancel();
    _partialSub?.cancel();
    if (_state.isListening) unawaited(recognizer.stop());
    if (_state.isSpeaking) unawaited(synthesizer.stop());
    if (_state.wakeWordArmed) unawaited(wakeWordEngine.disarm());
  }
}
