/// The typed failure hierarchy every repository/service maps raw exceptions
/// onto, per ARCHITECTURE.md §16 and FLUTTER_ARCHITECTURE.md §12.
///
/// No raw platform or Firebase exception ever crosses the data-layer
/// boundary — datasources catch and translate into one of these. The
/// presentation layer maps a [Failure] to calm, user-facing copy via a
/// `FailureMessageMapper` (introduced when a feature first needs one).
///
/// These carry no logic — they are plain, immutable data.
sealed class Failure {
  const Failure({this.message, this.cause});

  /// Optional technical detail, for logging only — never shown to a user.
  final String? message;

  /// The original exception, if any, retained for diagnostics/Crashlytics.
  final Object? cause;
}

/// Connectivity lost or unreachable mid-operation.
final class NetworkFailure extends Failure {
  const NetworkFailure({super.message, super.cause});
}

/// Invalid credentials, expired session, or another Firebase Auth failure.
final class AuthFailure extends Failure {
  const AuthFailure({super.message, super.cause});
}

/// A Firestore/Storage Security Rule denied a read or write.
final class PermissionFailure extends Failure {
  const PermissionFailure({super.message, super.cause});
}

/// A Callable Cloud Function call failed (e.g. an invalid team invite code).
final class CloudFailure extends Failure {
  const CloudFailure({super.message, super.cause});
}

/// Reserved for the future BLE evolution path (ARCHITECTURE.md, "Future
/// Evolution"). Unused at MVP — the Flutter app has no BLE dependency per
/// DECISIONS.md ADR-030 — but retained now so the Failure hierarchy does not
/// need to change shape when that capability is introduced.
final class BleFailure extends Failure {
  const BleFailure({super.message, super.cause});
}

/// Anything not classified above. Always reported to Crashlytics with
/// [cause] attached; the user only ever sees a generic, calm message.
final class UnknownFailure extends Failure {
  const UnknownFailure({super.message, super.cause});
}
