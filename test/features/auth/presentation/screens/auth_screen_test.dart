import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vikzar/core/result/result.dart';
import 'package:vikzar/design_system/theme/app_theme.dart';
import 'package:vikzar/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:vikzar/features/auth/domain/models/auth_state.dart';
import 'package:vikzar/features/auth/domain/repositories/auth_repository.dart';
import 'package:vikzar/features/auth/presentation/screens/auth_screen.dart';
import 'package:vikzar/services/local_storage/shared_preferences_provider.dart';

class _FakeAuthRepository implements AuthRepository {
  bool sendSignInLinkCalled = false;
  String? lastEmailSent;

  @override
  Stream<AuthState> get authStateChanges => const Stream.empty();

  @override
  Future<Result<void>> signInWithGoogle() async => const Result.success(null);

  @override
  Future<Result<void>> signInWithApple() async => const Result.success(null);

  @override
  Future<Result<void>> sendSignInLinkToEmail(String email) async {
    sendSignInLinkCalled = true;
    lastEmailSent = email;
    return const Result.success(null);
  }

  @override
  bool isSignInWithEmailLink(String link) => false;

  @override
  Future<Result<void>> signInWithEmailLink({
    required String email,
    required String emailLink,
  }) async =>
      const Result.success(null);

  @override
  Future<Result<void>> signOut() async => const Result.success(null);
}

/// Builds a full ProviderScope override with both auth and SharedPreferences,
/// and a tall viewport so the scrollable AuthScreen content fits entirely.
///
/// AuthController (Phase 17) reads:
///   pendingEmailLinkStoreProvider → sharedPreferencesProvider
/// which throws if not overridden — hence both must be provided.
Future<void> _pump(
  WidgetTester tester,
  _FakeAuthRepository fakeRepo,
  SharedPreferences prefs,
) async {
  // AuthScreen uses SingleChildScrollView with substantial vertical padding.
  // Ensure the full content (including the "Email me a link" button) fits
  // inside the render surface so it can be found and tapped.
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(fakeRepo),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: MaterialApp(theme: AppTheme.dark(), home: const AuthScreen()),
    ),
  );
  await tester.pump();
}

void main() {
  group('AuthScreen', () {
    testWidgets('renders the email form with no password field anywhere', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await _pump(tester, _FakeAuthRepository(), prefs);

      // Phase 17: no password, no OTP code.
      expect(find.text('Password'), findsNothing);
      // The magic-link button is present on initial load.
      expect(find.text('Email me a link'), findsOneWidget);
      // Google sign-in is always present (Apple only on iOS/macOS).
      expect(find.text('Continue with Google'), findsOneWidget);
    });

    testWidgets(
      'submitting an email calls sendSignInLinkToEmail and shows the link-sent confirmation',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final fakeRepo = _FakeAuthRepository();
        await _pump(tester, fakeRepo, prefs);

        // Enter email into the first (only) TextField on screen.
        await tester.enterText(find.byType(TextField).first, 'jai@vikzar.app');
        // Tap the magic-link trigger button.
        await tester.tap(find.text('Email me a link'));
        await tester.pumpAndSettle();

        // The controller called sendSignInLinkToEmail on the repository.
        expect(fakeRepo.sendSignInLinkCalled, isTrue);
        expect(fakeRepo.lastEmailSent, 'jai@vikzar.app');
        // Phase 17 "check your email" confirmation — trailing period is intentional.
        expect(find.text('Check your email.'), findsOneWidget);
      },
    );
  });
}
