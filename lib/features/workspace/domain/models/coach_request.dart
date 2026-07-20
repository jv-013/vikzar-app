import '../../../../shared/models/coach_profile.dart';

/// `coachRequests/{requestId}` — BACKEND_SPECIFICATION.md §1.12 (Added
/// Phase 8B). A player-held account's request to also gain a Coach
/// workspace; submitting never grants it — see DECISIONS.md ADR-049/ADR-051.
class CoachRequest {
  const CoachRequest({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.level,
    this.club,
    this.title,
    this.orgEmail,
  });

  final String uid;
  final String email;
  final String displayName;
  final CoachingLevel level;
  final String? club;
  final String? title;
  final String? orgEmail;

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'email': email,
    'displayName': displayName,
    'level': level.name,
    if (club != null && club!.trim().isNotEmpty) 'club': club,
    if (title != null && title!.trim().isNotEmpty) 'title': title,
    if (orgEmail != null && orgEmail!.trim().isNotEmpty) 'orgEmail': orgEmail,
    'status': 'pending',
  };
}
