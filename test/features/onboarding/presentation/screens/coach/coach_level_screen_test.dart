import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:vikzar/design_system/theme/app_theme.dart';
import 'package:vikzar/features/onboarding/presentation/screens/coach/coach_level_screen.dart';

void main() {
  group('CoachLevelScreen', () {
    testWidgets('shows the coach-relabeled level options and advances on '
        'Continue', (tester) async {
      final router = GoRouter(
        initialLocation: '/level',
        routes: [
          GoRoute(path: '/level', builder: (context, state) => const CoachLevelScreen()),
          GoRoute(
            path: '/onboarding/coach/profile',
            builder: (context, state) => const SizedBox(key: Key('profile')),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(theme: AppTheme.dark(), routerConfig: router),
        ),
      );

      expect(find.text('Academy'), findsOneWidget);
      expect(find.text('Club'), findsOneWidget);
      expect(find.text('Professional'), findsOneWidget);
      // Player-only label must never leak into the Coach level screen.
      expect(find.text('Semi Professional'), findsNothing);

      await tester.tap(find.text('Club'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('profile')), findsOneWidget);
    });
  });
}
