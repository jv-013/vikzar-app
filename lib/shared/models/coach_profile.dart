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

  /// Football-club-natural label (DECISIONS.md ADR — football terminology
  /// pass): "Pro", matching `PlayingLevel`'s same change. `.name` is
  /// unchanged.
  String get label => switch (this) {
    CoachingLevel.academy => 'Academy',
    CoachingLevel.club => 'Club',
    CoachingLevel.professional => 'Pro',
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
  const CoachProfile({
    this.level,
    this.age,
    this.title,
    this.club,
    this.license,
    this.academy,
  });

  final CoachingLevel? level;
  final int? age;
  final String? title;
  final String? club;

  /// A coaching license/certification (e.g. "UEFA B"), collected
  /// Phase 15 — free text, since licensing bodies/tiers vary by country
  /// and this app doesn't validate against any registry.
  final String? license;

  /// The academy/institution the coach is affiliated with — distinct
  /// from [club] (the team's own club name), collected Phase 15.
  final String? academy;

  Map<String, dynamic> toMap() => {
    if (level != null) 'level': level!.name,
    if (age != null) 'age': age,
    if (title != null && title!.trim().isNotEmpty) 'title': title,
    if (club != null && club!.trim().isNotEmpty) 'club': club,
    if (license != null && license!.trim().isNotEmpty) 'license': license,
    if (academy != null && academy!.trim().isNotEmpty) 'academy': academy,
  };

  factory CoachProfile.fromMap(Map<String, dynamic> data) {
    return CoachProfile(
      level: CoachingLevel.fromName(data['level'] as String?),
      age: (data['age'] as num?)?.toInt(),
      title: data['title'] as String?,
      club: data['club'] as String?,
      license: data['license'] as String?,
      academy: data['academy'] as String?,
    );
  }
}
