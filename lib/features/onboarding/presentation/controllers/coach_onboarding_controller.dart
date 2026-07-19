import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/coach_onboarding_data.dart';

/// Holds the Coach onboarding flow's collected fields across its five
/// screens, in memory only — mirrors `PlayerOnboardingController`.
class CoachOnboardingController extends Notifier<CoachOnboardingData> {
  @override
  CoachOnboardingData build() => const CoachOnboardingData();

  void setLevel(CoachingLevel level) {
    state = state.copyWith(level: level);
  }

  void setProfile(CoachProfileData profile) {
    state = state.copyWith(profile: profile);
  }

  void setPermissions(CoachPermissions permissions) {
    state = state.copyWith(permissions: permissions);
  }

  void setTeam(TeamSetupData team) {
    state = state.copyWith(team: team);
  }

  void reset() {
    state = const CoachOnboardingData();
  }
}

final coachOnboardingControllerProvider =
    NotifierProvider<CoachOnboardingController, CoachOnboardingData>(
      CoachOnboardingController.new,
    );
