import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../services/local_storage/voice_settings_store.dart';
import '../../domain/models/raz_voice_settings.dart';

/// Reactive read/write surface over [VoiceSettingsStore] — mirrors
/// `ThemeModeNotifier`'s shape exactly. Settings screen and
/// `RazConversationManager` both watch this so a change in one place
/// (e.g. disabling the wake word in Settings) is immediately reflected
/// wherever else it matters.
class RazVoiceSettingsController extends Notifier<RazVoiceSettings> {
  @override
  RazVoiceSettings build() => ref.read(voiceSettingsStoreProvider).read();

  void _update(RazVoiceSettings Function(RazVoiceSettings) transform) {
    final next = transform(state);
    state = next;
    ref.read(voiceSettingsStoreProvider).write(next);
  }

  void setEnabled(bool value) => _update((s) => s.copyWith(enabled: value));

  void setWakeWordEnabled(bool value) => _update((s) => s.copyWith(wakeWordEnabled: value));

  void setSpeechRate(double value) => _update((s) => s.copyWith(speechRate: value));

  void setSpeechVolume(double value) => _update((s) => s.copyWith(speechVolume: value));

  void setVoiceName(String? value) {
    if (value == null) {
      _update((s) => s.copyWith(clearVoiceName: true));
    } else {
      _update((s) => s.copyWith(voiceName: value));
    }
  }
}

final razVoiceSettingsControllerProvider =
    NotifierProvider<RazVoiceSettingsController, RazVoiceSettings>(
      RazVoiceSettingsController.new,
    );
