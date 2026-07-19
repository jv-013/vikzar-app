import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vikzar/features/coach_home/presentation/screens/coach_home_screen.dart';

void main() {
  group('CoachHomeScreen', () {
    testWidgets(
      'renders a team-level layout distinct from Player Home, with honest '
      'placeholders — never a fabricated roster or alert count',
      (tester) async {
        // Home's ListView is taller than the default 800x600 test
        // surface — a plain ListView is lazy (SliverList), so content far
        // below the fold is outside the default cache extent and won't be
        // found at all. Enlarge the surface so everything renders.
        tester.view.physicalSize = const Size(800, 2000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(home: CoachHomeScreen()),
          ),
        );

        // Coach-specific sections absent from Player Home.
        expect(find.text('Roster'), findsOneWidget);
        expect(find.text('No players yet.'), findsOneWidget);
        expect(find.text("Today's Sessions"), findsOneWidget);
        expect(find.text('Recent Alerts'), findsOneWidget);
        expect(find.text('No alerts.'), findsOneWidget);
        expect(find.text('Team Actions'), findsOneWidget);
        expect(find.text('Invite Player'), findsWidgets);
        expect(find.text('Create Team'), findsOneWidget);
        expect(find.text('Join Team'), findsOneWidget);
        // Never a fabricated count — the placeholder is an em dash.
        expect(find.text('—'), findsNWidgets(3));

        // Player-only vocabulary must never leak into Coach Home.
        expect(find.text('Quick Actions'), findsNothing);
        expect(find.text('Impact Summary'), findsNothing);
      },
    );
  });
}
