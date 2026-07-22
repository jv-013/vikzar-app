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

  /// Football-club-natural labels (DECISIONS.md ADR — football terminology
  /// pass): "Pro"/"Semi-Pro", the way players and coaches actually say
  /// these, not the more corporate-sounding "Professional"/"Semi
  /// Professional" this previously read. `.name` (the Firestore-persisted
  /// value) is unchanged — this only affects display text.
  String get label => switch (this) {
    PlayingLevel.academy => 'Academy',
    PlayingLevel.amateur => 'Amateur',
    PlayingLevel.semiProfessional => 'Semi-Pro',
    PlayingLevel.professional => 'Pro',
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

/// **Revised at Phase 8D (DECISIONS.md ADR-057), revised again at Phase 9
/// (DECISIONS.md ADR-059):** replaces the earlier `InjuryHistoryStatus`/
/// `InjuryType` pair. Phase 8D's version asked a clinical intake-style
/// question at onboarding; Phase 9 widens the label set to the product's
/// exact four training-availability states and gives it a real consumer —
/// Player Home's "Today's Status" and Coach Home's "Today's Squad" both
/// read this field directly, closing the "nothing reads it" gap ADR-057
/// originally flagged.
enum TrainingStatus {
  fullyAvailable,
  individualTraining,
  returnToPlay,
  unavailable;

  String get label => switch (this) {
    TrainingStatus.fullyAvailable => 'Fully Available',
    TrainingStatus.individualTraining => 'Individual Training',
    TrainingStatus.returnToPlay => 'Return to Play',
    TrainingStatus.unavailable => 'Unavailable',
  };

  static TrainingStatus? fromName(String? name) {
    for (final value in TrainingStatus.values) {
      if (value.name == name) return value;
    }
    return null;
  }
}

/// **Added at Phase 9 (DECISIONS.md ADR-060).** Shown only on Profile —
/// never during onboarding — and only once [TrainingStatus] is something
/// other than [TrainingStatus.fullyAvailable]. Unlike the clinical picker
/// ADR-057 removed, this is optional, profile-only, and framed as
/// training-availability planning for a coach managing a squad, not a
/// medical intake: predefined options for legibility and consistency, not
/// diagnostic precision.
enum InjuryType {
  acl,
  meniscus,
  hamstring,
  ankle,
  groin,
  calf,
  hip,
  quadriceps,
  other;

  String get label => switch (this) {
    InjuryType.acl => 'ACL',
    InjuryType.meniscus => 'Meniscus',
    InjuryType.hamstring => 'Hamstring',
    InjuryType.ankle => 'Ankle',
    InjuryType.groin => 'Groin',
    InjuryType.calf => 'Calf',
    InjuryType.hip => 'Hip',
    InjuryType.quadriceps => 'Quadriceps',
    InjuryType.other => 'Other',
  };

  static InjuryType? fromName(String? name) {
    for (final value in InjuryType.values) {
      if (value.name == name) return value;
    }
    return null;
  }
}

/// **Added at Phase 9 (DECISIONS.md ADR-060).** An approximate estimate,
/// not a medical prognosis — paired with [InjuryType] on Profile only,
/// under the same condition (see that enum's doc comment).
enum RecoveryTimeframe {
  underTwoWeeks,
  twoToFourWeeks,
  oneToTwoMonths,
  twoToThreeMonths,
  threeMonthsOrMore;

  String get label => switch (this) {
    RecoveryTimeframe.underTwoWeeks => 'Under 2 weeks',
    RecoveryTimeframe.twoToFourWeeks => '2–4 weeks',
    RecoveryTimeframe.oneToTwoMonths => '1–2 months',
    RecoveryTimeframe.twoToThreeMonths => '2–3 months',
    RecoveryTimeframe.threeMonthsOrMore => '3+ months',
  };

  static RecoveryTimeframe? fromName(String? name) {
    for (final value in RecoveryTimeframe.values) {
      if (value.name == name) return value;
    }
    return null;
  }
}

/// `users/{uid}.playerProfile` — BACKEND_SPECIFICATION.md §1.5 (Added Phase
/// 8B). Written once, as a whole map, when Player onboarding completes;
/// read by Profile, Player Home, and the profile badge. `injuryTypes`/
/// `recoveryTimeframe` are written only via Profile edits, never onboarding
/// (Phase 9, ADR-060).
@immutable
class PlayerProfile {
  const PlayerProfile({
    this.level,
    this.age,
    this.heightCm,
    this.weightKg,
    this.preferredFoot,
    this.position,
    this.trainingStatus,
    this.injuryTypes = const {},
    this.recoveryTimeframe,
  });

  final PlayingLevel? level;
  final int? age;
  final double? heightCm;
  final double? weightKg;
  final PreferredFoot? preferredFoot;
  final PlayingPosition? position;
  final TrainingStatus? trainingStatus;
  final Set<InjuryType> injuryTypes;
  final RecoveryTimeframe? recoveryTimeframe;

  Map<String, dynamic> toMap() => {
    if (level != null) 'level': level!.name,
    if (age != null) 'age': age,
    if (heightCm != null) 'heightCm': heightCm,
    if (weightKg != null) 'weightKg': weightKg,
    if (preferredFoot != null) 'preferredFoot': preferredFoot!.name,
    if (position != null) 'position': position!.name,
    if (trainingStatus != null) 'trainingStatus': trainingStatus!.name,
    if (injuryTypes.isNotEmpty)
      'injuryTypes': injuryTypes.map((t) => t.name).toList(),
    if (recoveryTimeframe != null) 'recoveryTimeframe': recoveryTimeframe!.name,
  };

  factory PlayerProfile.fromMap(Map<String, dynamic> data) {
    return PlayerProfile(
      level: PlayingLevel.fromName(data['level'] as String?),
      age: (data['age'] as num?)?.toInt(),
      heightCm: (data['heightCm'] as num?)?.toDouble(),
      weightKg: (data['weightKg'] as num?)?.toDouble(),
      preferredFoot: PreferredFoot.fromName(data['preferredFoot'] as String?),
      position: PlayingPosition.fromName(data['position'] as String?),
      trainingStatus: TrainingStatus.fromName(
        data['trainingStatus'] as String?,
      ),
      injuryTypes:
          (data['injuryTypes'] as List<dynamic>?)
              ?.map((v) => InjuryType.fromName(v as String?))
              .whereType<InjuryType>()
              .toSet() ??
          const {},
      recoveryTimeframe: RecoveryTimeframe.fromName(
        data['recoveryTimeframe'] as String?,
      ),
    );
  }
}
