/// Coach onboarding field options and in-memory collected data —
/// DESIGN_SPECIFICATION.md §19.1, steps 2–5b.
///
/// **Revised at Phase 8B:** `CoachingLevel` now lives in
/// `shared/models/coach_profile.dart` (same reasoning as `PlayingLevel` in
/// `player_onboarding_data.dart`) and is re-exported below. [CoachProfileData]
/// remains onboarding-flow-local scratch state; [toCoachProfile] converts
/// it to the shared, persisted shape once [isComplete].
library;

import '../../../../shared/models/coach_profile.dart';

export '../../../../shared/models/coach_profile.dart'
    show CoachingLevel, CoachProfile;

class CoachProfileData {
  const CoachProfileData({
    this.name = '',
    this.age,
    this.title = '',
    this.club = '',
    this.license = '',
    this.academy = '',
  });

  final String name;
  final int? age;
  final String title;
  final String club;
  final String license;
  final String academy;

  bool get isComplete =>
      name.trim().isNotEmpty && age != null && title.trim().isNotEmpty;
}

class CoachPermissions {
  const CoachPermissions({
    this.bluetooth = false,
    this.motion = false,
    this.notifications = false,
  });

  final bool bluetooth;
  final bool motion;
  final bool notifications;

  CoachPermissions copyWith({bool? bluetooth, bool? motion, bool? notifications}) {
    return CoachPermissions(
      bluetooth: bluetooth ?? this.bluetooth,
      motion: motion ?? this.motion,
      notifications: notifications ?? this.notifications,
    );
  }
}

enum TeamSetupMode { create, join }

class TeamSetupData {
  const TeamSetupData({this.mode, this.teamName = '', this.inviteCode = ''});

  final TeamSetupMode? mode;
  final String teamName;
  final String inviteCode;

  bool get isComplete => switch (mode) {
    TeamSetupMode.create => teamName.trim().isNotEmpty,
    TeamSetupMode.join => inviteCode.trim().isNotEmpty,
    null => false,
  };

  TeamSetupData copyWith({TeamSetupMode? mode, String? teamName, String? inviteCode}) {
    return TeamSetupData(
      mode: mode ?? this.mode,
      teamName: teamName ?? this.teamName,
      inviteCode: inviteCode ?? this.inviteCode,
    );
  }
}

class CoachOnboardingData {
  const CoachOnboardingData({
    this.level,
    this.profile = const CoachProfileData(),
    this.permissions = const CoachPermissions(),
    this.team = const TeamSetupData(),
  });

  final CoachingLevel? level;
  final CoachProfileData profile;
  final CoachPermissions permissions;
  final TeamSetupData team;

  CoachOnboardingData copyWith({
    CoachingLevel? level,
    CoachProfileData? profile,
    CoachPermissions? permissions,
    TeamSetupData? team,
  }) {
    return CoachOnboardingData(
      level: level ?? this.level,
      profile: profile ?? this.profile,
      permissions: permissions ?? this.permissions,
      team: team ?? this.team,
    );
  }

  /// Converts the collected onboarding data into the shape persisted at
  /// `users/{uid}.coachProfile` (BACKEND_SPECIFICATION.md §1.5, Added
  /// Phase 8B). Callers should only do this once [profile.isComplete].
  CoachProfile toCoachProfile() => CoachProfile(
    level: level,
    age: profile.age,
    title: profile.title,
    club: profile.club,
    license: profile.license,
    academy: profile.academy,
  );
}
