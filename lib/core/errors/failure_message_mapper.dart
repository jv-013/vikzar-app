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
      CloudFailure(:final message) => _cloudMessage(message),
      BleFailure() => 'A device connection issue occurred.',
      UnknownFailure() => 'Something went wrong. Please try again.',
    };
  }

  static String _authMessage(String? code) {
    return switch (code) {
      'invalid-email' => "That email address doesn't look right.",
      'user-disabled' => 'This account has been disabled.',
      'wrong-password' ||
      'user-not-found' ||
      'invalid-credential' => "We couldn't verify that. Please try again.",
      'account-exists-with-different-credential' =>
        'An account already exists for that email with a different sign-in '
            'method. Try continuing with that method instead.',
      'invalid-action-code' || 'invalid-email-link' =>
        "That link isn't valid. Request a new one and try again.",
      'expired-action-code' =>
        'That link has expired. Request a new one and try again.',
      _ => 'We couldn\'t sign you in. Please try again.',
    };
  }

  static String _cloudMessage(String? code) {
    return switch (code) {
      'team-not-found' =>
        "That team ID doesn't match a team. Check the code and try again.",
      // joinTeamWithInvite's rejection for an unknown/expired code.
      'not-found' =>
        'This invite code is invalid or has expired. Check the code and '
            'try again.',
      // Phase 13 §10 — createPlannedSession's rate limit.
      'resource-exhausted' =>
        "You're doing that a bit too quickly. Please wait a moment and try again.",
      _ => 'Something went wrong. Please try again.',
    };
  }
}
