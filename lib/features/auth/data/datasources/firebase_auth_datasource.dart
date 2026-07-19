import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../services/firebase/auth_service.dart';
import 'auth_datasource.dart';

/// The only file in `features/auth` permitted to import `firebase_auth`
/// directly, per FLUTTER_ARCHITECTURE.md §3/§7 — everything above this
/// (`AuthDatasource`, `data/repositories`, `presentation/`) works with
/// plain Dart types only, via the `AuthDatasource` interface.
class FirebaseAuthDatasource implements AuthDatasource {
  FirebaseAuthDatasource(this._auth);

  final fb.FirebaseAuth _auth;

  @override
  Stream<AuthUser?> get authStateChanges => _auth.authStateChanges().map(
    (user) => user == null ? null : AuthUser(uid: user.uid, email: user.email),
  );

  @override
  Future<void> sendOtp({required String email}) async {
    // Placeholder (DECISIONS.md ADR-044): no real backend exists this phase
    // to generate, email, and verify a one-time code, so nothing is
    // actually sent. The delay simulates real network latency so the
    // calling screen's loading state has something genuine to show rather
    // than an instant, suspicious-looking "success."
    await Future<void>.delayed(const Duration(milliseconds: 400));
  }

  @override
  Future<void> signIn({required String email, required String secret}) =>
      _guard(
        () => _auth.signInWithEmailAndPassword(email: email, password: secret),
      );

  @override
  Future<void> createAccount({
    required String email,
    required String secret,
  }) => _guard(
    () => _auth.createUserWithEmailAndPassword(email: email, password: secret),
  );

  @override
  Future<void> signOut() => _guard(_auth.signOut);

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } on fb.FirebaseAuthException catch (e) {
      throw AuthDatasourceException(e.code);
    }
  }
}

final firebaseAuthDatasourceProvider = Provider<AuthDatasource>((ref) {
  return FirebaseAuthDatasource(ref.watch(firebaseAuthProvider));
});
