import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/result/result.dart';
import '../../domain/models/auth_state.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_datasource.dart';
import '../datasources/firebase_auth_datasource.dart';

/// Error codes across `firebase_auth` SDK versions that mean "no account
/// exists for this email" — newer versions consolidate several codes into
/// `invalid-credential` for enumeration-attack protection, so both are
/// checked.
const _noAccountErrorCodes = {'user-not-found', 'invalid-credential'};

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._datasource);

  final AuthDatasource _datasource;

  @override
  Stream<AuthState> get authStateChanges => _datasource.authStateChanges.map(
    (user) => user == null
        ? const Unauthenticated()
        : Authenticated(uid: user.uid, email: user.email),
  );

  @override
  Future<Result<void>> signInOrCreateAccount({
    required String email,
    required String password,
  }) async {
    try {
      await _datasource.signIn(email: email, password: password);
      return const Result.success(null);
    } on AuthDatasourceException catch (signInError) {
      if (!_noAccountErrorCodes.contains(signInError.code)) {
        return Result.failure(_mapException(signInError));
      }

      // No account for this email yet — the single-screen "Continue"
      // action (DESIGN_SPECIFICATION.md §19.1) transparently creates one
      // rather than sending the user to a separate sign-up flow.
      try {
        await _datasource.createAccount(email: email, password: password);
        return const Result.success(null);
      } on AuthDatasourceException catch (createError) {
        if (createError.code == 'email-already-in-use') {
          // The account does exist after all — the original sign-in
          // failure was really a wrong password. Surface that, not the
          // confusing "already in use" error.
          return Result.failure(_mapException(signInError));
        }
        return Result.failure(_mapException(createError));
      }
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }

  @override
  Future<Result<void>> signOut() async {
    try {
      await _datasource.signOut();
      return const Result.success(null);
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }

  Failure _mapException(AuthDatasourceException e) {
    switch (e.code) {
      case 'network-request-failed':
        return NetworkFailure(message: e.code, cause: e);
      case 'invalid-email':
      case 'weak-password':
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
      case 'user-disabled':
        return AuthFailure(message: e.code, cause: e);
      default:
        return UnknownFailure(message: e.code, cause: e);
    }
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(ref.watch(firebaseAuthDatasourceProvider));
});

/// Global-scope auth status, per FLUTTER_ARCHITECTURE.md §5 — the router's
/// redirect logic and any screen needing "am I signed in" watches this.
final authStateProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});
