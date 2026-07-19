import 'package:flutter_test/flutter_test.dart';

import 'package:vikzar/core/errors/failure.dart';
import 'package:vikzar/features/auth/data/datasources/auth_datasource.dart';
import 'package:vikzar/features/auth/data/repositories/auth_repository_impl.dart';

import '../datasources/fake_auth_datasource.dart';

void main() {
  group('AuthRepositoryImpl.signInOrCreateAccount', () {
    test('signs in successfully when the account and password match', () async {
      final datasource = FakeAuthDatasource()
        ..existingAccounts['jai@vikzar.app'] = 'correct-password';
      final repository = AuthRepositoryImpl(datasource);

      final result = await repository.signInOrCreateAccount(
        email: 'jai@vikzar.app',
        password: 'correct-password',
      );

      expect(result.isSuccess, isTrue);
    });

    test(
      'creates the account when no account exists for the email '
      '(user-not-found)',
      () async {
        final datasource = FakeAuthDatasource();
        final repository = AuthRepositoryImpl(datasource);

        final result = await repository.signInOrCreateAccount(
          email: 'new@vikzar.app',
          password: 'a-new-password',
        );

        expect(result.isSuccess, isTrue);
        expect(datasource.existingAccounts['new@vikzar.app'], 'a-new-password');
      },
    );

    test('surfaces "incorrect password" rather than creating a duplicate '
        'account when the password is wrong', () async {
      final datasource = FakeAuthDatasource()
        ..existingAccounts['jai@vikzar.app'] = 'correct-password';
      final repository = AuthRepositoryImpl(datasource);

      final result = await repository.signInOrCreateAccount(
        email: 'jai@vikzar.app',
        password: 'wrong-password-attempt',
      );

      expect(result.isFailure, isTrue);
      final failure = result.fold(
        onSuccess: (_) => null,
        onFailure: (f) => f,
      );
      expect(failure, isA<AuthFailure>());
      expect((failure as AuthFailure).message, 'wrong-password');
      // Never attempted to create a duplicate account.
      expect(datasource.existingAccounts['jai@vikzar.app'], 'correct-password');
    });

    test(
      'surfaces the original sign-in failure when create-account fails '
      'with email-already-in-use (the newer-SDK invalid-credential path)',
      () async {
        // Simulates a Firebase Auth SDK version that returns the
        // consolidated 'invalid-credential' code instead of
        // 'wrong-password' for a mismatched password: the repository must
        // still attempt create-account (invalid-credential is in its
        // no-account-error set), get email-already-in-use back, and
        // surface the *original* invalid-credential failure rather than
        // the confusing "already in use" one.
        final datasource = _InvalidCredentialOnWrongPassword()
          ..existingAccounts['jai@vikzar.app'] = 'correct-password';
        final repository = AuthRepositoryImpl(datasource);

        final result = await repository.signInOrCreateAccount(
          email: 'jai@vikzar.app',
          password: 'wrong-password-attempt',
        );

        expect(result.isFailure, isTrue);
        final failure = result.fold(onSuccess: (_) => null, onFailure: (f) => f);
        expect(failure, isA<AuthFailure>());
        expect((failure as AuthFailure).message, 'invalid-credential');
      },
    );

    test('maps an unrelated sign-in failure without attempting create', () async {
      final datasource = _AlwaysThrowsOnSignIn('invalid-email');

      final repository = AuthRepositoryImpl(datasource);

      final result = await repository.signInOrCreateAccount(
        email: 'not-an-email',
        password: 'whatever',
      );

      expect(result.isFailure, isTrue);
      final failure = result.fold(onSuccess: (_) => null, onFailure: (f) => f);
      expect(failure, isA<AuthFailure>());
      expect((failure as AuthFailure).message, 'invalid-email');
      expect(
        datasource.createAccountCalled,
        isFalse,
        reason:
            'invalid-email is not a no-account error; create must never be attempted',
      );
    });
  });

  group('AuthRepositoryImpl.signOut', () {
    test('delegates to the datasource', () async {
      final datasource = FakeAuthDatasource();
      final repository = AuthRepositoryImpl(datasource);

      final result = await repository.signOut();

      expect(result.isSuccess, isTrue);
      expect(datasource.signOutCalled, isTrue);
    });
  });
}

/// Like [FakeAuthDatasource], but `signIn` throws `invalid-credential`
/// instead of `wrong-password` on a mismatch — simulating the
/// enumeration-protected Firebase Auth SDK behaviour.
class _InvalidCredentialOnWrongPassword extends FakeAuthDatasource {
  @override
  Future<void> signIn({required String email, required String password}) async {
    if (!existingAccounts.containsKey(email)) {
      throw const AuthDatasourceException('invalid-credential');
    }
    if (existingAccounts[email] != password) {
      throw const AuthDatasourceException('invalid-credential');
    }
  }
}

/// A datasource whose `signIn` always throws the given error code, useful
/// for exercising codes outside the "no account" set.
class _AlwaysThrowsOnSignIn extends FakeAuthDatasource {
  _AlwaysThrowsOnSignIn(this.code);

  final String code;
  bool createAccountCalled = false;

  @override
  Future<void> signIn({required String email, required String password}) async {
    throw AuthDatasourceException(code);
  }

  @override
  Future<void> createAccount({
    required String email,
    required String password,
  }) async {
    createAccountCalled = true;
    return super.createAccount(email: email, password: password);
  }
}
