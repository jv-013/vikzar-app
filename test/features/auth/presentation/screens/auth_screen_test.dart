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
  Result<void>? nextSendOtpResult;
  Result<void>? nextVerifyOtpResult;
  bool sendOtpCalled = false;
  bool verifyOtpCalled = false;
  String? lastVerifiedEmail;

  @override
  Stream<AuthState> get authStateChanges => const Stream.empty();

  @override
  Future<Result<void>> sendOtp({required String email}) async {
    sendOtpCalled = true;
    return nextSendOtpResult ?? const Result.success(null);
  }

  @override
  Future<Result<void>> verifyOtp({
    required String email,
    required String code,
  }) async {
    verifyOtpCalled = true;
    lastVerifiedEmail = email;
    return nextVerifyOtpResult ?? const Result.success(null);
  }

  @override
  Future<Result<void>> signOut() async => const Result.success(null);
}

void main() {
  group('AuthScreen', () {
    testWidgets('renders the email step with no password field anywhere', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [authRepositoryProvider.overrideWithValue(_FakeAuthRepository())],
          child: MaterialApp(theme: AppTheme.dark(), home: const AuthScreen()),
        ),
      );

      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsNothing);
      expect(find.text('Continue'), findsOneWidget);
    });

    testWidgets(
      'submitting an email advances to the 6-digit code step and shows '
      'that email back to the user',
      (tester) async {
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
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();

        expect(fakeRepository.sendOtpCalled, isTrue);
        expect(find.text('Enter the code we sent you.'), findsOneWidget);
        expect(find.textContaining('jai@vikzar.app'), findsOneWidget);
      },
    );

    testWidgets('entering a 6-digit code verifies it', (tester) async {
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
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, '123456');
      await tester.pumpAndSettle();

      expect(fakeRepository.verifyOtpCalled, isTrue);
      expect(fakeRepository.lastVerifiedEmail, 'jai@vikzar.app');
    });

    testWidgets('shows a calm, mapped error message on a failed code — '
        'never a raw error code', (tester) async {
      final fakeRepository = _FakeAuthRepository()
        ..nextVerifyOtpResult = const Result.failure(
          AuthFailure(message: 'invalid-credential'),
        );
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
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, '123456');
      await tester.pumpAndSettle();

      expect(find.text("That code didn't work. Please try again."), findsOneWidget);
      expect(find.text('invalid-credential'), findsNothing);
    });
  });
}
