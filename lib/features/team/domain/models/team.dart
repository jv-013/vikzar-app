/// `teams/{teamId}` — BACKEND_SPECIFICATION.md §1.2.
class Team {
  const Team({
    required this.teamId,
    required this.name,
    required this.coachIds,
    this.orgId,
    this.ageGroup,
    this.country,
    this.status = 'active',
  });

  final String teamId;
  final String? orgId;
  final String name;
  final String? ageGroup;
  final List<String> coachIds;
  final String? country;
  final String status;

  factory Team.fromMap(Map<String, dynamic> data, {required String teamId}) {
    return Team(
      teamId: teamId,
      orgId: data['orgId'] as String?,
      name: data['name'] as String? ?? '',
      ageGroup: data['ageGroup'] as String?,
      coachIds: (data['coachIds'] as List<dynamic>?)?.cast<String>() ?? const [],
      country: data['country'] as String?,
      status: data['status'] as String? ?? 'active',
    );
  }
}

/// `teams/{teamId}/members/{uid}` — BACKEND_SPECIFICATION.md §1.3.
class TeamMember {
  const TeamMember({
    required this.uid,
    required this.displayName,
    this.avatarUrl,
    this.jerseyNumber,
    this.position,
    this.role = 'player',
    this.status = 'active',
  });

  final String uid;
  final String displayName;
  final String? avatarUrl;
  final int? jerseyNumber;
  final String? position;
  final String role;
  final String status;

  factory TeamMember.fromMap(Map<String, dynamic> data, {required String uid}) {
    return TeamMember(
      uid: uid,
      displayName: data['displayName'] as String? ?? '',
      avatarUrl: data['avatarUrl'] as String?,
      jerseyNumber: (data['jerseyNumber'] as num?)?.toInt(),
      position: data['position'] as String?,
      role: data['role'] as String? ?? 'player',
      status: data['status'] as String? ?? 'active',
    );
  }
}
