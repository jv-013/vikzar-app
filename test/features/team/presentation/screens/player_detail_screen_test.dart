import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vikzar/core/result/result.dart';
import 'package:vikzar/design_system/theme/app_theme.dart';
import 'package:vikzar/features/team/presentation/screens/player_detail_screen.dart';
import 'package:vikzar/shared/models/app_user.dart';
import 'package:vikzar/shared/models/player_profile.dart';
import 'package:vikzar/shared/models/user_workspaces.dart';
import 'package:vikzar/shared/repositories/user_repository_impl.dart';

Future<void> _pump(WidgetTester tester, {required AppUser? user}) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        watchUserProvider('p1').overrideWith((ref) => Stream.value(Result.success(user))),
      ],
      child: MaterialApp(theme: AppTheme.dark(), home: const PlayerDetailScreen(uid: 'p1')),
    ),
  );
  await tester.pump();
}

void main() {
  group('PlayerDetailScreen', () {
    testWidgets(
      'shows Training Status plus honest empty states for Session/Activity/AI/Notes — '
      'no injury detail when Fully Available',
      (tester) async {
        await _pump(
          tester,
          user: AppUser(
            uid: 'p1',
            email: 'p1@example.com',
            displayName: 'Alex Keeper',
            workspaces: const UserWorkspaces(player: PlayerWorkspace()),
            playerProfile: const PlayerProfile(
              position: PlayingPosition.goalkeeper,
              trainingStatus: TrainingStatus.fullyAvailable,
            ),
          ),
        );

        expect(find.text('Alex Keeper'), findsOneWidget);
        expect(find.text('Goalkeeper'), findsOneWidget);
        expect(find.text('Fully Available'), findsOneWidget);
        expect(find.text('Injury Detail'), findsNothing);

        expect(find.text('Latest Session'), findsOneWidget);
        expect(find.text('No sessions yet.'), findsOneWidget);
        expect(find.text('Recent Activity'), findsOneWidget);
        expect(find.text('No activity yet.'), findsOneWidget);
        expect(find.text('Future AI'), findsOneWidget);
        expect(find.text('Coach Notes'), findsOneWidget);
        expect(find.text('No notes yet.'), findsOneWidget);
      },
    );

    testWidgets('shows Injury Detail when Training Status is not Fully Available', (
      tester,
    ) async {
      await _pump(
        tester,
        user: AppUser(
          uid: 'p1',
          email: 'p1@example.com',
          displayName: 'Alex Keeper',
          workspaces: const UserWorkspaces(player: PlayerWorkspace()),
          playerProfile: const PlayerProfile(
            trainingStatus: TrainingStatus.unavailable,
            injuryTypes: {InjuryType.ankle},
            recoveryTimeframe: RecoveryTimeframe.oneToTwoMonths,
          ),
        ),
      );

      expect(find.text('Injury Detail'), findsOneWidget);
      expect(find.text('Ankle'), findsOneWidget);
      expect(find.text('1–2 months'), findsOneWidget);
    });

    testWidgets('shows an honest empty state when the player is not found', (tester) async {
      await _pump(tester, user: null);

      expect(find.text('Player not found.'), findsOneWidget);
    });
  });
}
