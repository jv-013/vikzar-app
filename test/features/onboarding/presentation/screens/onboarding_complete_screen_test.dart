import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vikzar/core/result/result.dart';
import 'package:vikzar/design_system/theme/app_theme.dart';
import 'package:vikzar/features/onboarding/presentation/screens/onboarding_complete_screen.dart';
import 'package:vikzar/shared/models/app_user.dart';
import 'package:vikzar/shared/models/coach_profile.dart';
import 'package:vikzar/shared/models/player_profile.dart';
import 'package:vikzar/shared/models/workspace_type.dart';
import 'package:vikzar/shared/providers/current_uid_provider.dart';
import 'package:vikzar/shared/repositories/user_repository.dart';
import 'package:vikzar/shared/repositories/user_repository_impl.dart';

const _uid = 'uid_123';

/// Records whether `completePlayerOnboarding` was called — Phase 8B
/// (DECISIONS.md ADR-051) turned "Get Started" into a real Firestore
/// write, so this fake stands in for `UserRepositoryImpl` the same way
/// `_FakeAuthRepository`-style fakes already do elsewhere in this suite,
/// letting the test assert the write happens exactly once, only on tap.
class _RecordingUserRepository implements UserRepository {
  bool completeCalled = false;

  @override
  Future<Result<void>> completePlayerOnboarding({
    required String uid,
    required String email,
    required String displayName,
    required PlayerProfile profile,
    String? teamId,
  }) async {
    completeCalled = true;
    return const Result.success(null);
  }

  @override
  Future<Result<void>> completeCoachOnboarding({
    required String uid,
    required String email,
    required String displayName,
    required CoachProfile profile,
    required String teamId,
  }) async {
    completeCalled = true;
    return const Result.success(null);
  }

  @override
  Future<Result<void>> updateDisplayName({
    required String uid,
    required String displayName,
  }) async => const Result.success(null);

  @override
  Future<Result<void>> updatePlayerProfile({
    required String uid,
    required PlayerProfile profile,
  }) async => const Result.success(null);

  @override
  Future<Result<void>> updateCoachProfile({
    required String uid,
    required CoachProfile profile,
  }) async => const Result.success(null);

  @override
  Stream<Result<AppUser?>> watchUser(String uid) => Stream.value(const Result.success(null));
}

void main() {
  group('OnboardingCompleteScreen', () {
    testWidgets('renders a calm confirmation and does not write to '
        'Firestore until "Get Started" is tapped', (tester) async {
      final repository = _RecordingUserRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUidProvider.overrideWithValue(_uid),
            currentUserEmailProvider.overrideWithValue('p@vikzar.app'),
            userRepositoryProvider.overrideWithValue(repository),
          ],
          child: MaterialApp(
            theme: AppTheme.dark(),
            home: const OnboardingCompleteScreen(workspace: WorkspaceType.player),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("You're all set."), findsOneWidget);
      expect(find.text('Your Player workspace is ready.'), findsOneWidget);
      expect(
        repository.completeCalled,
        isFalse,
        reason: 'marking complete must be an explicit action, never automatic',
      );

      await tester.tap(find.text('Get Started'));
      await tester.pumpAndSettle();

      expect(repository.completeCalled, isTrue);
    });
  });
}
