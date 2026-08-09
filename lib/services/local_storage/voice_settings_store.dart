import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/raz/domain/models/raz_voice_settings.dart';
import 'shared_preferences_provider.dart';

/// Persists [RazVoiceSettings] — mirrors `ThemeModeStore`'s shape
/// exactly (wraps `sharedPreferencesProvider`, one class, several
/// `static const _key*` constants). **Deliberately not uid-namespaced**,
/// same reasoning as `ThemeModeStore`: voice preferences (whether the
/// wake word is on, how fast RAZ talks) are a personal device setting,
/// not per-account state — switching accounts on a shared device
/// shouldn't silently change how the device behaves.
class VoiceSettingsStore {
  VoiceSettingsStore(this._prefs);

  final SharedPreferences _prefs;

  static const _enabledKey = 'voice_enabled';
  static const _wakeWordEnabledKey = 'voice_wake_word_enabled';
  static const _speechRateKey = 'voice_speech_rate';
  static const _speechVolumeKey = 'voice_speech_volume';
  static const _voiceNameKey = 'voice_name';

  RazVoiceSettings read() {
    const defaults = RazVoiceSettings();
    return RazVoiceSettings(
      enabled: _prefs.getBool(_enabledKey) ?? defaults.enabled,
      wakeWordEnabled: _prefs.getBool(_wakeWordEnabledKey) ?? defaults.wakeWordEnabled,
      speechRate: _prefs.getDouble(_speechRateKey) ?? defaults.speechRate,
      speechVolume: _prefs.getDouble(_speechVolumeKey) ?? defaults.speechVolume,
      voiceName: _prefs.getString(_voiceNameKey),
    );
  }

  Future<void> write(RazVoiceSettings settings) async {
    await Future.wait([
      _prefs.setBool(_enabledKey, settings.enabled),
      _prefs.setBool(_wakeWordEnabledKey, settings.wakeWordEnabled),
      _prefs.setDouble(_speechRateKey, settings.speechRate),
      _prefs.setDouble(_speechVolumeKey, settings.speechVolume),
      if (settings.voiceName != null)
        _prefs.setString(_voiceNameKey, settings.voiceName!)
      else
        _prefs.remove(_voiceNameKey),
    ]);
  }
}

final voiceSettingsStoreProvider = Provider<VoiceSettingsStore>((ref) {
  return VoiceSettingsStore(ref.watch(sharedPreferencesProvider));
});
