/// Player onboarding field options and in-memory collected data —
/// DESIGN_SPECIFICATION.md §19.1, steps 2–5a. **Nothing here is persisted
/// to Firestore this phase** (no Cloud Functions, per this phase's scope);
/// it exists only for the lifetime of the onboarding flow, discarded on
/// sign-out — see DECISIONS.md's Phase 6 onboarding-state ADR.
enum PlayingLevel {
  academy,
  amateur,
  semiProfessional,
  professional;

  String get label => switch (this) {
    PlayingLevel.academy => 'Academy',
    PlayingLevel.amateur => 'Amateur',
    PlayingLevel.semiProfessional => 'Semi Professional',
    PlayingLevel.professional => 'Professional',
  };
}

enum PreferredFoot {
  left,
  right,
  both;

  String get label => switch (this) {
    PreferredFoot.left => 'Left',
    PreferredFoot.right => 'Right',
    PreferredFoot.both => 'Both',
  };
}

enum PlayingPosition {
  goalkeeper,
  defender,
  midfielder,
  forward;

  String get label => switch (this) {
    PlayingPosition.goalkeeper => 'Goalkeeper',
    PlayingPosition.defender => 'Defender',
    PlayingPosition.midfielder => 'Midfielder',
    PlayingPosition.forward => 'Forward',
  };
}

enum InjuryHistoryStatus {
  never,
  previously,
  currentlyRecovering;

  String get label => switch (this) {
    InjuryHistoryStatus.never => 'Never',
    InjuryHistoryStatus.previously => 'Previously',
    InjuryHistoryStatus.currentlyRecovering => 'Currently Recovering',
  };
}

enum InjuryType {
  acl,
  meniscus,
  hamstring,
  ankle,
  other;

  String get label => switch (this) {
    InjuryType.acl => 'ACL',
    InjuryType.meniscus => 'Meniscus',
    InjuryType.hamstring => 'Hamstring',
    InjuryType.ankle => 'Ankle',
    InjuryType.other => 'Other',
  };
}

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
}
