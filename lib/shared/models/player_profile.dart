import 'package:flutter/foundation.dart';

/// A player's declared playing level — collected during Player onboarding
/// (DESIGN_SPECIFICATION.md §19.1), persisted at `users/{uid}.playerProfile.level`
/// per BACKEND_SPECIFICATION.md §1.5 (Added Phase 8B).
///
/// Lives in `shared/models/` (promoted from `features/onboarding/`) because
/// Phase 8B's `AppUser.playerProfile` needs it too — Onboarding, Profile,
/// and Player Home all reference it, per FLUTTER_ARCHITECTURE.md's rule
/// that `shared/` holds things a second feature has come to need.
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

  static PlayingLevel? fromName(String? name) {
    for (final value in PlayingLevel.values) {
      if (value.name == name) return value;
    }
    return null;
  }
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

  static PreferredFoot? fromName(String? name) {
    for (final value in PreferredFoot.values) {
      if (value.name == name) return value;
    }
    return null;
  }
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

  static PlayingPosition? fromName(String? name) {
    for (final value in PlayingPosition.values) {
      if (value.name == name) return value;
    }
    return null;
  }
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

  static InjuryHistoryStatus? fromName(String? name) {
    for (final value in InjuryHistoryStatus.values) {
      if (value.name == name) return value;
    }
    return null;
  }
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

  static InjuryType? fromName(String? name) {
    for (final value in InjuryType.values) {
      if (value.name == name) return value;
    }
    return null;
  }
}

/// `users/{uid}.playerProfile` — BACKEND_SPECIFICATION.md §1.5 (Added Phase
/// 8B). Written once, as a whole map, when Player onboarding completes;
/// read by Profile, Player Home, and the profile badge.
@immutable
class PlayerProfile {
  const PlayerProfile({
    this.level,
    this.age,
    this.heightCm,
    this.weightKg,
    this.preferredFoot,
    this.position,
    this.injuryStatus,
    this.injuryTypes = const {},
  });

  final PlayingLevel? level;
  final int? age;
  final double? heightCm;
  final double? weightKg;
  final PreferredFoot? preferredFoot;
  final PlayingPosition? position;
  final InjuryHistoryStatus? injuryStatus;
  final Set<InjuryType> injuryTypes;

  Map<String, dynamic> toMap() => {
    if (level != null) 'level': level!.name,
    if (age != null) 'age': age,
    if (heightCm != null) 'heightCm': heightCm,
    if (weightKg != null) 'weightKg': weightKg,
    if (preferredFoot != null) 'preferredFoot': preferredFoot!.name,
    if (position != null) 'position': position!.name,
    if (injuryStatus != null) 'injuryStatus': injuryStatus!.name,
    if (injuryTypes.isNotEmpty)
      'injuryTypes': injuryTypes.map((t) => t.name).toList(),
  };

  factory PlayerProfile.fromMap(Map<String, dynamic> data) {
    return PlayerProfile(
      level: PlayingLevel.fromName(data['level'] as String?),
      age: (data['age'] as num?)?.toInt(),
      heightCm: (data['heightCm'] as num?)?.toDouble(),
      weightKg: (data['weightKg'] as num?)?.toDouble(),
      preferredFoot: PreferredFoot.fromName(data['preferredFoot'] as String?),
      position: PlayingPosition.fromName(data['position'] as String?),
      injuryStatus: InjuryHistoryStatus.fromName(
        data['injuryStatus'] as String?,
      ),
      injuryTypes:
          (data['injuryTypes'] as List<dynamic>?)
              ?.map((v) => InjuryType.fromName(v as String?))
              .whereType<InjuryType>()
              .toSet() ??
          const {},
    );
  }
}
