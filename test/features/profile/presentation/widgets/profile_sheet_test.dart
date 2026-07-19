import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vikzar/design_system/theme/app_theme.dart';
import 'package:vikzar/features/profile/presentation/widgets/profile_sheet.dart';
import 'package:vikzar/services/local_storage/shared_preferences_provider.dart';
import 'package:vikzar/shared/models/workspace_type.dart';

Future<void> _pumpSheet(
  WidgetTester tester, {
  required WorkspaceType workspace,
  required Map<String, Object> prefsValues,
}) async {
  SharedPreferences.setMockInitialValues(prefsValues);
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => ProfileSheet.show(context, workspace: workspace),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  group('ProfileSheet', () {
    testWidgets('a Player-only account sees Become a Coach, never Switch '
        'Workspace', (tester) async {
      await _pumpSheet(
        tester,
        workspace: WorkspaceType.player,
        prefsValues: {'onboarding_complete_player': true},
      );

      expect(find.text('Profile'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Become a Coach'), findsOneWidget);
      expect(find.text('Switch Workspace'), findsNothing);
      expect(find.text('Sign Out'), findsOneWidget);
    });

    testWidgets('a Coach-only account sees neither Become a Coach nor '
        'Switch Workspace', (tester) async {
      await _pumpSheet(
        tester,
        workspace: WorkspaceType.coach,
        prefsValues: {'onboarding_complete_coach': true},
      );

      expect(find.text('Become a Coach'), findsNothing);
      expect(find.text('Switch Workspace'), findsNothing);
    });

    testWidgets('a dual-workspace account sees Switch Workspace, never '
        'Become a Coach', (tester) async {
      await _pumpSheet(
        tester,
        workspace: WorkspaceType.player,
        prefsValues: {
          'onboarding_complete_player': true,
          'onboarding_complete_coach': true,
        },
      );

      expect(find.text('Switch Workspace'), findsOneWidget);
      expect(find.text('Become a Coach'), findsNothing);
    });
  });
}
