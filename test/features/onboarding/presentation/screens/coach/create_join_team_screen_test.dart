import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:vikzar/design_system/theme/app_theme.dart';
import 'package:vikzar/features/onboarding/presentation/screens/coach/create_join_team_screen.dart';

void main() {
  group('CreateJoinTeamScreen', () {
    testWidgets(
      'selecting "Create a new team" reveals an inline team-name field and '
      'relabels Continue to Create — never a new screen',
      (tester) async {
        final router = GoRouter(
          initialLocation: '/team',
          routes: [
            GoRoute(
              path: '/team',
              builder: (context, state) => const CreateJoinTeamScreen(),
            ),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp.router(theme: AppTheme.dark(), routerConfig: router),
          ),
        );

        expect(find.text('Team name'), findsNothing);
        expect(find.text('Continue'), findsOneWidget);

        await tester.tap(find.text('Create a new team'));
        await tester.pumpAndSettle();

        expect(find.text('Team name'), findsOneWidget);
        expect(find.text('Create'), findsOneWidget);

        var createButton = tester.widget<TextButton>(
          find.widgetWithText(TextButton, 'Create'),
        );
        expect(createButton.onPressed, isNull);

        await tester.enterText(find.widgetWithText(TextField, 'Team name'), 'Riverside U18');
        await tester.pumpAndSettle();

        createButton = tester.widget<TextButton>(
          find.widgetWithText(TextButton, 'Create'),
        );
        expect(createButton.onPressed, isNotNull);
      },
    );
  });
}
