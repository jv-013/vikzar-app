import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:vikzar/design_system/theme/app_theme.dart';
import 'package:vikzar/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:vikzar/features/auth/domain/models/auth_state.dart';
import 'package:vikzar/features/profile/presentation/screens/settings_screen.dart';
import 'package:vikzar/shared/models/workspace_type.dart';

Future<void> _pump(WidgetTester tester) async {
  final router = GoRouter(
    initialLocation: '/player/settings',
    routes: [
      GoRoute(
        path: '/player/settings',
        builder: (context, state) => const SettingsScreen(workspace: WorkspaceType.player),
      ),
      GoRoute(
        path: '/player/notifications',
        builder: (context, state) => const SizedBox(key: Key('notifications')),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authStateProvider.overrideWith(
          (ref) => Stream.value(const Authenticated(uid: 'u1', email: 'p@example.com')),
        ),
      ],
      child: MaterialApp.router(theme: AppTheme.dark(), routerConfig: router),
    ),
  );
  await tester.pump();
}

void main() {
  group('SettingsScreen', () {
    testWidgets('shows exactly Account/Notifications/Support/Sign Out sections', (tester) async {
      await _pump(tester);

      expect(find.text('Account'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('p@example.com'), findsOneWidget);
      // "Notifications" appears twice: the section header and the row title.
      expect(find.text('Notifications'), findsNWidgets(2));
      expect(find.text('Privacy'), findsOneWidget);
      // "Support" appears twice: the section header and the row title.
      expect(find.text('Support'), findsNWidgets(2));
      expect(find.text('About'), findsOneWidget);
      expect(find.text('Sign Out'), findsOneWidget);

      expect(find.text('Workspace'), findsNothing);
      expect(find.text('Bluetooth'), findsNothing);
      expect(find.text('Legal'), findsNothing);
      expect(find.text('Delete Account'), findsNothing);
    });

    testWidgets('tapping Notifications navigates to the notification center', (tester) async {
      await _pump(tester);

      await tester.tap(find.text('Notifications').last);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('notifications')), findsOneWidget);
    });

    testWidgets('tapping Privacy shows an info sheet', (tester) async {
      await _pump(tester);

      await tester.tap(find.text('Privacy'));
      await tester.pumpAndSettle();

      expect(find.textContaining('never shared outside your team'), findsOneWidget);
    });
  });
}
