/// The minimal identity data a datasource exposes — deliberately not
/// `firebase_auth`'s `User` type, kept out of this interface so it stays
/// fakeable in tests without touching the Firebase SDK at all.
class AuthUser {
  const AuthUser({required this.uid, this.email});

  final String uid;
  final String? email;
}

/// Thrown by any [AuthDatasource] implementation on a failed operation.
/// [code] mirrors `FirebaseAuthException.code` values (e.g.
/// `'user-not-found'`, `'wrong-password'`) so
/// `AuthRepositoryImpl`'s fallback logic and exception mapping are
/// identical whether driven by the real Firebase implementation or a fake.
class AuthDatasourceException implements Exception {
  const AuthDatasourceException(this.code);

  final String code;
}

/// The contract `AuthRepositoryImpl` depends on — proportionate
/// abstraction at the SDK boundary, per FLUTTER_ARCHITECTURE.md §7/§15.
///
/// Phase 6: authentication is passwordless (email + 6-digit code) at every
/// layer above this one. [signIn]/[createAccount] still take a `secret`
/// parameter because Firebase Auth has no native email-OTP primitive — see
/// `AuthRepositoryImpl`'s doc comment for how that secret is derived and
/// why it never appears in any public, user-facing API. This interface is
/// what makes that whole mechanism unit-testable against a fake, without
/// mocking `firebase_auth` classes.
abstract interface class AuthDatasource {
  Stream<AuthUser?> get authStateChanges;

  /// Placeholder — see `AuthRepositoryImpl`'s doc comment. No email is
  /// actually sent by any implementation at Phase 6.
  Future<void> sendOtp({required String email});

  Future<void> signIn({required String email, required String secret});

  Future<void> createAccount({required String email, required String secret});

  Future<void> signOut();
}
