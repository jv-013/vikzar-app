import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vikzar/design_system/theme/app_theme.dart';
import 'package:vikzar/features/onboarding/presentation/screens/onboarding_complete_screen.dart';
import 'package:vikzar/services/local_storage/onboarding_progress_store.dart';
import 'package:vikzar/services/local_storage/shared_preferences_provider.dart';
import 'package:vikzar/shared/models/workspace_type.dart';

void main() {
  group('OnboardingCompleteScreen', () {
    testWidgets('renders a calm confirmation and does not mark complete '
        'until "Get Started" is tapped', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      late final ProviderContainer container;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: Consumer(
            builder: (context, ref, _) {
              container = ProviderScope.containerOf(context);
              return MaterialApp(
                theme: AppTheme.dark(),
                home: const OnboardingCompleteScreen(workspace: WorkspaceType.player),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("You're all set."), findsOneWidget);
      expect(find.text('Your Player workspace is ready.'), findsOneWidget);
      expect(
        container.read(onboardingCompletionProvider),
        isNot(contains(WorkspaceType.player)),
        reason: 'marking complete must be an explicit action, never automatic',
      );

      await tester.tap(find.text('Get Started'));
      await tester.pumpAndSettle();

      expect(container.read(onboardingCompletionProvider), contains(WorkspaceType.player));
      expect(prefs.getBool('onboarding_complete_player'), isTrue);
    });
  });
}
