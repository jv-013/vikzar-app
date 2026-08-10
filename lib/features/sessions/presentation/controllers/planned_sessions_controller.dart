import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/result/result.dart';
import '../../data/repositories/planned_session_repository_impl.dart';
import '../../domain/models/planned_session.dart';

/// Upcoming (non-cancelled) planned sessions for the current coach's
/// team, per Phase 13 §5. `.autoDispose` — matches every other
/// Firestore-backed `.family` provider fixed at Phase 11 (DECISIONS.md
/// ADR-068).
final upcomingPlannedSessionsProvider =
    StreamProvider.autoDispose.family<Result<List<PlannedSession>>, String>((ref, teamId) {
      return ref.watch(plannedSessionRepositoryProvider).watchUpcoming(teamId);
    });

/// Wraps [PlannedSessionRepository.createPlannedSession] for the "Create
/// Session" sheet — a thin controller, not a StateNotifier, since the
/// form itself owns its transient loading/error UI state (matching
/// `BecomeACoachScreen`'s own `_submit()` pattern, not a new one).
final createPlannedSessionProvider = Provider((ref) {
  return ({
    required String teamId,
    required String title,
    required PlannedSessionType type,
    required DateTime scheduledAt,
    String? notes,
    int? durationMinutes,
    String? location,
    List<String>? playerIds,
  }) => ref.read(plannedSessionRepositoryProvider).createPlannedSession(
    teamId: teamId,
    title: title,
    type: type,
    scheduledAt: scheduledAt,
    notes: notes,
    durationMinutes: durationMinutes,
    location: location,
    playerIds: playerIds,
  );
});
