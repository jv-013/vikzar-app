import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vikzar/services/local_storage/onboarding_progress_store.dart';
import 'package:vikzar/services/local_storage/shared_preferences_provider.dart';
import 'package:vikzar/shared/models/workspace_type.dart';

void main() {
  group('OnboardingProgressStore', () {
    test('a workspace starts incomplete and can be marked complete', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = OnboardingProgressStore(prefs);

      expect(store.isComplete(WorkspaceType.player), isFalse);

      await store.markComplete(WorkspaceType.player);

      expect(store.isComplete(WorkspaceType.player), isTrue);
      expect(store.isComplete(WorkspaceType.coach), isFalse);
    });
  });

  group('onboardingCompletionProvider', () {
    test('reflects a mark-complete call and persists it', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      expect(container.read(onboardingCompletionProvider), isEmpty);

      await container
          .read(onboardingCompletionProvider.notifier)
          .markComplete(WorkspaceType.coach);

      expect(container.read(onboardingCompletionProvider), {WorkspaceType.coach});
      expect(prefs.getBool('onboarding_complete_coach'), isTrue);
    });
  });
}
