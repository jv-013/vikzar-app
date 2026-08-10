/// `plannedSessions/{plannedSessionId}` — Phase 13 §5. A coach-scheduled
/// training/match slot, distinct from `sessions/{sessionId}`
/// (BACKEND_SPECIFICATION.md §1.8), which represents a real hardware
/// capture and remains exclusively laptop-authored. Created only via the
/// `createPlannedSession` Callable Cloud Function — this app never
/// writes this collection directly (`firestore.rules`: `write: false`).
enum PlannedSessionType {
  training,
  match;

  String get firestoreKey => name;

  static PlannedSessionType fromFirestoreKey(String? key) {
    for (final value in PlannedSessionType.values) {
      if (value.firestoreKey == key) return value;
    }
    return PlannedSessionType.training;
  }

  String get label => switch (this) {
    PlannedSessionType.training => 'Training',
    PlannedSessionType.match => 'Match',
  };
}

enum PlannedSessionStatus {
  scheduled,
  cancelled,
  completed;

  String get firestoreKey => name;

  static PlannedSessionStatus fromFirestoreKey(String? key) {
    for (final value in PlannedSessionStatus.values) {
      if (value.firestoreKey == key) return value;
    }
    return PlannedSessionStatus.scheduled;
  }
}

class PlannedSession {
  const PlannedSession({
    required this.plannedSessionId,
    required this.teamId,
    required this.title,
    required this.type,
    required this.scheduledAt,
    this.notes,
    required this.status,
    required this.createdBy,
    this.durationMinutes,
    this.location,
    this.playerIds = const [],
  });

  final String plannedSessionId;
  final String teamId;
  final String title;
  final PlannedSessionType type;
  final DateTime scheduledAt;
  final String? notes;
  final PlannedSessionStatus status;
  final String createdBy;

  /// Additive, Phase 15 — the Create Session sheet's full field set.
  /// `playerIds` empty means "whole squad" (no explicit selection made),
  /// never fabricated to look like a real roster subset.
  final int? durationMinutes;
  final String? location;
  final List<String> playerIds;

  /// Expects [data]'s `scheduledAt` already normalized to a plain
  /// [DateTime] — [PlannedSessionRepositoryImpl] does that conversion
  /// before calling this, keeping this domain model free of any Firebase
  /// dependency (the same pattern `Alert.fromMap` uses).
  factory PlannedSession.fromMap(Map<String, dynamic> data, {required String plannedSessionId}) {
    return PlannedSession(
      plannedSessionId: plannedSessionId,
      teamId: data['teamId'] as String? ?? '',
      title: data['title'] as String? ?? '',
      type: PlannedSessionType.fromFirestoreKey(data['type'] as String?),
      scheduledAt: (data['scheduledAt'] as DateTime?) ?? DateTime.now(),
      notes: data['notes'] as String?,
      status: PlannedSessionStatus.fromFirestoreKey(data['status'] as String?),
      createdBy: data['createdBy'] as String? ?? '',
      durationMinutes: (data['durationMinutes'] as num?)?.toInt(),
      location: data['location'] as String?,
      playerIds: (data['playerIds'] as List<dynamic>?)?.cast<String>() ?? const [],
    );
  }
}
