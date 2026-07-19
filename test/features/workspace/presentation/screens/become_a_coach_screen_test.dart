import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:vikzar/design_system/theme/app_theme.dart';
import 'package:vikzar/features/workspace/presentation/screens/become_a_coach_complete_screen.dart';
import 'package:vikzar/features/workspace/presentation/screens/become_a_coach_screen.dart';
import 'package:vikzar/routing/app_router.dart';

void main() {
  group('BecomeACoachScreen', () {
    testWidgets(
      'Submit stays disabled until Level, Club, and Role are filled, then '
      'advances to the submitted-for-review confirmation',
      (tester) async {
        // The form is taller than the default 800x600 test surface, which
        // leaves Submit's computed tap offset outside the rendered
        // window. Enlarge it so the button is actually reachable.
        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        // The screen navigates via the real AppRoute path constants
        // (context.push(AppRoute.becomeCoachCompletePath)), so the test's
        // router must register those same paths, not stand-ins.
        final router = GoRouter(
          initialLocation: AppRoute.becomeCoachPath,
          routes: [
            GoRoute(
              path: AppRoute.becomeCoachPath,
              builder: (context, state) => const BecomeACoachScreen(),
            ),
            GoRoute(
              path: AppRoute.becomeCoachCompletePath,
              builder: (context, state) => const BecomeACoachCompleteScreen(),
            ),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp.router(theme: AppTheme.dark(), routerConfig: router),
          ),
        );

        TextButton submitButton() =>
            tester.widget<TextButton>(find.widgetWithText(TextButton, 'Submit'));

        expect(submitButton().onPressed, isNull);

        await tester.tap(find.text('Club'));
        await tester.enterText(
          find.widgetWithText(TextField, 'Club / Academy Name'),
          'Riverside Academy',
        );
        await tester.enterText(
          find.widgetWithText(TextField, 'Current Role'),
          'Assistant Coach',
        );
        await tester.pumpAndSettle();

        expect(submitButton().onPressed, isNotNull);

        await tester.tap(find.text('Submit'));
        await tester.pumpAndSettle();

        expect(find.text('Your request has been submitted.'), findsOneWidget);
        expect(
          find.textContaining("We'll review it and notify you"),
          findsOneWidget,
        );
      },
    );
  });
}
