import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:vikzar/design_system/theme/app_theme.dart';
import 'package:vikzar/features/profile/presentation/screens/profile_screen.dart';
import 'package:vikzar/shared/models/app_user.dart';
import 'package:vikzar/shared/models/player_profile.dart';
import 'package:vikzar/shared/models/user_workspaces.dart';
import 'package:vikzar/shared/models/workspace_type.dart';
import 'package:vikzar/shared/providers/current_app_user_provider.dart';

Future<void> _pump(WidgetTester tester, AppUser user) async {
  // ProfileScreen's ListView is taller than the default 800x600 test
  // surface — enlarge it so every section is actually rendered, not just
  // present in a lazily-built sliver below the fold.
  tester.view.physicalSize = const Size(800, 2200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final router = GoRouter(
    initialLocation: '/profile',
    routes: [
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(workspace: WorkspaceType.player),
      ),
      GoRoute(
        path: '/player/settings',
        builder: (context, state) => const SizedBox(key: Key('settings')),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [currentAppUserProvider.overrideWithValue(user)],
      child: MaterialApp.router(theme: AppTheme.dark(), routerConfig: router),
    ),
  );
}

void main() {
  group('ProfileScreen (Player)', () {
    testWidgets(
      'shows Personal/Football/Physical/Training Status sections with real '
      'onboarding data, including fields never surfaced before Phase 9',
      (tester) async {
        await _pump(
          tester,
          AppUser(
            uid: 'u1',
            email: 'p@example.com',
            displayName: 'Jai Vinush',
            workspaces: const UserWorkspaces(player: PlayerWorkspace()),
            defaultWorkspace: WorkspaceType.player,
            playerProfile: const PlayerProfile(
              level: PlayingLevel.academy,
              age: 21,
              heightCm: 182,
              weightKg: 78,
              preferredFoot: PreferredFoot.right,
              position: PlayingPosition.midfielder,
              trainingStatus: TrainingStatus.fullyAvailable,
            ),
          ),
        );

        expect(find.text('Personal'), findsOneWidget);
        expect(find.text('Football'), findsOneWidget);
        expect(find.text('Physical'), findsOneWidget);
        expect(find.text('182 cm'), findsOneWidget);
        expect(find.text('78 kg'), findsOneWidget);
        expect(find.text('Fully Available'), findsOneWidget);

        // Fully Available: no injury-detail section.
        expect(find.text('Injury Detail'), findsNothing);
      },
    );

    testWidgets(
      'shows Injury Detail only when Training Status is not Fully Available',
      (tester) async {
        await _pump(
          tester,
          AppUser(
            uid: 'u2',
            email: 'p2@example.com',
            displayName: 'Test Player',
            workspaces: const UserWorkspaces(player: PlayerWorkspace()),
            defaultWorkspace: WorkspaceType.player,
            playerProfile: const PlayerProfile(
              trainingStatus: TrainingStatus.returnToPlay,
              injuryTypes: {InjuryType.hamstring},
              recoveryTimeframe: RecoveryTimeframe.twoToFourWeeks,
            ),
          ),
        );

        expect(find.text('Injury Detail'), findsOneWidget);
        expect(find.text('Hamstring'), findsOneWidget);
        expect(find.text('2–4 weeks'), findsOneWidget);
      },
    );
  });
}
