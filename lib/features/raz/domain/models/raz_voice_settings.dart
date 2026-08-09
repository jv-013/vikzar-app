/// A player's or coach's voice preferences — device-level (see
/// `VoiceSettingsStore`'s own doc comment for why), covering only
/// options that map to a genuinely working control today. No field
/// exists here for "Voice Language" — every locale today is whatever
/// the device's own speech recognizer/synthesizer defaults to, and
/// there is no localization infrastructure to back a real language
/// picker yet (documented as future-only in `RAZ_VOICE_ARCHITECTURE.md`,
/// never a fake dropdown in Settings).
class RazVoiceSettings {
  const RazVoiceSettings({
    this.enabled = true,
    this.wakeWordEnabled = false,
    this.speechRate = 0.5,
    this.speechVolume = 1.0,
    this.voiceName,
  });

  /// Master voice switch — off disables both push-to-talk and the wake
  /// word; it never removes typed chat, which always works regardless.
  final bool enabled;

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

  /// **No `autoReadDailyBrief` field, deliberately.** RAZ never
  /// auto-reads anything — content is only ever spoken when a user
  /// explicitly taps a `RazReadAloudButton` (or the conversational mic).
  /// A toggle to enable behavior that never happens automatically would
  /// be exactly the kind of fake option this codebase's "no fake
  /// options" convention rules out.
  RazVoiceSettings copyWith({
    bool? enabled,
    bool? wakeWordEnabled,
    double? speechRate,
    double? speechVolume,
    String? voiceName,
    bool clearVoiceName = false,
  }) {
    return RazVoiceSettings(
      enabled: enabled ?? this.enabled,
      wakeWordEnabled: wakeWordEnabled ?? this.wakeWordEnabled,
      speechRate: speechRate ?? this.speechRate,
      speechVolume: speechVolume ?? this.speechVolume,
      voiceName: clearVoiceName ? null : (voiceName ?? this.voiceName),
    );
  }
}
