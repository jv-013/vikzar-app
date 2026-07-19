import 'package:flutter_test/flutter_test.dart';

import 'package:vikzar/core/errors/failure.dart';
import 'package:vikzar/features/auth/data/datasources/auth_datasource.dart';
import 'package:vikzar/features/auth/data/repositories/auth_repository_impl.dart';

import '../datasources/fake_auth_datasource.dart';

void main() {
  group('AuthRepositoryImpl.sendOtp', () {
    test('succeeds and delegates to the datasource', () async {
      final datasource = FakeAuthDatasource();
      final repository = AuthRepositoryImpl(datasource);

      final result = await repository.sendOtp(email: 'jai@vikzar.app');

      expect(result.isSuccess, isTrue);
      expect(datasource.sendOtpCalled, isTrue);
    });

    test('maps a datasource failure', () async {
      final datasource = _AlwaysThrowsOnSendOtp('network-request-failed');
      final repository = AuthRepositoryImpl(datasource);

      final result = await repository.sendOtp(email: 'jai@vikzar.app');

      expect(result.isFailure, isTrue);
      final failure = result.fold(onSuccess: (_) => null, onFailure: (f) => f);
      expect(failure, isA<NetworkFailure>());
    });
  });

  group('AuthRepositoryImpl.verifyOtp', () {
    test('rejects a code that is not exactly 6 digits, without touching '
        'the datasource', () async {
      final datasource = FakeAuthDatasource();
      final repository = AuthRepositoryImpl(datasource);

      final result = await repository.verifyOtp(
        email: 'jai@vikzar.app',
        code: '12345',
      );

      expect(result.isFailure, isTrue);
      final failure = result.fold(onSuccess: (_) => null, onFailure: (f) => f);
      expect(failure, isA<AuthFailure>());
      expect((failure as AuthFailure).message, 'invalid-otp-format');
      expect(datasource.existingAccounts, isEmpty);
    });

    test('creates the account on first verification for a new email', () async {
      final datasource = FakeAuthDatasource();
      final repository = AuthRepositoryImpl(datasource);

      final result = await repository.verifyOtp(
        email: 'new@vikzar.app',
        code: '123456',
      );

      expect(result.isSuccess, isTrue);
      expect(datasource.existingAccounts.containsKey('new@vikzar.app'), isTrue);
    });

    test(
      'signs in on a second verification for the same email — the derived '
      'credential is deterministic per email, so the account created on '
      'the first call is found on the second',
      () async {
        final datasource = FakeAuthDatasource();
        final repository = AuthRepositoryImpl(datasource);

        final first = await repository.verifyOtp(
          email: 'returning@vikzar.app',
          code: '111111',
        );
        final second = await repository.verifyOtp(
          email: 'returning@vikzar.app',
          code: '222222',
        );

        expect(first.isSuccess, isTrue);
        expect(second.isSuccess, isTrue);
      },
    );

    test(
      'surfaces the original sign-in failure when create-account fails '
      'with email-already-in-use — a defensive path for an account whose '
      'stored credential does not match this build\'s derivation (e.g. '
      'created under a prior derivation-secret version)',
      () async {
        final datasource = _InvalidCredentialAlways()
          ..existingAccounts['jai@vikzar.app'] = 'some-other-secret';
        final repository = AuthRepositoryImpl(datasource);

        final result = await repository.verifyOtp(
          email: 'jai@vikzar.app',
          code: '123456',
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

      final result = await repository.verifyOtp(
        email: 'not-an-email',
        code: '123456',
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

/// A datasource whose `sendOtp` always throws the given error code.
class _AlwaysThrowsOnSendOtp extends FakeAuthDatasource {
  _AlwaysThrowsOnSendOtp(this.code);

  final String code;

  @override
  Future<void> sendOtp({required String email}) async {
    throw AuthDatasourceException(code);
  }
}

/// Like [FakeAuthDatasource], but `signIn` always throws `invalid-credential`
/// regardless of the derived secret — simulating an account whose stored
/// credential can never match this build's derivation.
class _InvalidCredentialAlways extends FakeAuthDatasource {
  @override
  Future<void> signIn({required String email, required String secret}) async {
    if (!existingAccounts.containsKey(email)) {
      throw const AuthDatasourceException('invalid-credential');
    }
    throw const AuthDatasourceException('invalid-credential');
  }
}

/// A datasource whose `signIn` always throws the given error code, useful
/// for exercising codes outside the "no account" set.
class _AlwaysThrowsOnSignIn extends FakeAuthDatasource {
  _AlwaysThrowsOnSignIn(this.code);

  final String code;
  bool createAccountCalled = false;

  @override
  Future<void> signIn({required String email, required String secret}) async {
    throw AuthDatasourceException(code);
  }

  @override
  Future<void> createAccount({
    required String email,
    required String secret,
  }) async {
    createAccountCalled = true;
    return super.createAccount(email: email, secret: secret);
  }
}
