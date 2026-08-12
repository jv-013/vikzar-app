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
///
/// **RC2.1:** The former `voice_enabled` key is no longer read or
/// written — the master voice toggle has been removed. Old keys in
/// SharedPreferences are simply ignored (not migrated or deleted).
class VoiceSettingsStore {
  VoiceSettingsStore(this._prefs);

  final SharedPreferences _prefs;

  // Note: _enabledKey intentionally removed. Old values in prefs are ignored.
  static const _wakeWordEnabledKey = 'voice_wake_word_enabled';
  static const _speechRateKey = 'voice_speech_rate';
  static const _speechVolumeKey = 'voice_speech_volume';
  static const _voiceNameKey = 'voice_name';

  RazVoiceSettings read() {
    const defaults = RazVoiceSettings();
    return RazVoiceSettings(
      wakeWordEnabled: _prefs.getBool(_wakeWordEnabledKey) ?? defaults.wakeWordEnabled,
      speechRate: _prefs.getDouble(_speechRateKey) ?? defaults.speechRate,
      speechVolume: _prefs.getDouble(_speechVolumeKey) ?? defaults.speechVolume,
      voiceName: _prefs.getString(_voiceNameKey),
    );
  }

  Future<void> write(RazVoiceSettings settings) async {
    await Future.wait([
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
