import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/result/result.dart';
import '../../domain/models/auth_state.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_datasource.dart';
import '../datasources/firebase_auth_datasource.dart';

/// The provider-cancellation codes the datasource layer uses to signal
/// "the user backed out of the picker/sheet" — not a failure, per
/// [AuthRepository.signInWithGoogle]/[signInWithApple]'s contract.
const _cancellationCodes = {'google-sign-in-cancelled', 'apple-sign-in-cancelled'};

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
  Future<Result<void>> signInWithGoogle() => _guard(_datasource.signInWithGoogle);

  @override
  Future<Result<void>> signInWithApple() => _guard(_datasource.signInWithApple);

  @override
  Future<Result<void>> sendSignInLinkToEmail(String email) =>
      _guard(() => _datasource.sendSignInLinkToEmail(email));

  @override
  bool isSignInWithEmailLink(String link) => _datasource.isSignInWithEmailLink(link);

  @override
  Future<Result<void>> signInWithEmailLink({required String email, required String emailLink}) =>
      _guard(() => _datasource.signInWithEmailLink(email: email, emailLink: emailLink));

  @override
  Future<Result<void>> signOut() => _guard(_datasource.signOut);

  Future<Result<void>> _guard(Future<void> Function() action) async {
    try {
      await action();
      return const Result.success(null);
    } on AuthDatasourceException catch (e) {
      if (_cancellationCodes.contains(e.code)) {
        return const Result.success(null);
      }
      return Result.failure(_mapException(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }

  Failure _mapException(AuthDatasourceException e) {
    switch (e.code) {
      case 'network-request-failed':
        return NetworkFailure(message: e.code, cause: e);
      case 'invalid-email':
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
      case 'user-disabled':
      case 'account-exists-with-different-credential':
      case 'invalid-action-code':
      case 'expired-action-code':
      case 'invalid-email-link':
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
