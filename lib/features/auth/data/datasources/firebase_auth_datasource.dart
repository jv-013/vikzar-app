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
  Future<void> signIn({required String email, required String password}) =>
      _guard(
        () => _auth.signInWithEmailAndPassword(email: email, password: password),
      );

  @override
  Future<void> createAccount({
    required String email,
    required String password,
  }) => _guard(
    () => _auth.createUserWithEmailAndPassword(email: email, password: password),
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
