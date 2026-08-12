/// Product-defined RAZ voice presets — what the user sees in Settings.
/// Each preset maps to a locale + gender combination. The actual
/// underlying TTS voice is resolved at runtime by matching against the
/// device's installed voices — never assumed or faked.
///
/// If a preset's underlying voice is not available on the current
/// device, it is simply not offered in the picker. The user always
/// sees "Device Default" as a fallback.
library;

/// One of the eight product voice presets, or the device default.
enum RazVoicePreset {
  deviceDefault(locale: null, gender: null, displayLabel: 'Device Default'),
  ukEnglishFemale(locale: 'en-GB', gender: 'female', displayLabel: 'UK English — Female'),
  ukEnglishMale(locale: 'en-GB', gender: 'male', displayLabel: 'UK English — Male'),
  usEnglishFemale(locale: 'en-US', gender: 'female', displayLabel: 'US English — Female'),
  usEnglishMale(locale: 'en-US', gender: 'male', displayLabel: 'US English — Male'),
  indianEnglishFemale(locale: 'en-IN', gender: 'female', displayLabel: 'Indian English — Female'),
  indianEnglishMale(locale: 'en-IN', gender: 'male', displayLabel: 'Indian English — Male'),
  italianFemale(locale: 'it-IT', gender: 'female', displayLabel: 'Italian — Female'),
  italianMale(locale: 'it-IT', gender: 'male', displayLabel: 'Italian — Male');

  const RazVoicePreset({required this.locale, required this.gender, required this.displayLabel});

  /// BCP-47 locale string, or `null` for device default.
  final String? locale;

  /// `"male"` or `"female"`, or `null` for device default.
  final String? gender;

  /// Human-readable label shown in the voice picker.
  final String displayLabel;
}

/// A matched preset with the actual TTS voice it maps to on this device.
class ResolvedVoicePreset {
  const ResolvedVoicePreset({required this.preset, required this.voiceName});

  final RazVoicePreset preset;

  /// The platform TTS engine's own voice identifier — passed to
  /// `RazSpeechSynthesizer.setVoice` verbatim.
  final String voiceName;
}
