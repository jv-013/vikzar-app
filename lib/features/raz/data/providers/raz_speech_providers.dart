/// The Speech Provider Layer — Voice OS's exact counterpart to the
/// backend's Model Router (`functions/src/lib/ai/aiService.ts`'s
/// `routeToProvider`). Nothing in `RazConversationManager`,
/// `RazVoiceController`, or any widget ever constructs
/// `SpeechToTextRecognizer`/`FlutterTtsSynthesizer`/
/// `ContinuousListeningWakeWordEngine` directly — every one goes through
/// a `routeTo...()` function here, so replacing a provider later (a
/// different STT/TTS engine, a dedicated hotword SDK) is a new enum
/// case and a new class in this one file, never a change anywhere
/// upstream.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/raz_voice_option.dart';
import '../../domain/repositories/raz_speech_recognizer.dart';
import '../../domain/repositories/raz_speech_synthesizer.dart';
import '../../domain/repositories/raz_voice_permissions.dart';
import '../../domain/repositories/raz_wake_word_engine.dart';
import '../repositories/continuous_listening_wake_word_engine.dart';
import '../repositories/flutter_tts_synthesizer.dart';
import '../repositories/permission_handler_voice_permissions.dart';
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

/// `porcupine` is named deliberately, not invented: Picovoice Porcupine
/// is a real, existing dedicated wake-word SDK — the obvious next
/// provider if this app ever needs better-than-continuous-STT wake-word
/// accuracy or true background listening. It is **not** a dependency of
/// this app and nothing behind this case is built — the same "named but
/// not yet registered" pattern `aiService.ts`'s `ModelProviderId` already
/// uses for `"claude"`/`"openai"`/`"local"`.
enum WakeWordProviderId { platform, porcupine }

RazWakeWordEngine routeToWakeWordEngine([
  WakeWordProviderId preferred = WakeWordProviderId.platform,
  RazSpeechRecognizer? recognizer,
]) {
  switch (preferred) {
    case WakeWordProviderId.platform:
      return ContinuousListeningWakeWordEngine(recognizer ?? routeToSpeechRecognizer());
    case WakeWordProviderId.porcupine:
      throw UnimplementedError(
        'No wake-word provider registered for "porcupine" yet — only '
        '"platform" (continuous on-device speech recognition) is '
        'available today. Add a class implementing RazWakeWordEngine '
        'wrapping the Porcupine SDK and a new case here to register '
        'one; nothing above this file needs to change.',
      );
  }
}

final razSpeechRecognizerProvider = Provider<RazSpeechRecognizer>((ref) => routeToSpeechRecognizer());

final razSpeechSynthesizerProvider = Provider<RazSpeechSynthesizer>((ref) => routeToSpeechSynthesizer());

final razWakeWordEngineProvider = Provider<RazWakeWordEngine>((ref) {
  return routeToWakeWordEngine(WakeWordProviderId.platform, ref.watch(razSpeechRecognizerProvider));
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
