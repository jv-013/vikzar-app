/// Microphone permission abstraction — the first real, non-`speech_to_
/// text`-implicit permission check in this app. Resolved through a bare
/// provider (no router — there is only one real notion of "the
/// platform's permission system" to route to, unlike the recognizer/
/// synthesizer/wake-word seams, so a router layer here would be
/// indirection with no real alternative behind it).
abstract interface class RazVoicePermissions {
  /// Reads current status without prompting the user.
  Future<RazPermissionStatus> check();

  /// Prompts the user if [check] would return [RazPermissionStatus.denied]
  /// — a no-op (returns the current status) if already granted or
  /// already permanently denied, since re-prompting either does nothing
  /// on real platforms.
  Future<RazPermissionStatus> request();

  /// Opens the OS settings screen for this app — the only way forward
  /// once a permission is [RazPermissionStatus.permanentlyDenied].
  Future<void> openSettings();
}

enum RazPermissionStatus {
  granted,
  denied,
  permanentlyDenied,

  /// The current platform has no real permission plugin implementation
  /// to check (macOS today — `permission_handler` registers no macOS
  /// implementation for `Permission.microphone`). A distinct, honest
  /// status rather than a fabricated `denied`/`granted` — callers should
  /// surface this as "voice isn't available on this platform yet," not
  /// prompt the user toward a Settings screen that won't help.
  unsupported,
}
