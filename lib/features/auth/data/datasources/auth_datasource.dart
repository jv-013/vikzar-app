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
/// `'user-not-found'`, `'account-exists-with-different-credential'`), or
/// one of this interface's own codes (`'google-sign-in-cancelled'`,
/// `'apple-sign-in-cancelled'`, `'invalid-email-link'`) for failures that
/// happen before Firebase Auth is even reached.
class AuthDatasourceException implements Exception {
  const AuthDatasourceException(this.code);

  final String code;
}

/// The contract `AuthRepositoryImpl` depends on — proportionate
/// abstraction at the SDK boundary, per FLUTTER_ARCHITECTURE.md §7/§15.
///
/// **Phase 17** replaces the custom email + 6-digit code flow (which had
/// a documented, un-shippable placeholder verification step — see
/// DECISIONS.md ADR-044) with three real Firebase Authentication
/// providers: Google Sign-In, Apple Sign-In, and Firebase's own Email
/// Link (magic link). Every method here either succeeds against a real,
/// Firebase-verified identity, or throws — there is no code path in
/// this interface, or anything implementing it, that accepts an
/// unverified credential.
abstract interface class AuthDatasource {
  Stream<AuthUser?> get authStateChanges;

  /// Signs in with Google. Throws with code `'google-sign-in-cancelled'`
  /// if the user dismisses the account picker — a normal, non-error
  /// outcome the repository maps to no failure surfaced at all, not a
  /// generic error.
  Future<void> signInWithGoogle();

  /// Signs in with Apple. Only meaningfully available on iOS/macOS —
  /// see `AuthScreen`'s platform check. Throws with code
  /// `'apple-sign-in-cancelled'` on user cancellation, same treatment
  /// as Google's cancellation code above.
  Future<void> signInWithApple();

  /// Step 1 of the magic-link flow: asks Firebase to email [email] a
  /// sign-in link. Never reveals whether the email belongs to an
  /// existing account — Firebase Email Link sign-in creates one
  /// transparently if it doesn't, matching the single continuous flow
  /// the old OTP flow also used.
  Future<void> sendSignInLinkToEmail(String email);

  /// Whether [link] (the URL the app was opened with) is a Firebase
  /// sign-in link at all, before attempting to use it as one.
  bool isSignInWithEmailLink(String link);

  /// Step 2: completes sign-in using the link the user tapped in their
  /// email. [email] must be the same address [sendSignInLinkToEmail]
  /// was called with — the caller is responsible for persisting it
  /// locally between steps (the link itself doesn't carry it back if
  /// completed on a different device).
  Future<void> signInWithEmailLink({required String email, required String emailLink});

  Future<void> signOut();
}
