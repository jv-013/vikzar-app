import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vikzar/design_system/theme/app_theme.dart';
import 'package:vikzar/routing/shells/app_shell_scaffold.dart';
import 'package:vikzar/services/local_storage/shared_preferences_provider.dart';
import 'package:vikzar/shared/models/workspace_type.dart';

GoRouter _shellRouterFor(WorkspaceType workspace, List<String> paths) {
  return GoRouter(
    initialLocation: paths.first,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShellScaffold(workspace: workspace, navigationShell: navigationShell),
        branches: [
          for (final path in paths)
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: path,
                  builder: (context, state) => Center(child: Text('screen:$path')),
                ),
              ],
            ),
        ],
      ),
    ],
  );
}

void main() {
  group('AppShellScaffold', () {
    testWidgets('Player workspace shows exactly the 4 spec bottom-nav items, '
        'and tapping one switches the visible branch', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final router = _shellRouterFor(WorkspaceType.player, [
        '/player/home',
        '/player/timeline',
        '/player/history',
        '/player/profile',
      ]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: MaterialApp.router(theme: AppTheme.dark(), routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Timeline'), findsOneWidget);
      expect(find.text('History'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
      expect(find.text('Live'), findsNothing);
      expect(find.text('screen:/player/home'), findsOneWidget);

      await tester.tap(find.text('Timeline'));
      await tester.pumpAndSettle();

      expect(find.text('screen:/player/timeline'), findsOneWidget);
      expect(find.text('screen:/player/home'), findsNothing);
    });

    testWidgets('Coach workspace shows exactly the 5 spec bottom-nav items', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final router = _shellRouterFor(WorkspaceType.coach, [
        '/coach/home',
        '/coach/live',
        '/coach/team',
        '/coach/alerts',
        '/coach/profile',
      ]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: MaterialApp.router(theme: AppTheme.dark(), routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Live'), findsOneWidget);
      expect(find.text('Team'), findsOneWidget);
      expect(find.text('Alerts'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
      expect(find.text('Timeline'), findsNothing);
    });
  });
}
