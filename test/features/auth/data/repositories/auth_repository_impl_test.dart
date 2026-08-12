import 'package:flutter_test/flutter_test.dart';

import 'package:vikzar/features/auth/data/datasources/auth_datasource.dart';
import 'package:vikzar/features/auth/data/repositories/auth_repository_impl.dart';

import '../datasources/fake_auth_datasource.dart';

void main() {
  group('AuthRepositoryImpl', () {
    test('signInWithGoogle succeeds and delegates', () async {
      final datasource = FakeAuthDatasource();
      final repository = AuthRepositoryImpl(datasource);

      final result = await repository.signInWithGoogle();

      expect(result.isSuccess, isTrue);
      expect(datasource.signInWithGoogleCalled, isTrue);
    });

    test('signInWithGoogle handles cancellation gracefully', () async {
      final datasource = _AlwaysThrowsOnAction('google-sign-in-cancelled');
      final repository = AuthRepositoryImpl(datasource);

      final result = await repository.signInWithGoogle();

      expect(result.isSuccess, isTrue, reason: 'Cancellation is not an error');
    });

    test('signInWithApple succeeds and delegates', () async {
      final datasource = FakeAuthDatasource();
      final repository = AuthRepositoryImpl(datasource);

      final result = await repository.signInWithApple();

      expect(result.isSuccess, isTrue);
      expect(datasource.signInWithAppleCalled, isTrue);
    });

    test('sendSignInLinkToEmail delegates', () async {
      final datasource = FakeAuthDatasource();
      final repository = AuthRepositoryImpl(datasource);

      final result = await repository.sendSignInLinkToEmail('jai@vikzar.app');

      expect(result.isSuccess, isTrue);
      expect(datasource.sendSignInLinkCalled, isTrue);
      expect(datasource.lastLinkSent, 'jai@vikzar.app');
    });

    test('signInWithEmailLink delegates', () async {
      final datasource = FakeAuthDatasource()..existingAccounts['jai@vikzar.app'] = 'secret';
      final repository = AuthRepositoryImpl(datasource);

      final result = await repository.signInWithEmailLink(
        email: 'jai@vikzar.app',
        emailLink: 'https://vikzar.firebaseapp.com/__/auth/action',
      );

      expect(result.isSuccess, isTrue);
    });

    test('signOut delegates', () async {
      final datasource = FakeAuthDatasource();
      final repository = AuthRepositoryImpl(datasource);

      final result = await repository.signOut();

      expect(result.isSuccess, isTrue);
      expect(datasource.signOutCalled, isTrue);
    });
  });
}

class _AlwaysThrowsOnAction extends FakeAuthDatasource {
  _AlwaysThrowsOnAction(this.code);
  final String code;

  @override
  Future<void> signInWithGoogle() async => throw AuthDatasourceException(code);

  @override
  Future<void> signInWithApple() async => throw AuthDatasourceException(code);
}
