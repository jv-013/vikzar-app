import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:vikzar/core/result/result.dart';
import 'package:vikzar/design_system/theme/app_theme.dart';
import 'package:vikzar/features/team/domain/models/team.dart';
import 'package:vikzar/features/team/presentation/controllers/team_roster_controller.dart';
import 'package:vikzar/features/team/presentation/screens/player_detail_screen.dart';
import 'package:vikzar/features/team/presentation/screens/team_screen.dart';
import 'package:vikzar/shared/models/app_user.dart';
import 'package:vikzar/shared/models/player_profile.dart';
import 'package:vikzar/shared/models/user_workspaces.dart';
import 'package:vikzar/shared/providers/current_app_user_provider.dart';
import 'package:vikzar/shared/repositories/user_repository_impl.dart';

const _teamId = 'team1';

Future<void> _pump(
  WidgetTester tester, {
  List<String> teamIds = const [_teamId],
  List<TeamMember> members = const [],
  Map<String, AppUser> memberUsers = const {},
}) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final router = GoRouter(
    initialLocation: '/coach/team',
    routes: [
      GoRoute(path: '/coach/team', builder: (context, state) => const TeamScreen()),
      GoRoute(
        path: '/coach/team/player/:uid',
        builder: (context, state) =>
            PlayerDetailScreen(uid: state.pathParameters['uid']!),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentAppUserProvider.overrideWithValue(
          AppUser(
            uid: 'coach1',
            email: 'coach@example.com',
            displayName: 'Coach',
            workspaces: UserWorkspaces(coach: CoachWorkspace(teamIds: teamIds)),
          ),
        ),
        if (teamIds.isNotEmpty)
          teamRosterProvider(_teamId).overrideWith((ref) => Stream.value(Result.success(members))),
        for (final entry in memberUsers.entries)
          watchUserProvider(entry.key).overrideWith(
            (ref) => Stream.value(Result.success(entry.value)),
          ),
      ],
      child: MaterialApp.router(theme: AppTheme.dark(), routerConfig: router),
    ),
  );
  await tester.pump();
}

AppUser _playerUser(String uid, String name, {TrainingStatus? status}) => AppUser(
  uid: uid,
  email: '$uid@example.com',
  displayName: name,
  workspaces: const UserWorkspaces(player: PlayerWorkspace()),
  playerProfile: PlayerProfile(trainingStatus: status),
);

void main() {
  group('TeamScreen', () {
    testWidgets('shows an honest empty state when the coach has no team', (tester) async {
      await _pump(tester, teamIds: const []);

      expect(find.text('No team yet.'), findsOneWidget);
    });

    testWidgets('shows an honest empty state when the team has no players', (tester) async {
      await _pump(tester, members: const []);

      expect(find.text('No players yet.'), findsOneWidget);
    });

    testWidgets('groups real roster members by position and shows Training Status', (
      tester,
    ) async {
      await _pump(
        tester,
        members: const [
          TeamMember(uid: 'p1', displayName: 'Alex Keeper', position: 'goalkeeper'),
          TeamMember(uid: 'p2', displayName: 'Sam Striker', position: 'forward'),
        ],
        memberUsers: {
          'p1': _playerUser('p1', 'Alex Keeper', status: TrainingStatus.fullyAvailable),
          'p2': _playerUser('p2', 'Sam Striker', status: TrainingStatus.returnToPlay),
        },
      );

      expect(find.text('Goalkeepers'), findsOneWidget);
      expect(find.text('Forwards'), findsOneWidget);
      expect(find.text('Alex Keeper'), findsOneWidget);
      expect(find.text('Sam Striker'), findsOneWidget);
      expect(find.text('Fully Available'), findsOneWidget);
      expect(find.text('Return to Play'), findsOneWidget);
    });

    testWidgets('searching filters the roster by name', (tester) async {
      await _pump(
        tester,
        members: const [
          TeamMember(uid: 'p1', displayName: 'Alex Keeper', position: 'goalkeeper'),
          TeamMember(uid: 'p2', displayName: 'Sam Striker', position: 'forward'),
        ],
        memberUsers: {
          'p1': _playerUser('p1', 'Alex Keeper'),
          'p2': _playerUser('p2', 'Sam Striker'),
        },
      );

      await tester.enterText(find.byType(TextField), 'Sam');
      await tester.pump();

      expect(find.text('Sam Striker'), findsOneWidget);
      expect(find.text('Alex Keeper'), findsNothing);
    });

    testWidgets('tapping a player navigates to Player Detail', (tester) async {
      await _pump(
        tester,
        members: const [
          TeamMember(uid: 'p1', displayName: 'Alex Keeper', position: 'goalkeeper'),
        ],
        memberUsers: {'p1': _playerUser('p1', 'Alex Keeper')},
      );

      await tester.tap(find.text('Alex Keeper'));
      await tester.pumpAndSettle();

      expect(find.text('Alex Keeper'), findsOneWidget);
      expect(find.text('Training Status'), findsOneWidget);
    });
  });
}
