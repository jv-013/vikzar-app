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
/// background service — this is the one explicitly-accepted V1
/// limitation, not an oversight. See `RAZ_VOICE_ARCHITECTURE.md` for the
/// documented (not built) background/always-listening extension design.
abstract interface class RazWakeWordEngine {
  /// Fires once per detected wake phrase. Never fires for a false
  /// negative (a missed phrase produces silence, not an event) — only a
  /// genuine, matched detection.
  Stream<void> get onWakeWordDetected;

  bool get isArmed;

  /// Starts passive listening for the wake phrase. A no-op if already
  /// armed, and safe to call repeatedly (an implementation may need to
  /// re-arm itself after each bounded listen cycle — callers don't need
  /// to know that).
  Future<void> arm();

  /// Stops passive listening entirely — called on app background, or
  /// when the user disables the wake-word setting.
  Future<void> disarm();
}
