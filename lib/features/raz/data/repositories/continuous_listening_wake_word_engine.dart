import 'dart:async';

import '../../domain/repositories/raz_speech_recognizer.dart';
import '../../domain/repositories/raz_wake_word_engine.dart';

/// The one real [RazWakeWordEngine] implementation today. Not a
/// dedicated hotword SDK — Vikzar has no such dependency, and none
/// should be silently added (see `RAZ_VOICE_ARCHITECTURE.md`). Instead:
/// repeated, bounded `speech_to_text` listening sessions, phrase-matched
/// against partial transcripts for "hey raz" and its known
/// near-homophones. This is a real platform capability, honestly
/// less accurate and more battery-hungry than a dedicated wake-word
/// model would be — exactly why this engine is foreground-only and
/// opt-in, never a background service.
///
/// Shares the *same* [RazSpeechRecognizer] instance command capture
/// uses (never a second concurrent microphone session) — [arm] is a
/// no-op whenever the recognizer is already busy.
class ContinuousListeningWakeWordEngine implements RazWakeWordEngine {
  ContinuousListeningWakeWordEngine(this._recognizer);

  final RazSpeechRecognizer _recognizer;
  final _detectedController = StreamController<void>.broadcast();
  StreamSubscription<String>? _partialSub;
  StreamSubscription<bool>? _listeningSub;
  bool _armed = false;
  bool _awaitingHandoff = false;

  /// Requires the "hey" prefix rather than matching bare "raz" — the
  /// concrete mitigation for ADR-091's own pre-documented phonetic-
  /// collision risk ("Raz" vs. "Red" in casual speech). A stray "red"
  /// in ordinary conversation never matches; only a "hey ___" pattern
  /// close to "hey raz" does.
  static const _wakePhrases = {'hey raz', 'hey ras', 'hey rad', 'a raz', 'hey res'};

  static const _listenWindow = Duration(seconds: 8);
  static const _pauseWindow = Duration(seconds: 3);

  @override
  Stream<void> get onWakeWordDetected => _detectedController.stream;

  @override
  bool get isArmed => _armed;

  @override
  Future<void> arm() async {
    if (_armed) return;
    _armed = true;
    _awaitingHandoff = false;
    _partialSub ??= _recognizer.partialResults.listen(_checkForWakePhrase);
    _listeningSub ??= _recognizer.listeningChanges.listen(_onListeningChanged);
    await _startCycle();
  }

  @override
  Future<void> disarm() async {
    _armed = false;
    await _partialSub?.cancel();
    await _listeningSub?.cancel();
    _partialSub = null;
    _listeningSub = null;
    await _recognizer.stop();
  }

  Future<void> _startCycle() async {
    if (!_armed || _awaitingHandoff || _recognizer.isListening) return;
    await _recognizer.listen(
      // Detection happens on partial transcripts (_checkForWakePhrase);
      // a completed cycle with no match just ends quietly and re-arms.
      onFinalResult: (_) {},
      listenFor: _listenWindow,
      pauseFor: _pauseWindow,
    );
  }

  void _onListeningChanged(bool listening) {
    if (!listening && _armed && !_awaitingHandoff) {
      unawaited(_startCycle());
    }
  }

  void _checkForWakePhrase(String transcript) {
    if (!_armed || _awaitingHandoff) return;
    final normalized = transcript.trim().toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '');
    if (_wakePhrases.any(normalized.contains)) {
      _awaitingHandoff = true;
      unawaited(_recognizer.stop());
      _detectedController.add(null);
    }
  }
}
