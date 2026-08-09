/// A gender RAZ's voice can confidently be identified as — never a
/// guess dressed up as fact. See [RazVoiceOption.gender]'s own doc
/// comment for what "confidently" means in practice.
enum RazVoiceGender { male, female }

/// One installed platform TTS voice, as reported by the device itself
/// — never invented, never a hardcoded ID for one specific device.
/// [RazSpeechSynthesizer.availableVoices] is the only place these come
/// from.
class RazVoiceOption {
  const RazVoiceOption({required this.name, required this.locale, this.gender});

  /// The engine's own identifier for this voice — opaque to Vikzar,
  /// passed back to [RazSpeechSynthesizer.setVoice] verbatim.
  final String name;

  final String locale;

  /// `null` when the platform genuinely doesn't expose this voice's
  /// gender — e.g. most Android system voices report only a name and
  /// locale, no gender field at all. A `null` here must never be
  /// papered over with a guess; see `flutter_tts_synthesizer.dart`'s
  /// `_deriveGender` for the one real signal (iOS's own `gender` key)
  /// this is ever set from.
  final RazVoiceGender? gender;
}
