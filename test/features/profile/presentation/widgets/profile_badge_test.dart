import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vikzar/design_system/theme/app_theme.dart';
import 'package:vikzar/features/profile/presentation/widgets/profile_badge.dart';
import 'package:vikzar/services/local_storage/shared_preferences_provider.dart';
import 'package:vikzar/shared/models/workspace_type.dart';

/// The chevron is explicitly called out as "VERY IMPORTANT" in this
/// phase's brief: a Player-only account must never see any hint that a
/// Coach workspace concept exists. These tests are the primary guard
/// against that regressing silently.
void main() {
  group('ProfileBadge', () {
    testWidgets('a single-workspace account shows the label with no chevron', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({'onboarding_complete_player': true});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: MaterialApp(
            theme: AppTheme.dark(),
            home: const Scaffold(body: ProfileBadge(workspace: WorkspaceType.player)),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('PLAYER'), findsOneWidget);
      expect(find.byIcon(Symbols.expand_more), findsNothing);
    });

    testWidgets('a dual-workspace account shows the label with a chevron', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'onboarding_complete_player': true,
        'onboarding_complete_coach': true,
      });
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: MaterialApp(
            theme: AppTheme.dark(),
            home: const Scaffold(body: ProfileBadge(workspace: WorkspaceType.coach)),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('COACH'), findsOneWidget);
      expect(find.byIcon(Symbols.expand_more), findsOneWidget);
    });
  });
}
