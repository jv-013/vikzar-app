/// The Speech Provider Layer — Voice OS's exact counterpart to the
/// backend's Model Router (`functions/src/lib/ai/aiService.ts`'s
/// `routeToProvider`). Nothing in `RazConversationManager`,
/// `RazVoiceController`, or any widget ever constructs
/// `SpeechToTextRecognizer`/`FlutterTtsSynthesizer`/
/// `SherpaWakeWordEngine` directly — every one goes through
/// a `routeTo...()` function here, so replacing a provider later (a
/// different STT/TTS engine, a dedicated hotword SDK) is a new enum
/// case and a new class in this one file, never a change anywhere
/// upstream.
///
/// **RC2.1:** Default wake-word engine changed from `platform`
/// (continuous SpeechRecognizer loop) to `sherpa` (offline KWS SDK). 
/// The `platform` fallback is retained for development platforms 
/// where sherpa-onnx is unavailable (web).
library;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/raz_voice_option.dart';
import '../../domain/models/raz_voice_preset.dart';
import '../../domain/repositories/raz_speech_recognizer.dart';
import '../../domain/repositories/raz_speech_synthesizer.dart';
import '../../domain/repositories/raz_voice_permissions.dart';
import '../../domain/repositories/raz_wake_word_engine.dart';
import '../repositories/continuous_listening_wake_word_engine.dart';
import '../repositories/flutter_tts_synthesizer.dart';
import '../repositories/permission_handler_voice_permissions.dart';
import '../repositories/sherpa_wake_word_engine.dart';
import '../repositories/raz_voice_preset_mapper.dart';
import '../repositories/speech_to_text_recognizer.dart';

enum SpeechRecognizerProviderId { platform }

RazSpeechRecognizer routeToSpeechRecognizer([
  SpeechRecognizerProviderId preferred = SpeechRecognizerProviderId.platform,
]) {
  switch (preferred) {
    case SpeechRecognizerProviderId.platform:
      return SpeechToTextRecognizer();
  }
}

enum SpeechSynthesizerProviderId { platform }

RazSpeechSynthesizer routeToSpeechSynthesizer([
  SpeechSynthesizerProviderId preferred = SpeechSynthesizerProviderId.platform,
]) {
  switch (preferred) {
    case SpeechSynthesizerProviderId.platform:
      return FlutterTtsSynthesizer();
  }
}

enum WakeWordProviderId { platform, sherpa }

RazWakeWordEngine routeToWakeWordEngine([
  WakeWordProviderId preferred = WakeWordProviderId.sherpa,
  RazSpeechRecognizer? recognizer,
]) {
  switch (preferred) {
    case WakeWordProviderId.sherpa:
      return SherpaWakeWordEngine();
    case WakeWordProviderId.platform:
      return ContinuousListeningWakeWordEngine(recognizer ?? routeToSpeechRecognizer());
  }
}

/// Selects the appropriate wake-word engine for the current platform.
/// sherpa-onnx is used on Android/iOS/macOS/Windows.
WakeWordProviderId _bestWakeWordProvider() {
  if (kIsWeb) return WakeWordProviderId.platform;
  return WakeWordProviderId.sherpa;
}

final razSpeechRecognizerProvider = Provider<RazSpeechRecognizer>((ref) => routeToSpeechRecognizer());

final razSpeechSynthesizerProvider = Provider<RazSpeechSynthesizer>((ref) => routeToSpeechSynthesizer());

final razWakeWordEngineProvider = Provider<RazWakeWordEngine>((ref) {
  final preferred = _bestWakeWordProvider();
  return routeToWakeWordEngine(
    preferred,
    preferred == WakeWordProviderId.platform ? ref.watch(razSpeechRecognizerProvider) : null,
  );
});

final razVoicePermissionsProvider = Provider<RazVoicePermissions>((ref) {
  return PermissionHandlerVoicePermissions();
});

/// The device's installed voices, for Settings' voice picker. A
/// `FutureProvider` (not `autoDispose`) so navigating away from and
/// back to Settings doesn't re-query the platform channel every time —
/// voices installed on a device don't change within a single app
/// session in any way Vikzar needs to react to live.
final razAvailableVoicesProvider = FutureProvider<List<RazVoiceOption>>((ref) {
  return ref.watch(razSpeechSynthesizerProvider).availableVoices();
});

/// The product voice presets that are actually available on this device,
/// resolved from the raw platform voices. Only presets with confident
/// matches are included — never fakes availability.
final razAvailablePresetsProvider = FutureProvider<List<ResolvedVoicePreset>>((ref) async {
  final voices = await ref.watch(razAvailableVoicesProvider.future);
  return resolveVoicePresets(voices);
});
