/// A player's or coach's voice preferences — device-level (see
/// `VoiceSettingsStore`'s own doc comment for why), covering only
/// options that map to a genuinely working control today. No field
/// exists here for "Voice Language" — every locale today is whatever
/// the device's own speech recognizer/synthesizer defaults to, and
/// there is no localization infrastructure to back a real language
/// picker yet (documented as future-only in `RAZ_VOICE_ARCHITECTURE.md`,
/// never a fake dropdown in Settings).
///
/// **RC2.1:** The former `enabled` master toggle ("Voice — Talk to RAZ
/// instead of typing") has been removed — users found it redundant
/// because RAZ already provides a microphone. Push-to-talk and TTS are
/// always available. Only the wake-word toggle remains as a separate
/// opt-in feature.
class RazVoiceSettings {
  const RazVoiceSettings({
    this.wakeWordEnabled = false,
    this.speechRate = 0.5,
    this.speechVolume = 1.0,
    this.voiceName,
  });

  /// Off by default — an always-on-while-foregrounded microphone is an
  /// opt-in cost, never assumed.
  final bool wakeWordEnabled;

  /// 0.0–1.0, `flutter_tts`'s own natural range.
  final double speechRate;

  /// 0.0–1.0.
  final double speechVolume;

  /// The platform TTS engine's own identifier for the chosen voice
  /// (`RazVoiceOption.name`) — `null` means "platform default," never a
  /// fake pre-selection before the athlete has actually chosen
  /// anything. Stored as the raw engine identifier, not a "male"/
  /// "female" label, so it stays meaningful even on a platform where
  /// gender metadata isn't available for every voice (see
  /// `FlutterTtsSynthesizer._deriveGender`) — the label shown in
  /// Settings is derived at display time from whatever
  /// `RazSpeechSynthesizer.availableVoices` reports for this name.
  final String? voiceName;

  RazVoiceSettings copyWith({
    bool? wakeWordEnabled,
    double? speechRate,
    double? speechVolume,
    String? voiceName,
    bool clearVoiceName = false,
  }) {
    return RazVoiceSettings(
      wakeWordEnabled: wakeWordEnabled ?? this.wakeWordEnabled,
      speechRate: speechRate ?? this.speechRate,
      speechVolume: speechVolume ?? this.speechVolume,
      voiceName: clearVoiceName ? null : (voiceName ?? this.voiceName),
    );
  }
}
