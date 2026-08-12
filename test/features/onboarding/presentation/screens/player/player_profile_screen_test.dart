import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:vikzar/design_system/theme/app_theme.dart';
import 'package:vikzar/features/onboarding/presentation/screens/player/player_profile_screen.dart';
import 'package:vikzar/routing/app_router.dart';
import 'package:vikzar/shared/models/workspace_type.dart';

void main() {
  group('PlayerProfileScreen', () {
    testWidgets(
      'Continue is always tappable; tapping while incomplete reveals inline "Required" errors instead '
      'of a snackbar/dialog and does not advance — filling every required field then lets it through '
      '(DECISIONS.md ADR-056), including the non-medical Training Status question (DECISIONS.md ADR-057)',
      (tester) async {
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
            GoRoute(
              path: OnboardingRoute.permissionsPath(WorkspaceType.player),
              builder: (context, state) => const Scaffold(body: Text('Permissions')),
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

        // Always tappable, and no error shown before any attempt.
        expect(continueButton().onPressed, isNotNull);
        expect(find.text('Required'), findsNothing);

        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();

        // Every required field is empty/unset, so every one of them shows
        // its own inline "Required" message — never a snackbar or dialog.
        expect(find.text('Required'), findsWidgets);
        expect(find.text('Permissions'), findsNothing);
        expect(find.byType(SnackBar), findsNothing);
        expect(find.byType(Dialog), findsNothing);

        await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Jai');
        await tester.enterText(find.widgetWithText(TextField, 'Age'), '21');
        await tester.enterText(find.widgetWithText(TextField, 'Height (cm)'), '180');
        await tester.enterText(find.widgetWithText(TextField, 'Weight (kg)'), '75');
        await tester.tap(find.text('Right'));
        await tester.tap(find.text('Midfielder'));
        
        await tester.tap(find.text('Select training status'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Fully Available'));
        await tester.pumpAndSettle();

        expect(find.text('Required'), findsNothing);

        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();

        expect(find.text('Permissions'), findsOneWidget);
      },
    );

    testWidgets(
      'Training Status offers exactly the four non-medical options and never shows medical/injury '
      'terminology during onboarding (DECISIONS.md ADR-057, ADR-059, ADR-060)',
      (tester) async {
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

        expect(find.text('Training Status'), findsOneWidget);
        
        await tester.tap(find.text('Select training status'));
        await tester.pumpAndSettle();

        expect(find.text('Fully Available'), findsOneWidget);
        expect(find.text('Individual Training'), findsOneWidget);
        expect(find.text('Return to Play'), findsOneWidget);
        expect(find.text('Unavailable'), findsOneWidget);

        expect(find.text('Injury History'), findsNothing);
        expect(find.text('ACL'), findsNothing);
        expect(find.text('Meniscus'), findsNothing);
      },
    );
  });
}
