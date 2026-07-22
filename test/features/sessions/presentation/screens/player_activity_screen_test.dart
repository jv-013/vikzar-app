import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vikzar/design_system/theme/app_theme.dart';
import 'package:vikzar/features/sessions/presentation/screens/player_activity_screen.dart';

void main() {
  group('PlayerActivityScreen', () {
    testWidgets(
      'shows an honest empty state — never a fabricated football event — '
      'when the notification stream is empty',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(theme: AppTheme.dark(), home: const PlayerActivityScreen()),
          ),
        );
        await tester.pump();

        expect(find.text('Activity'), findsOneWidget);
        expect(find.text('No activity yet.'), findsOneWidget);
        expect(
          find.textContaining('will appear here once your training data starts flowing'),
          findsOneWidget,
        );
      },
    );
  });
}
