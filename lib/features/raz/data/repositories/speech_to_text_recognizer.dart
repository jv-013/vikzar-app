import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../domain/repositories/raz_speech_recognizer.dart';

/// Debug-only pipeline tracing (never prints in release — `debugPrint`
/// itself doesn't strip by build mode, so the [kDebugMode] guard is what
/// actually keeps this out of shipped logs). Kept permanently rather
/// than deleted post-investigation: the speech pipeline crosses a
/// platform channel into an on-device/cloud recognizer this codebase
/// doesn't control, exactly the kind of boundary that's cheap to trace
/// now and expensive to re-instrument blind the next time listening
/// silently produces nothing.
void _log(String message) {
  if (kDebugMode) debugPrint('[VIKZAR_SPEECH_DEBUG] $message');
}

/// The one real [RazSpeechRecognizer] implementation today — wraps the
/// platform's on-device speech recognizer via `speech_to_text`. Resolved
/// exclusively through `raz_speech_providers.dart`'s
/// `routeToSpeechRecognizer()`; nothing outside that router should
/// construct this class directly.
class SpeechToTextRecognizer implements RazSpeechRecognizer {
  SpeechToTextRecognizer([stt.SpeechToText? speech]) : _speech = speech ?? stt.SpeechToText();

  final stt.SpeechToText _speech;
  final _partialResultsController = StreamController<String>.broadcast();
  final _errorsController = StreamController<String>.broadcast();
  final _listeningChangesController = StreamController<bool>.broadcast();
  bool _initialized = false;

  @override
  Stream<String> get partialResults => _partialResultsController.stream;

  @override
  Stream<String> get errors => _errorsController.stream;

  @override
  Stream<bool> get listeningChanges => _listeningChangesController.stream;

  @override
  bool get isAvailable => _initialized;

  @override
  bool get isListening => _speech.isListening;

  @override
  Future<bool> initialize() async {
    if (_initialized) return true;
    _log('initialize() called');
    _initialized = await _speech.initialize(
      onError: (error) {
        _log('onError: errorMsg=${error.errorMsg} permanent=${error.permanent}');
        _errorsController.add(error.errorMsg);
      },
      onStatus: (status) {
        _log('onStatus: $status');
        if (status == 'listening') {
          _listeningChangesController.add(true);
        } else if (status == 'notListening' || status == 'done') {
          _listeningChangesController.add(false);
        }
      },
      debugLogging: kDebugMode,
    );
    _log('initialize() result=$_initialized');
    if (!_initialized) {
      _errorsController.add('Voice input is not available on this device.');
    }
    return _initialized;
  }

  @override
  Future<void> listen({
    required void Function(String text) onFinalResult,
    Duration? listenFor,
    Duration? pauseFor,
  }) async {
    _log('listen() called; isListening=${_speech.isListening} listenFor=$listenFor pauseFor=$pauseFor');
    if (_speech.isListening) return;
    if (!await initialize()) {
      _log('listen() aborted: initialize() returned false');
      return;
    }

    await _speech.listen(
      listenOptions: stt.SpeechListenOptions(listenFor: listenFor, pauseFor: pauseFor),
      onResult: (result) {
        _log(
          'onResult: words="${result.recognizedWords}" finalResult=${result.finalResult} '
          'confidence=${result.confidence}',
        );
        final text = result.recognizedWords.trim();
        if (text.isEmpty) return;
        _partialResultsController.add(text);
        if (result.finalResult) onFinalResult(text);
      },
      onSoundLevelChange: (level) => _log('onSoundLevelChange: $level'),
    );
    _log('listen() call returned (listening started)');
  }

  @override
  Future<void> stop() {
    _log('stop() called');
    return _speech.stop();
  }

  @override
  Future<void> cancel() {
    _log('cancel() called');
    return _speech.cancel();
  }
}
