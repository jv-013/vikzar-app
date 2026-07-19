import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:vikzar/design_system/theme/app_theme.dart';
import 'package:vikzar/features/onboarding/presentation/screens/player/player_level_screen.dart';

void main() {
  group('PlayerLevelScreen', () {
    testWidgets('Continue is disabled until a level is selected, then '
        'advances to the Profile step', (tester) async {
      final router = GoRouter(
        initialLocation: '/level',
        routes: [
          GoRoute(path: '/level', builder: (context, state) => const PlayerLevelScreen()),
          GoRoute(
            path: '/onboarding/player/profile',
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
      expect(find.text('Professional'), findsOneWidget);

      var continueButton = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Continue'),
      );
      expect(continueButton.onPressed, isNull);

      await tester.tap(find.text('Amateur'));
      await tester.pumpAndSettle();

      continueButton = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Continue'),
      );
      expect(continueButton.onPressed, isNotNull);

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('profile')), findsOneWidget);
    });
  });
}
