import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/player_onboarding_data.dart';

/// Holds the Player onboarding flow's collected fields across its five
/// screens, in memory only — see `player_onboarding_data.dart`'s doc
/// comment on why nothing here reaches Firestore this phase.
class PlayerOnboardingController extends Notifier<PlayerOnboardingData> {
  @override
  PlayerOnboardingData build() => const PlayerOnboardingData();

  void setLevel(PlayingLevel level) {
    state = state.copyWith(level: level);
  }

  void setProfile(PlayerProfileData profile) {
    state = state.copyWith(profile: profile);
  }

  void setPermissions(PlayerPermissions permissions) {
    state = state.copyWith(permissions: permissions);
  }

  /// Reset for a fresh run (e.g. after sign-out) — not currently called
  /// anywhere in this phase's scope (no sign-out UI exists yet), provided
  /// for the controller's own lifecycle completeness.
  void reset() {
    state = const PlayerOnboardingData();
  }
}

final playerOnboardingControllerProvider =
    NotifierProvider<PlayerOnboardingController, PlayerOnboardingData>(
      PlayerOnboardingController.new,
    );
