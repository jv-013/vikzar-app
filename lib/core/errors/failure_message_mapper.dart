import 'failure.dart';

/// The single place `Failure → user-facing string` translation happens,
/// per ARCHITECTURE.md §16 and FLUTTER_ARCHITECTURE.md §12 — no controller
/// writes its own ad hoc error string. Copy is calm and specific, never a
/// raw error code, per DESIGN_SPECIFICATION.md's trustworthy tone.
abstract final class FailureMessageMapper {
  static String toMessage(Failure failure) {
    return switch (failure) {
      NetworkFailure() => "You're offline. Please check your connection "
          'and try again.',
      AuthFailure(:final message) => _authMessage(message),
      PermissionFailure() =>
        "You don't have permission to do that right now.",
      CloudFailure() => 'Something went wrong. Please try again.',
      BleFailure() => 'A device connection issue occurred.',
      UnknownFailure() => 'Something went wrong. Please try again.',
    };
  }

  static String _authMessage(String? code) {
    return switch (code) {
      'invalid-otp-format' => 'Enter the 6-digit code sent to your email.',
      'invalid-email' => "That email address doesn't look right.",
      'user-disabled' => 'This account has been disabled.',
      'wrong-password' ||
      'user-not-found' ||
      'invalid-credential' => "That code didn't work. Please try again.",
      _ => 'We couldn\'t sign you in. Please try again.',
    };
  }
}
