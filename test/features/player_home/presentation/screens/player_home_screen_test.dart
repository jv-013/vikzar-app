import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:vikzar/design_system/theme/app_theme.dart';
import 'package:vikzar/features/player_home/presentation/screens/player_home_screen.dart';

void main() {
  group('PlayerHomeScreen', () {
    testWidgets(
      'renders every Phase 9 section with honest placeholders, never a '
      'fabricated session or football event',
      (tester) async {
        // Home's ListView is taller than the default 800x600 test
        // surface — a plain ListView is lazy (SliverList), so content far
        // below the fold is outside the default cache extent and won't be
        // found at all, not just unable to be tapped. Enlarge the surface
        // so everything renders.
        tester.view.physicalSize = const Size(800, 2200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final router = GoRouter(
          initialLocation: '/home',
          routes: [
            GoRoute(path: '/home', builder: (context, state) => const PlayerHomeScreen()),
            GoRoute(
              path: '/player/timeline',
              builder: (context, state) => const SizedBox(key: Key('timeline')),
            ),
            GoRoute(
              path: '/player/notifications',
              builder: (context, state) => const SizedBox(key: Key('notifications')),
            ),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp.router(theme: AppTheme.dark(), routerConfig: router),
          ),
        );
        await tester.pump(); // let the notification stream emit its first value

        expect(find.textContaining('Good '), findsOneWidget); // time-of-day greeting
        expect(find.text("Today's Status"), findsOneWidget);
        expect(find.text('No data yet.'), findsOneWidget); // no profile in this test
        expect(find.text('Pod Status'), findsOneWidget);
        expect(find.text('Next Training'), findsOneWidget);
        expect(find.text('No training scheduled.'), findsOneWidget);
        expect(find.text('Recent Activity'), findsOneWidget);
        expect(find.text('No activity yet.'), findsOneWidget);
        expect(find.text('Insights'), findsOneWidget);
        expect(
          find.text(
            'Insights will appear once enough training data has been collected.',
          ),
          findsOneWidget,
        );
        expect(find.text("You're all caught up."), findsOneWidget);

        // Superseded Phase 7 sections must be gone.
        expect(find.text('Quick Actions'), findsNothing);
        expect(find.text('Impact Summary'), findsNothing);
        expect(find.text('Risk Summary'), findsNothing);

        final viewAllButtons = find.widgetWithText(TextButton, 'View All');
        expect(viewAllButtons, findsNWidgets(2));

        await tester.tap(viewAllButtons.first);
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('timeline')), findsOneWidget);
      },
    );
  });
}
