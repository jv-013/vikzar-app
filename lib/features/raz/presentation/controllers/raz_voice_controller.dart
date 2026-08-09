import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/providers/current_uid_provider.dart';
import '../../data/providers/raz_speech_providers.dart';
import '../../domain/models/raz_voice_settings.dart';
import '../../domain/models/raz_voice_state.dart';
import '../../domain/repositories/raz_repository.dart';
import 'raz_conversation_controller.dart';
import 'raz_conversation_manager.dart';
import 'raz_voice_settings_controller.dart';

export '../../domain/models/raz_voice_state.dart' show RazVoiceState;

/// Voice as another interface to the same intelligence — never a
/// separate pipeline. The microphone only ever produces text that flows
/// through the exact same [RazConversationController.ask] path a typed
/// question would; speech output only ever reads back the exact same
/// `RazResponse.text` a typed answer already shows on screen.
///
/// A thin Riverpod `Notifier` shell — all real orchestration logic
/// lives in [RazConversationManager], which this class constructs once
/// (with dependencies resolved through the Speech Provider Layer, never
/// constructed directly) and forwards state changes from into
/// `ref`-watchable [RazVoiceState]. Family-scoped over [RazAudience],
/// matching `razConversationControllerProvider`, so player and coach
/// voice sessions never share state.
class RazVoiceController extends Notifier<RazVoiceState> with WidgetsBindingObserver {
  RazVoiceController(this.audience);

  final RazAudience audience;
  late final RazConversationManager _manager;

  @override
  RazVoiceState build() {
    // Rebuilds fresh (dropping any prior state/manager) whenever the
    // signed-in user changes — without this, `RazAudience` alone
    // (2 values) means Player A's voice session state could otherwise be
    // reused for Player B on a shared device after sign-out/sign-in.
    ref.watch(currentUidProvider);
    final synthesizer = ref.read(razSpeechSynthesizerProvider);
    _manager = RazConversationManager(
      recognizer: ref.read(razSpeechRecognizerProvider),
      synthesizer: synthesizer,
      wakeWordEngine: ref.read(razWakeWordEngineProvider),
      permissions: ref.read(razVoicePermissionsProvider),
      askRaz: (question, {required onSentence}) async {
        final response = await ref
            .read(razConversationControllerProvider(audience).notifier)
            .ask(question, mode: RazConversationMode.voice, onSentence: onSentence);
        return response?.text;
      },
      onStateChanged: (voiceState) => state = voiceState,
    );

    // Applies the user's speech-rate/volume/voice preference immediately
    // on build, and again whenever changed in Settings — the shared
    // synthesizer instance means this applies to conversational speech,
    // Read Aloud, and Daily Brief narration identically, with no
    // per-surface wiring.
    void applyPreferences(RazVoiceSettings settings) {
      synthesizer.setRate(settings.speechRate);
      synthesizer.setVolume(settings.speechVolume);
    }

    // Voice selection needs a fresh `availableVoices()` lookup (the
    // stored preference is just an engine identifier — see
    // `RazVoiceSettings.voiceName`'s own doc comment on why), so it's
    // async and kept separate from the synchronous rate/volume applies
    // above. Silently does nothing if the saved voice is no longer
    // installed, matching `RazSpeechSynthesizer.setVoice`'s own
    // graceful-no-op contract.
    Future<void> applyVoice(String? voiceName) async {
      if (voiceName == null) return;
      final voices = await synthesizer.availableVoices();
      final match = voices.where((v) => v.name == voiceName).firstOrNull;
      if (match != null) await synthesizer.setVoice(match);
    }

    applyPreferences(ref.read(razVoiceSettingsControllerProvider));
    unawaited(applyVoice(ref.read(razVoiceSettingsControllerProvider).voiceName));
    ref.listen(razVoiceSettingsControllerProvider, (previous, next) {
      if (previous?.speechRate != next.speechRate || previous?.speechVolume != next.speechVolume) {
        applyPreferences(next);
      }
      if (previous?.voiceName != next.voiceName) {
        unawaited(applyVoice(next.voiceName));
      }
      // Without this, toggling "Hey Raz" off in Settings only persisted
      // the preference — it never reached the engine actually running
      // the mic, so wake-word listening kept cycling until the next
      // app-background/foreground transition.
      if (previous?.wakeWordEnabled != next.wakeWordEnabled) {
        unawaited(setWakeWordEnabled(next.wakeWordEnabled));
      }
    });

    WidgetsBinding.instance.addObserver(this);
    ref.onDispose(() {
      WidgetsBinding.instance.removeObserver(this);
      _manager.dispose();
    });

    return _manager.state;
  }

  // The SDK's own parameter name is `state`, which would shadow
  // Notifier's own `state` field if renamed to match.
  @override
  // ignore: avoid_renaming_method_parameters
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    final wakeWordEnabled = ref.read(razVoiceSettingsControllerProvider).wakeWordEnabled;

    switch (lifecycleState) {
      case AppLifecycleState.resumed:
        if (wakeWordEnabled) _manager.armWakeWord();
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        // The microphone must never stay active once Vikzar leaves the
        // foreground — this runs regardless of the wake-word setting,
        // since push-to-talk sessions can be mid-listen when the app
        // backgrounds too.
        unawaited(_manager.stopListening());
        if (wakeWordEnabled) _manager.disarmWakeWord();
    }
  }

  /// Starts listening; a no-op if already listening. Real microphone
  /// permission is checked/requested before the platform recognizer is
  /// ever touched.
  Future<void> startListening() => _manager.startListening();

  Future<void> stopListening() => _manager.stopListening();

  Future<void> speak(String text) => _manager.speak(text);

  /// The real, working "stop talking over me" — call this from a tap on
  /// the mic/pulse while [RazVoiceState.isSpeaking] is true.
  Future<void> stopSpeaking() => _manager.stopSpeaking();

  Future<void> replay(String text) => _manager.replay(text);

  /// Applies the user's wake-word Settings toggle immediately, without
  /// waiting for the next app-lifecycle transition.
  Future<void> setWakeWordEnabled(bool enabled) {
    return enabled ? _manager.armWakeWord() : _manager.disarmWakeWord();
  }
}

final razVoiceControllerProvider = NotifierProvider.autoDispose
    .family<RazVoiceController, RazVoiceState, RazAudience>(
      RazVoiceController.new,
    );
