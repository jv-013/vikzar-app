import '../models/raz_voice_option.dart';

/// Speech synthesis abstraction — the seam that keeps every voice
/// controller ignorant of `flutter_tts` (or whatever speaks tomorrow).
/// Resolved through `raz_speech_providers.dart`'s
/// `routeToSpeechSynthesizer()`, never constructed directly.
///
/// A single [speak] call owns its own sentence-by-sentence pacing
/// internally (see `FlutterTtsSynthesizer`'s implementation) — callers
/// pass RAZ's full response text once; they never manage chunking,
/// queues, or pause timing themselves. Calling [speak] while already
/// speaking cancels the in-progress utterance first (there is never a
/// legitimate case in this app for two RAZ replies to be queued
/// back-to-back — a new question can't be asked while one is already
/// pending), so [RazReadAloudButton] and the conversational voice path
/// can safely share one synthesizer instance with no extra
/// coordination.
abstract interface class RazSpeechSynthesizer {
  bool get isSpeaking;

  /// The platform's installed voices, queried fresh each call — never
  /// cached stale across a device's own OS-level voice-pack changes.
  /// Returns an empty list on any platform/plugin failure rather than
  /// throwing (`RazVoiceSettingsController`/the Settings screen already
  /// treat "no voices available" as "hide the picker", never a crash).
  Future<List<RazVoiceOption>> availableVoices();

  /// Selects [voice] for every subsequent [speak]/[speakSentence] call.
  /// A no-op, not a throw, if the platform rejects it (e.g. the voice
  /// was uninstalled since [availableVoices] last ran) — the previous
  /// voice (or platform default) simply keeps being used.
  Future<void> setVoice(RazVoiceOption voice);

  /// Speaks [text], stopping any currently-speaking utterance first.
  /// Strips markdown/formatting characters before speaking (RAZ's text
  /// is plain prose today, but this is a cheap, permanent guard against
  /// ever reading `**bold**`/`- bullets` aloud verbatim). Resolves once
  /// speech has finished, been stopped, or been superseded by a newer
  /// [speak] call.
  Future<void> speak(String text);

  /// The streaming counterpart to [speak] — speaks one already-complete
  /// sentence, queued after whatever this call's caller has already
  /// enqueued, rather than interrupting it. Deliberately does **not**
  /// stop any prior utterance itself (unlike [speak]); the caller is
  /// responsible for calling [stop] once, before the first sentence of
  /// a new streamed turn, exactly the barge-in guarantee [speak]
  /// otherwise gives for free. Exists so a streamed LLM answer can be
  /// spoken sentence-by-sentence as it arrives instead of waiting for
  /// the complete text.
  Future<void> speakSentence(String sentence);

  /// Stops immediately, mid-sentence if necessary — the mechanism behind
  /// barge-in ("stop talking over me").
  Future<void> stop();

  /// 0.0–1.0. Applied to the next [speak] call onward (never
  /// interrupts one already in progress).
  Future<void> setRate(double rate);

  /// 0.0–1.0.
  Future<void> setVolume(double volume);
}
