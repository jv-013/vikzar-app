import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vikzar/core/errors/failure.dart';
import 'package:vikzar/core/result/result.dart';
import 'package:vikzar/design_system/theme/app_theme.dart';
import 'package:vikzar/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:vikzar/features/auth/domain/models/auth_state.dart';
import 'package:vikzar/features/auth/domain/repositories/auth_repository.dart';
import 'package:vikzar/features/auth/presentation/screens/auth_screen.dart';

class _FakeAuthRepository implements AuthRepository {
  Result<void>? nextResult;
  bool submitCalled = false;

  @override
  Stream<AuthState> get authStateChanges => const Stream.empty();

  @override
  Future<Result<void>> signInOrCreateAccount({
    required String email,
    required String password,
  }) async {
    submitCalled = true;
    return nextResult ?? const Result.success(null);
  }

  @override
  Future<Result<void>> signOut() async => const Result.success(null);
}

void main() {
  group('AuthScreen', () {
    testWidgets('renders one email field, one password field, one Continue '
        'button — per DESIGN_SPECIFICATION.md §19.1', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [authRepositoryProvider.overrideWithValue(_FakeAuthRepository())],
          child: MaterialApp(theme: AppTheme.dark(), home: const AuthScreen()),
        ),
      );

      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
      // No separate "Sign Up" toggle/button — one screen, one action.
      expect(find.text('Sign Up'), findsNothing);
      expect(find.text('Sign In'), findsNothing);
    });

    testWidgets('submits the entered email/password to the repository', (
      tester,
    ) async {
      final fakeRepository = _FakeAuthRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [authRepositoryProvider.overrideWithValue(fakeRepository)],
          child: MaterialApp(theme: AppTheme.dark(), home: const AuthScreen()),
        ),
      );

      await tester.enterText(
        find.widgetWithText(TextField, 'Email'),
        'jai@vikzar.app',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Password'),
        'a-password',
      );
      await tester.tap(find.text('Continue'));
      await tester.pump();

      expect(fakeRepository.submitCalled, isTrue);
    });

    testWidgets('shows a calm, mapped error message on failure — never a '
        'raw error code', (tester) async {
      final fakeRepository = _FakeAuthRepository()
        ..nextResult = const Result.failure(AuthFailure(message: 'wrong-password'));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [authRepositoryProvider.overrideWithValue(fakeRepository)],
          child: MaterialApp(theme: AppTheme.dark(), home: const AuthScreen()),
        ),
      );

      await tester.enterText(find.widgetWithText(TextField, 'Email'), 'a@b.com');
      await tester.enterText(find.widgetWithText(TextField, 'Password'), 'x');
      await tester.tap(find.text('Continue'));
      await tester.pump();

      expect(find.text('Incorrect email or password.'), findsOneWidget);
      expect(find.text('wrong-password'), findsNothing);
    });
  });
}
