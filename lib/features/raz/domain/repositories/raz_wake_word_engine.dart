/// Foreground-only "Hey Raz" wake-word detection abstraction.
/// Resolved through `raz_speech_providers.dart`'s
/// `routeToWakeWordEngine()`.
///
/// **Hardware upgrades RAZ, it never activates it — the same governing
/// rule `razHardwareContext.ts` already enforces for Pods/EMG applies
/// here for a different capability.** A wake word only ever adds a
/// second way to start a conversation already fully available via
/// push-to-talk; disabling it (the default) never reduces what RAZ can
/// do.
///
/// **Foreground only, by construction.** [arm]/[disarm] are driven by
/// app-lifecycle transitions (see `RazConversationManager`), never by a
/// background service.
abstract interface class RazWakeWordEngine {
  /// Fires once per detected wake phrase. Never fires for a false
  /// negative (a missed phrase produces silence, not an event) — only a
  /// genuine, matched detection.
  Stream<void> get onWakeWordDetected;

  /// Emits a human-readable message when the engine encounters a real
  /// error (missing model file, invalid access key, platform
  /// incompatibility) — never a fabricated error in place of a genuine
  /// success.
  Stream<String> get errors;

  bool get isArmed;

  /// Whether the engine is actively processing audio frames right now.
  /// Distinct from [isArmed]: an engine can be armed (initialized and
  /// ready) but not currently listening (e.g., paused while STT is
  /// active).
  bool get isListening;

  /// Starts passive listening for the wake phrase. A no-op if already
  /// armed, and safe to call repeatedly.
  Future<void> arm();

  /// Stops passive listening entirely — called on app background, or
  /// when the user disables the wake-word setting.
  Future<void> disarm();

  /// Temporarily pauses wake-word detection without fully disarming —
  /// used when another audio source (STT, TTS) needs exclusive
  /// microphone access. [resume] re-starts detection.
  Future<void> pause();

  /// Resumes wake-word detection after a [pause]. A no-op if not armed.
  Future<void> resume();

  /// Releases all engine resources. Must be called when the engine is
  /// no longer needed (provider disposal, logout).
  Future<void> dispose();
}
