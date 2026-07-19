import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/models/workspace_type.dart';
import 'shared_preferences_provider.dart';

/// The **local-device-only** record of which workspaces this device has
/// already completed onboarding for. Local, not Firestore, for the same
/// reason as `ActiveWorkspaceStore`: `users/{uid}.workspaces` (what the
/// account *holds*, Cloud-Function-written) does not exist yet at Phase 6
/// (no Cloud Functions this phase, per [DECISIONS.md ADR-041]) — this store
/// only tracks "has this device's user walked through the onboarding
/// screens for this workspace," so a returning user isn't forced through
/// Level/Profile/Permissions again every cold start.
class OnboardingProgressStore {
  OnboardingProgressStore(this._prefs);

  final SharedPreferences _prefs;

  static String _keyFor(WorkspaceType type) =>
      'onboarding_complete_${type.firestoreKey}';

  bool isComplete(WorkspaceType type) => _prefs.getBool(_keyFor(type)) ?? false;

  Future<void> markComplete(WorkspaceType type) =>
      _prefs.setBool(_keyFor(type), true);
}

final onboardingProgressStoreProvider = Provider<OnboardingProgressStore>((ref) {
  return OnboardingProgressStore(ref.watch(sharedPreferencesProvider));
});

/// Reactive wrapper so the router's redirect logic re-evaluates the moment
/// onboarding completes, mirroring `ActiveWorkspaceNotifier`'s pattern.
final onboardingCompletionProvider =
    NotifierProvider<OnboardingCompletionNotifier, Set<WorkspaceType>>(
      OnboardingCompletionNotifier.new,
    );

class OnboardingCompletionNotifier extends Notifier<Set<WorkspaceType>> {
  @override
  Set<WorkspaceType> build() {
    final store = ref.watch(onboardingProgressStoreProvider);
    return {
      for (final type in WorkspaceType.values)
        if (store.isComplete(type)) type,
    };
  }

  Future<void> markComplete(WorkspaceType type) async {
    await ref.read(onboardingProgressStoreProvider).markComplete(type);
    state = {...state, type};
  }
}
