import 'package:vikzar/features/auth/data/datasources/auth_datasource.dart';

/// A fake [AuthDatasource] for unit-testing `AuthRepositoryImpl`'s
/// sign-in-or-create-account fallback logic without touching
/// `firebase_auth` at all — the payoff of extracting the datasource
/// interface, per FLUTTER_ARCHITECTURE.md §15's unit-test-heavy pyramid.
class FakeAuthDatasource implements AuthDatasource {
  /// Emails "known" to already have an account, mapped to their correct
  /// password — `signIn` succeeds only for a matching pair.
  final Map<String, String> existingAccounts = {};

  bool signOutCalled = false;

  @override
  Stream<AuthUser?> get authStateChanges => const Stream.empty();

  @override
  Future<void> signIn({required String email, required String password}) async {
    if (!existingAccounts.containsKey(email)) {
      throw const AuthDatasourceException('user-not-found');
    }
    if (existingAccounts[email] != password) {
      throw const AuthDatasourceException('wrong-password');
    }
  }

  @override
  Future<void> createAccount({
    required String email,
    required String password,
  }) async {
    if (existingAccounts.containsKey(email)) {
      throw const AuthDatasourceException('email-already-in-use');
    }
    existingAccounts[email] = password;
  }

  @override
  Future<void> signOut() async {
    signOutCalled = true;
  }
}
