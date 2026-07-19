import 'package:flutter/foundation.dart';

/// This feature's domain-level view of authentication status — deliberately
/// not `firebase_auth`'s `User` type, which must never appear above
/// `features/auth/data`, per FLUTTER_ARCHITECTURE.md §1's dependency rule
/// (domain has zero Firebase dependency).
@immutable
sealed class AuthState {
  const AuthState();
}

final class Authenticated extends AuthState {
  const Authenticated({required this.uid, this.email});

  final String uid;
  final String? email;
}

final class Unauthenticated extends AuthState {
  const Unauthenticated();
}
