import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:vikzar/design_system/theme/app_theme.dart';
import 'package:vikzar/features/player_home/presentation/screens/player_home_screen.dart';

void main() {
  group('PlayerHomeScreen', () {
    testWidgets(
      'renders every required section with honest placeholders, never a '
      'fabricated risk score or session',
      (tester) async {
        // Home's ListView is taller than the default 800x600 test
        // surface — a plain ListView is lazy (SliverList), so content far
        // below the fold is outside the default cache extent and won't be
        // found at all, not just unable to be tapped. Enlarge the surface
        // so everything renders.
        tester.view.physicalSize = const Size(800, 2000);
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
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp.router(theme: AppTheme.dark(), routerConfig: router),
          ),
        );

        expect(find.textContaining('Hi,'), findsNothing); // no name collected in this test
        expect(find.text('No Pod connected'), findsOneWidget);
        expect(find.text("Today's Status"), findsOneWidget);
        expect(find.text('Recent Sessions'), findsOneWidget);
        expect(find.text('No sessions yet.'), findsOneWidget);
        expect(find.text('Impact Summary'), findsOneWidget);
        expect(find.text('Risk Summary'), findsOneWidget);
        expect(find.text('Quick Actions'), findsOneWidget);
        expect(find.text('Recent Activity'), findsOneWidget);
        // No invented numbers: placeholder tiles show an em dash, not a
        // fabricated figure.
        expect(find.text('—'), findsWidgets);

        await tester.tap(find.text('View Timeline'));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('timeline')), findsOneWidget);
      },
    );
  });
}
