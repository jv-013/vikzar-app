import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vikzar/core/result/result.dart';
import 'package:vikzar/design_system/theme/app_theme.dart';
import 'package:vikzar/features/profile/presentation/widgets/edit_profile_sheet.dart';
import 'package:vikzar/shared/models/app_user.dart';
import 'package:vikzar/shared/models/coach_profile.dart';
import 'package:vikzar/shared/models/player_profile.dart';
import 'package:vikzar/shared/models/user_workspaces.dart';
import 'package:vikzar/shared/models/workspace_type.dart';
import 'package:vikzar/shared/providers/current_app_user_provider.dart';
import 'package:vikzar/shared/providers/current_uid_provider.dart';
import 'package:vikzar/shared/repositories/user_repository.dart';
import 'package:vikzar/shared/repositories/user_repository_impl.dart';

class _FakeUserRepository implements UserRepository {
  PlayerProfile? lastPlayerProfile;

  @override
  Future<Result<void>> completeCoachOnboarding({
    required String uid,
    required String email,
    required String displayName,
    required CoachProfile profile,
    required String teamId,
  }) async => const Result.success(null);

  @override
  Future<Result<void>> completePlayerOnboarding({
    required String uid,
    required String email,
    required String displayName,
    required PlayerProfile profile,
    String? teamId,
  }) async => const Result.success(null);

  @override
  Future<Result<void>> updateCoachProfile({
    required String uid,
    required CoachProfile profile,
  }) async => const Result.success(null);

  @override
  Future<Result<void>> updateDisplayName({
    required String uid,
    required String displayName,
  }) async => const Result.success(null);

  @override
  Future<Result<void>> updatePlayerProfile({
    required String uid,
    required PlayerProfile profile,
  }) async {
    lastPlayerProfile = profile;
    return const Result.success(null);
  }

  @override
  Stream<Result<AppUser?>> watchUser(String uid) => Stream.value(const Result.success(null));
}

Future<_FakeUserRepository> _pump(WidgetTester tester, {required PlayerProfile playerProfile}) async {
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final fakeRepository = _FakeUserRepository();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUidProvider.overrideWithValue('u1'),
        currentAppUserProvider.overrideWithValue(
          AppUser(
            uid: 'u1',
            email: 'p@example.com',
            displayName: 'Jai Vinush',
            workspaces: const UserWorkspaces(player: PlayerWorkspace()),
            playerProfile: playerProfile,
          ),
        ),
        userRepositoryProvider.overrideWithValue(fakeRepository),
      ],
      child: MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => EditProfileSheet.show(context, workspace: WorkspaceType.player),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();

  return fakeRepository;
}

void main() {
  group('EditProfileSheet (Player)', () {
    testWidgets('prefills Height/Weight/Level/Training Status from the real profile', (
      tester,
    ) async {
      await _pump(
        tester,
        playerProfile: const PlayerProfile(
          heightCm: 182,
          weightKg: 78,
          level: PlayingLevel.academy,
          trainingStatus: TrainingStatus.fullyAvailable,
        ),
      );

      expect(find.text('182'), findsOneWidget);
      expect(find.text('78'), findsOneWidget);
      expect(find.text('Injury Type'), findsNothing);
    });

    testWidgets(
      'reveals Injury Type/Expected Recovery only once Training Status is not Fully Available',
      (tester) async {
        await _pump(tester, playerProfile: const PlayerProfile());

        expect(find.text('Injury Type'), findsNothing);

        await tester.tap(find.text('Select Status'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Unavailable'));
        await tester.pumpAndSettle();

        expect(find.text('Injury Type'), findsOneWidget);
        expect(find.text('Expected Recovery'), findsOneWidget);
      },
    );

    testWidgets('saving clears injury detail when Training Status reverts to Fully Available', (
      tester,
    ) async {
      final repository = await _pump(
        tester,
        playerProfile: const PlayerProfile(
          trainingStatus: TrainingStatus.unavailable,
          injuryTypes: {InjuryType.hamstring},
          recoveryTimeframe: RecoveryTimeframe.twoToFourWeeks,
        ),
      );

      await tester.tap(find.text('Unavailable').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fully Available'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(repository.lastPlayerProfile?.trainingStatus, TrainingStatus.fullyAvailable);
      expect(repository.lastPlayerProfile?.injuryTypes, isEmpty);
      expect(repository.lastPlayerProfile?.recoveryTimeframe, isNull);
    });

    testWidgets('saving with injury detail visible persists the selected type and timeframe', (
      tester,
    ) async {
      final repository = await _pump(
        tester,
        playerProfile: const PlayerProfile(trainingStatus: TrainingStatus.returnToPlay),
      );

      await tester.tap(find.text('Ankle'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2–4 weeks'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(repository.lastPlayerProfile?.trainingStatus, TrainingStatus.returnToPlay);
      expect(repository.lastPlayerProfile?.injuryTypes, {InjuryType.ankle});
      expect(repository.lastPlayerProfile?.recoveryTimeframe, RecoveryTimeframe.twoToFourWeeks);
    });
  });
}
