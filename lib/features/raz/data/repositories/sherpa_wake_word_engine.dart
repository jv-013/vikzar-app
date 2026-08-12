import 'dart:async';
import 'package:flutter/foundation.dart';

import 'package:record/record.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart';

import '../../domain/repositories/raz_wake_word_engine.dart';

/// Foreground-only offline wake-word engine using sherpa-onnx.
/// Runs locally and listens for "Hey Raz".
class SherpaWakeWordEngine implements RazWakeWordEngine {
  final _detectedController = StreamController<void>.broadcast();
  final _errorsController = StreamController<String>.broadcast();
  
  final AudioRecorder _audioRecorder = AudioRecorder();
  StreamSubscription<List<int>>? _audioSubscription;
  
  KeywordSpotter? _spotter;
  OnlineStream? _sherpaStream;
  
  bool _armed = false;
  bool _listening = false;
  bool _disposed = false;

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
    if (_armed || _disposed) return;

    try {
      if (kDebugMode) debugPrint('[VIKZAR_WAKE] Initializing sherpa-onnx KeywordSpotter...');
      
      const config = KeywordSpotterConfig(
        model: OnlineModelConfig(
          transducer: OnlineTransducerModelConfig(
            encoder: 'assets/wake_word/sherpa-onnx-kws-zipformer-gigaspeech-3.3M-2024-01-01/encoder-epoch-12-avg-2-chunk-16-left-64.int8.onnx',
            decoder: 'assets/wake_word/sherpa-onnx-kws-zipformer-gigaspeech-3.3M-2024-01-01/decoder-epoch-12-avg-2-chunk-16-left-64.int8.onnx',
            joiner: 'assets/wake_word/sherpa-onnx-kws-zipformer-gigaspeech-3.3M-2024-01-01/joiner-epoch-12-avg-2-chunk-16-left-64.int8.onnx',
          ),
          tokens: 'assets/wake_word/sherpa-onnx-kws-zipformer-gigaspeech-3.3M-2024-01-01/tokens.txt',
          numThreads: 1,
          debug: false,
        ),
        keywordsFile: 'assets/wake_word/sherpa-onnx-kws-zipformer-gigaspeech-3.3M-2024-01-01/vikzar_keywords.txt',
      );

      _spotter = KeywordSpotter(config);
      _armed = true;
      await _startListening();
    } catch (e) {
      _armed = false;
      if (kDebugMode) debugPrint('[VIKZAR_WAKE] Failed to initialize sherpa-onnx: $e');
      _errorsController.add('"Hey Raz" is unavailable: $e');
    }
  }

  @override
  Future<void> disarm() async {
    _armed = false;
    await _stopListening();
    _destroySpotter();
  }

  @override
  Future<void> pause() async {
    if (!_armed || !_listening) return;
    await _stopListening();
  }

  @override
  Future<void> resume() async {
    if (!_armed || _listening || _disposed) return;
    await _startListening();
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    await disarm();
    await _detectedController.close();
    await _errorsController.close();
  }

  Future<void> _startListening() async {
    if (_listening || _spotter == null || _disposed) return;
    try {
      final hasPermission = await _audioRecorder.hasPermission();
      if (!hasPermission) {
        _errorsController.add('Microphone permission denied for wake word.');
        return;
      }

      final stream = await _audioRecorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
        ),
      );
      
      _sherpaStream = _spotter!.createStream();

      _audioSubscription = stream.listen((data) {
        if (!_listening || _spotter == null || _sherpaStream == null) return;
        
        // Convert Uint8List (pcm16) to Int16List then Float32List
        final dataView = ByteData.view(Uint8List.fromList(data).buffer);
        final float32List = Float32List(data.length ~/ 2);
        for (int i = 0; i < float32List.length; i++) {
          final int16Value = dataView.getInt16(i * 2, Endian.little);
          float32List[i] = int16Value / 32768.0;
        }

        _sherpaStream!.acceptWaveform(sampleRate: 16000, samples: float32List);
        
        while (_spotter!.isReady(_sherpaStream!)) {
          _spotter!.decode(_sherpaStream!);
        }
        
        final result = _spotter!.getResult(_sherpaStream!);
        if (result.keyword.isNotEmpty) {
          if (kDebugMode) debugPrint('[VIKZAR_WAKE] Keyword detected: ${result.keyword}');
          _detectedController.add(null);
          _spotter!.reset(_sherpaStream!);
        }
      });

      _listening = true;
    } catch (e) {
      if (kDebugMode) debugPrint('[VIKZAR_WAKE] startStream() failed: $e');
      _errorsController.add('"Hey Raz" microphone error.');
    }
  }

  Future<void> _stopListening() async {
    if (!_listening) return;
    try {
      await _audioSubscription?.cancel();
      _audioSubscription = null;
      await _audioRecorder.stop();
      _sherpaStream?.free();
      _sherpaStream = null;
    } catch (e) {
      if (kDebugMode) debugPrint('[VIKZAR_WAKE] stop() failed: $e');
    }
    _listening = false;
  }

  void _destroySpotter() {
    _spotter?.free();
    _spotter = null;
  }
}
