import 'package:flutter/foundation.dart';

/// A coach's declared coaching level — collected during Coach onboarding
/// (DESIGN_SPECIFICATION.md §19.1), persisted at `users/{uid}.coachProfile.level`
/// per BACKEND_SPECIFICATION.md §1.5 (Added Phase 8B). Lives in
/// `shared/models/` for the same reason as `PlayingLevel` in
/// `player_profile.dart` — promoted once `AppUser` needed it too.
enum CoachingLevel {
  academy,
  club,
  professional;

  String get label => switch (this) {
    CoachingLevel.academy => 'Academy',
    CoachingLevel.club => 'Club',
    CoachingLevel.professional => 'Professional',
  };

  static CoachingLevel? fromName(String? name) {
    for (final value in CoachingLevel.values) {
      if (value.name == name) return value;
    }
    return null;
  }
}

/// `users/{uid}.coachProfile` — BACKEND_SPECIFICATION.md §1.5 (Added Phase
/// 8B). Written once, as a whole map, when Coach onboarding completes.
@immutable
class CoachProfile {
  const CoachProfile({this.level, this.age, this.title, this.club});

  final CoachingLevel? level;
  final int? age;
  final String? title;
  final String? club;

  Map<String, dynamic> toMap() => {
    if (level != null) 'level': level!.name,
    if (age != null) 'age': age,
    if (title != null && title!.trim().isNotEmpty) 'title': title,
    if (club != null && club!.trim().isNotEmpty) 'club': club,
  };

  factory CoachProfile.fromMap(Map<String, dynamic> data) {
    return CoachProfile(
      level: CoachingLevel.fromName(data['level'] as String?),
      age: (data['age'] as num?)?.toInt(),
      title: data['title'] as String?,
      club: data['club'] as String?,
    );
  }
}
