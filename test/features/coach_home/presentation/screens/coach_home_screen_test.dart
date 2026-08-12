import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vikzar/design_system/theme/app_theme.dart';
import 'package:vikzar/features/coach_home/presentation/screens/coach_home_screen.dart';

Future<void> _pump(WidgetTester tester) async {
  // Home's ListView is taller than the default 800x600 test surface — a
  // plain ListView is lazy (SliverList), so content far below the fold is
  // outside the default cache extent and won't be found at all. Enlarge
  // the surface so everything renders.
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(theme: AppTheme.dark(), home: const CoachHomeScreen()),
    ),
  );
  await tester.pump();
}

void main() {
  group('CoachHomeScreen', () {
    testWidgets(
      'renders the Phase 13/15 Dashboard section list, with honest '
      'placeholders — never a fabricated squad count, session, or alert',
      (tester) async {
        await _pump(tester);

        expect(find.text("Today's Squad"), findsOneWidget);
        expect(find.text('Available'), findsOneWidget);
        expect(find.text('Individual'), findsOneWidget);
        expect(find.text('Return to Play'), findsOneWidget);
        expect(find.text('Unavailable'), findsOneWidget);
        // No team yet (no `workspaces.coach` in this test's user) — every
        // squad count is an honest dash, never a fabricated number.
        expect(find.text('—'), findsWidgets);

        expect(find.text("Today's Sessions"), findsOneWidget);
        expect(find.text('No team yet.'), findsOneWidget);
        expect(find.text('Active Alerts'), findsOneWidget);
        expect(find.text('Connected Pods'), findsOneWidget);
        expect(find.text('No Pods connected.'), findsOneWidget);
        expect(find.text('Recent Reports'), findsOneWidget);
        expect(find.text('No reports yet.'), findsOneWidget);
        expect(find.text('Recent Team Activity'), findsOneWidget);
        expect(find.text('No activity yet.'), findsOneWidget);

        expect(find.text('Quick Actions'), findsOneWidget);
        // Phase 15 dead-code pass: "Create Team" was removed from Quick Actions.
        // A coach reaching Coach Home has already created/joined a team during
        // onboarding — the button was always a dead placeholder.
        expect(find.text('Create Team'), findsNothing);
        // The remaining Phase 13 Quick Actions:
        expect(find.text('Invite Player'), findsOneWidget);
        expect(find.text('View Team'), findsOneWidget);
        expect(find.text('Notifications'), findsOneWidget);

        // Player-only vocabulary, Phase 7's superseded sections, and
        // Phase 13's removed placeholder sections must never leak into
        // the Coach Dashboard.
        expect(find.text('Roster'), findsNothing);
        expect(find.text('Recent Alerts'), findsNothing);
        expect(find.text('Team Actions'), findsNothing);
        expect(find.text('Join Team'), findsNothing);
        expect(find.text('Players Requiring Attention'), findsNothing);
        expect(find.text("Today's Training"), findsNothing);
      },
    );

    testWidgets(
      'Invite Player is disabled (not tappable) when there is no team yet — '
      'Phase 15: no team → onPressed is null, no dialog or snackbar shown',
      (tester) async {
        await _pump(tester);

        // With teamId == null the button's onPressed is null (disabled).
        final inviteButton = tester.widget<TextButton>(
          find.widgetWithText(TextButton, 'Invite Player'),
        );
        expect(
          inviteButton.onPressed,
          isNull,
          reason: 'Invite Player must be disabled when there is no team yet',
        );

        // Tapping a disabled button should produce no dialog or navigation.
        await tester.tap(find.text('Invite Player'), warnIfMissed: false);
        await tester.pumpAndSettle();

        expect(find.byType(Dialog), findsNothing);
        expect(find.byType(SnackBar), findsNothing);
      },
    );
  });
}
