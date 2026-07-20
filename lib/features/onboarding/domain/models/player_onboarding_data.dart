/// Player onboarding field options and in-memory collected data —
/// DESIGN_SPECIFICATION.md §19.1, steps 2–5a.
///
/// **Revised at Phase 8B:** the field-option enums used to be defined here
/// and were purely in-memory (nothing persisted). They are now defined in
/// `shared/models/player_profile.dart` — promoted once `AppUser.playerProfile`
/// needed the same enums outside onboarding (Profile, Player Home) — and
/// re-exported below so every existing import of this file keeps working
/// unchanged. [PlayerProfileData] itself remains onboarding-flow-local
/// scratch state; [toPlayerProfile] converts it to the shared, persisted
/// shape once [isComplete].
library;

import '../../../../shared/models/player_profile.dart';

export '../../../../shared/models/player_profile.dart'
    show
        PlayingLevel,
        PreferredFoot,
        PlayingPosition,
        InjuryHistoryStatus,
        InjuryType,
        PlayerProfile;

class PlayerProfileData {
  const PlayerProfileData({
    this.name = '',
    this.age,
    this.height,
    this.weight,
    this.preferredFoot,
    this.position,
    this.injuryStatus,
    this.injuryTypes = const {},
  });

  final String name;
  final int? age;
  final double? height;
  final double? weight;
  final PreferredFoot? preferredFoot;
  final PlayingPosition? position;
  final InjuryHistoryStatus? injuryStatus;
  final Set<InjuryType> injuryTypes;

  bool get isComplete =>
      name.trim().isNotEmpty &&
      age != null &&
      height != null &&
      weight != null &&
      preferredFoot != null &&
      position != null &&
      injuryStatus != null;
}

class PlayerPermissions {
  const PlayerPermissions({
    this.bluetooth = false,
    this.motion = false,
    this.notifications = false,
  });

  final bool bluetooth;
  final bool motion;
  final bool notifications;

  PlayerPermissions copyWith({bool? bluetooth, bool? motion, bool? notifications}) {
    return PlayerPermissions(
      bluetooth: bluetooth ?? this.bluetooth,
      motion: motion ?? this.motion,
      notifications: notifications ?? this.notifications,
    );
  }
}

/// Pod assignment status shown on step 5a — always "unassigned" this
/// phase, since matching a Pod to an account is a laptop/coach action this
/// codebase never performs (DECISIONS.md ADR-030). A real value would
/// arrive from Firestore in a future phase.
enum PodAssignmentStatus { unassigned }

class PlayerOnboardingData {
  const PlayerOnboardingData({
    this.level,
    this.profile = const PlayerProfileData(),
    this.permissions = const PlayerPermissions(),
  });

  final PlayingLevel? level;
  final PlayerProfileData profile;
  final PlayerPermissions permissions;

  PlayerOnboardingData copyWith({
    PlayingLevel? level,
    PlayerProfileData? profile,
    PlayerPermissions? permissions,
  }) {
    return PlayerOnboardingData(
      level: level ?? this.level,
      profile: profile ?? this.profile,
      permissions: permissions ?? this.permissions,
    );
  }

  /// Converts the collected onboarding data into the shape persisted at
  /// `users/{uid}.playerProfile` (BACKEND_SPECIFICATION.md §1.5, Added
  /// Phase 8B). Callers should only do this once [profile.isComplete].
  PlayerProfile toPlayerProfile() => PlayerProfile(
    level: level,
    age: profile.age,
    heightCm: profile.height,
    weightKg: profile.weight,
    preferredFoot: profile.preferredFoot,
    position: profile.position,
    injuryStatus: profile.injuryStatus,
    injuryTypes: profile.injuryTypes,
  );
}
