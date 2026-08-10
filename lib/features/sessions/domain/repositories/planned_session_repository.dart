import '../../../../core/result/result.dart';
import '../models/planned_session.dart';

/// `plannedSessions/{plannedSessionId}`, per Phase 13 §5.
abstract interface class PlannedSessionRepository {
  /// Every non-cancelled planned session for [teamId], soonest first —
  /// matches `firestore.indexes.json`'s composite index (added Phase 13).
  Stream<Result<List<PlannedSession>>> watchUpcoming(String teamId);

  /// Calls the `createPlannedSession` Callable — this repository never
  /// writes `plannedSessions` directly (`firestore.rules`: `write:
  /// false`). The frontend requests; the backend decides (§5/§7).
  Future<Result<void>> createPlannedSession({
    required String teamId,
    required String title,
    required PlannedSessionType type,
    required DateTime scheduledAt,
    String? notes,
    int? durationMinutes,
    String? location,
    List<String>? playerIds,
  });
}
