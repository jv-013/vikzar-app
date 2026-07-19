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
  bool sendOtpCalled = false;

  @override
  Stream<AuthUser?> get authStateChanges => const Stream.empty();

  @override
  Future<void> sendOtp({required String email}) async {
    sendOtpCalled = true;
  }

  @override
  Future<void> signIn({required String email, required String secret}) async {
    if (!existingAccounts.containsKey(email)) {
      throw const AuthDatasourceException('user-not-found');
    }
    if (existingAccounts[email] != secret) {
      throw const AuthDatasourceException('wrong-password');
    }
  }

  @override
  Future<void> createAccount({
    required String email,
    required String secret,
  }) async {
    if (existingAccounts.containsKey(email)) {
      throw const AuthDatasourceException('email-already-in-use');
    }
    existingAccounts[email] = secret;
  }

  @override
  Future<void> signOut() async {
    signOutCalled = true;
  }
}
