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
/// **RC2.1:** The former `voiceSettings.enabled` gate has been removed —
/// push-to-talk and TTS are always available. Only the wake-word toggle
/// (`wakeWordEnabled`) remains as a separate opt-in.
class RazVoiceController extends Notifier<RazVoiceState> with WidgetsBindingObserver {
  RazVoiceController(this.audience);

  final RazAudience audience;
  late final RazConversationManager _manager;

  @override
  RazVoiceState build() {
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

    void applyPreferences(RazVoiceSettings settings) {
      synthesizer.setRate(settings.speechRate);
      synthesizer.setVolume(settings.speechVolume);
    }

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
        unawaited(_manager.stopListening());
        if (wakeWordEnabled) _manager.disarmWakeWord();
    }
  }

  Future<void> startListening() => _manager.startListening();

  Future<void> stopListening() => _manager.stopListening();

  Future<void> speak(String text) => _manager.speak(text);

  Future<void> stopSpeaking() => _manager.stopSpeaking();

  Future<void> replay(String text) => _manager.replay(text);

  Future<void> setWakeWordEnabled(bool enabled) {
    return enabled ? _manager.armWakeWord() : _manager.disarmWakeWord();
  }
}

final razVoiceControllerProvider = NotifierProvider.autoDispose
    .family<RazVoiceController, RazVoiceState, RazAudience>(
      RazVoiceController.new,
    );
