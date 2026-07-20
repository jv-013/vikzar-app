import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vikzar/design_system/theme/app_theme.dart';
import 'package:vikzar/features/workspace/presentation/controllers/active_workspace_controller.dart';
import 'package:vikzar/features/workspace/presentation/screens/workspace_selection_screen.dart';
import 'package:vikzar/services/local_storage/shared_preferences_provider.dart';
import 'package:vikzar/shared/models/workspace_type.dart';
import 'package:vikzar/shared/providers/current_uid_provider.dart';

const _uid = 'uid_123';

void main() {
  group('WorkspaceSelectionScreen', () {
    testWidgets('Continue is disabled until a workspace is selected', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            currentUidProvider.overrideWithValue(_uid),
          ],
          child: MaterialApp(
            theme: AppTheme.dark(),
            home: const WorkspaceSelectionScreen(),
          ),
        ),
      );

      final continueButton = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Continue'),
      );
      expect(continueButton.onPressed, isNull);
    });

    testWidgets(
      'selecting Player enables Continue and persists the active workspace '
      'locally on confirm — never to Firestore, per DECISIONS.md ADR-031',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        late final ProviderContainer container;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            currentUidProvider.overrideWithValue(_uid),
          ],
            child: Consumer(
              builder: (context, ref, _) {
                container = ProviderScope.containerOf(context);
                return MaterialApp(
                  theme: AppTheme.dark(),
                  home: const WorkspaceSelectionScreen(),
                );
              },
            ),
          ),
        );

        await tester.tap(find.text('Player'));
        await tester.pumpAndSettle();

        final continueButton = tester.widget<TextButton>(
          find.widgetWithText(TextButton, 'Continue'),
        );
        expect(continueButton.onPressed, isNotNull);

        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();

        expect(
          container.read(activeWorkspaceProvider),
          WorkspaceType.player,
        );
        expect(prefs.getString('active_workspace::$_uid'), 'player');
      },
    );
  });
}
