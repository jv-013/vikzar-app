import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:vikzar/design_system/theme/app_theme.dart';
import 'package:vikzar/features/onboarding/presentation/screens/player/player_profile_screen.dart';

void main() {
  group('PlayerProfileScreen', () {
    testWidgets(
      'Injury History detail chips only appear after selecting '
      '"Previously" — never a new screen, DESIGN_SPECIFICATION.md §19.1',
      (tester) async {
        // The full form is taller than the default 800x600 test surface —
        // enlarge it so every field is actually hit-testable, rather than
        // scrolling to each one individually.
        tester.view.physicalSize = const Size(800, 2000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final router = GoRouter(
          initialLocation: '/profile',
          routes: [
            GoRoute(
              path: '/profile',
              builder: (context, state) => const PlayerProfileScreen(),
            ),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp.router(theme: AppTheme.dark(), routerConfig: router),
          ),
        );

        expect(find.text('ACL'), findsNothing);

        await tester.tap(find.text('Previously'));
        await tester.pumpAndSettle();

        expect(find.text('ACL'), findsOneWidget);
        expect(find.text('Meniscus'), findsOneWidget);

        await tester.tap(find.text('Never'));
        await tester.pumpAndSettle();

        expect(find.text('ACL'), findsNothing);
      },
    );

    testWidgets('Continue stays disabled until every required field is set', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final router = GoRouter(
        initialLocation: '/profile',
        routes: [
          GoRoute(
            path: '/profile',
            builder: (context, state) => const PlayerProfileScreen(),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(theme: AppTheme.dark(), routerConfig: router),
        ),
      );

      TextButton continueButton() =>
          tester.widget<TextButton>(find.widgetWithText(TextButton, 'Continue'));

      expect(continueButton().onPressed, isNull);

      await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Jai');
      await tester.enterText(find.widgetWithText(TextField, 'Age'), '21');
      await tester.enterText(find.widgetWithText(TextField, 'Height (cm)'), '180');
      await tester.enterText(find.widgetWithText(TextField, 'Weight (kg)'), '75');
      await tester.tap(find.text('Right'));
      await tester.tap(find.text('Midfielder'));
      await tester.tap(find.text('Never'));
      await tester.pumpAndSettle();

      expect(continueButton().onPressed, isNotNull);
    });
  });
}
