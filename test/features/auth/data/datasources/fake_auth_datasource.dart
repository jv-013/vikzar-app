import 'package:vikzar/features/auth/data/datasources/auth_datasource.dart';

/// A fake [AuthDatasource] for unit-testing `AuthRepositoryImpl`'s
/// sign-in-or-create-account fallback logic without touching
/// `firebase_auth` at all — the payoff of extracting the datasource
/// interface, per FLUTTER_ARCHITECTURE.md §15's unit-test-heavy pyramid.
///
/// `secret` here stands in for `AuthRepositoryImpl`'s internally-derived
/// credential (see that class's `verifyOtp` doc comment) — this fake has
/// no opinion on how the secret was produced, only that `signIn`/
/// `createAccount` behave like a real email/password backend would.
class FakeAuthDatasource implements AuthDatasource {
  /// Emails "known" to already have an account, mapped to their derived
  /// secret — `signIn` succeeds only for a matching pair.
  final Map<String, String> existingAccounts = {};

  bool signOutCalled = false;
  bool signInWithGoogleCalled = false;
  bool signInWithAppleCalled = false;
  bool sendSignInLinkCalled = false;
  String? lastLinkSent;

  @override
  Stream<AuthUser?> get authStateChanges => const Stream.empty();

  @override
  Future<void> signInWithGoogle() async {
    signInWithGoogleCalled = true;
  }

  @override
  Future<void> signInWithApple() async {
    signInWithAppleCalled = true;
  }

  @override
  Future<void> sendSignInLinkToEmail(String email) async {
    sendSignInLinkCalled = true;
    lastLinkSent = email;
  }

  @override
  bool isSignInWithEmailLink(String link) {
    return link.contains('firebase');
  }

  @override
  Future<void> signInWithEmailLink({required String email, required String emailLink}) async {
    if (!existingAccounts.containsKey(email)) {
      throw const AuthDatasourceException('user-not-found');
    }
  }

  @override
  Future<void> signOut() async {
    signOutCalled = true;
  }
}
