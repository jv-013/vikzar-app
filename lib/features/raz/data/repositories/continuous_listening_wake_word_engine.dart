import 'dart:async';

import '../../domain/repositories/raz_speech_recognizer.dart';
import '../../domain/repositories/raz_wake_word_engine.dart';

/// **Legacy — retained as a fallback, no longer the default.**
///
/// The original wake-word implementation that misused Android's
/// SpeechRecognizer for continuous detection. This caused repeated
/// system beep sounds and unreliable wake-word detection on real
/// Android devices. Replaced by `SherpaWakeWordEngine` as the
/// default in RC2.1.
///
/// Kept for platforms where sherpa-onnx is unavailable (e.g., web),
/// but should not be used in production Android/iOS builds.
class ContinuousListeningWakeWordEngine implements RazWakeWordEngine {
  ContinuousListeningWakeWordEngine(this._recognizer);

  final RazSpeechRecognizer _recognizer;
  final _detectedController = StreamController<void>.broadcast();
  final _errorsController = StreamController<String>.broadcast();
  StreamSubscription<String>? _partialSub;
  StreamSubscription<bool>? _listeningSub;
  bool _armed = false;
  bool _listening = false;
  bool _awaitingHandoff = false;

  static const _wakePhrases = {'hey raz', 'hey ras', 'hey rad', 'a raz', 'hey res'};

  static const _listenWindow = Duration(seconds: 8);
  static const _pauseWindow = Duration(seconds: 3);

  @override
  Stream<void> get onWakeWordDetected => _detectedController.stream;

  @override
  Stream<String> get errors => _errorsController.stream;

  @override
  bool get isArmed => _armed;

  @override
  bool get isListening => _listening;

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
    _listening = false;
    await _partialSub?.cancel();
    await _listeningSub?.cancel();
    _partialSub = null;
    _listeningSub = null;
    await _recognizer.stop();
  }

  @override
  Future<void> pause() async {
    if (!_armed || !_listening) return;
    _listening = false;
    await _recognizer.stop();
  }

  @override
  Future<void> resume() async {
    if (!_armed || _listening) return;
    await _startCycle();
  }

  @override
  Future<void> dispose() async {
    await disarm();
    await _detectedController.close();
    await _errorsController.close();
  }

  Future<void> _startCycle() async {
    if (!_armed || _awaitingHandoff || _recognizer.isListening) return;
    _listening = true;
    await _recognizer.listen(
      onFinalResult: (_) {},
      listenFor: _listenWindow,
      pauseFor: _pauseWindow,
    );
  }

  void _onListeningChanged(bool listening) {
    _listening = listening;
    if (!listening && _armed && !_awaitingHandoff) {
      unawaited(_startCycle());
    }
  }

  void _checkForWakePhrase(String transcript) {
    if (!_armed || _awaitingHandoff) return;
    final normalized = transcript.trim().toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '');
    if (_wakePhrases.any(normalized.contains)) {
      _awaitingHandoff = true;
      _listening = false;
      unawaited(_recognizer.stop());
      _detectedController.add(null);
    }
  }
}
