/// Speech-to-text abstraction — the seam that keeps every voice
/// controller ignorant of `speech_to_text` (or whatever recognizes
/// speech tomorrow). Resolved through `raz_speech_providers.dart`'s
/// `routeToSpeechRecognizer()`, never constructed directly by a
/// controller or widget — the same "Flutter never knows which provider"
/// discipline the backend's Model Router (`aiService.ts`) already
/// enforces for RAZ's own LLM calls.
///
/// One recognizer instance is shared between push-to-talk command
/// capture and wake-word passive listening (`RazWakeWordEngine` takes a
/// `RazSpeechRecognizer` as a dependency rather than owning a second
/// one) — there is only ever one microphone session at a time.
abstract interface class RazSpeechRecognizer {
  /// Emits partial and final transcripts while a [listen] session is
  /// active. A final transcript is not distinguished on this stream —
  /// callers that need only the final result should collect until the
  /// stream closes (which happens when the session ends) or use
  /// [listen]'s `onFinalResult` callback directly.
  Stream<String> get partialResults;

  /// Emits a human-readable message whenever the platform recognizer
  /// reports a real error (network unavailable for cloud-backed
  /// recognition, permission revoked mid-session, no match, a timeout)
  /// — never a fabricated transcript in place of a genuine failure.
  Stream<String> get errors;

  /// Emits the new [isListening] value whenever a session starts or
  /// ends — including ending on its own (a [listenFor]/[pauseFor]
  /// timeout), not only on an explicit [stop]/[cancel]. This is what
  /// lets a wake-word engine know when to re-arm without polling.
  Stream<bool> get listeningChanges;

  /// Prepares the platform recognizer. Must be called (and return
  /// `true`) before [listen]. Safe to call more than once.
  Future<bool> initialize();

  /// `true` once the platform engine is genuinely available on this
  /// device — `false` means no real recognizer exists here, not a
  /// permission gap (see `RazVoicePermissions` for that distinction).
  bool get isAvailable;

  bool get isListening;

  /// Starts one listen session. [onFinalResult] fires at most once, with
  /// the final recognized text, when the session ends with real words
  /// recognized — never with a fabricated transcript. [listenFor] bounds
  /// the whole session; [pauseFor] bounds a mid-speech silence before the
  /// session ends early (endpoint detection). A no-op if already
  /// listening.
  Future<void> listen({
    required void Function(String text) onFinalResult,
    Duration? listenFor,
    Duration? pauseFor,
  });

  /// Ends the current session early, keeping whatever was already
  /// recognized (graceful stop, not a discard).
  Future<void> stop();

  /// Ends the current session early and discards anything recognized so
  /// far — a genuine cancellation, distinct from [stop].
  Future<void> cancel();
}
