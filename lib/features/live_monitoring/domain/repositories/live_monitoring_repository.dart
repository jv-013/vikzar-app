import '../../../../core/result/result.dart';
import '../models/live_player_metrics.dart';

/// `teams/{teamId}/liveMonitoring/{playerId}`, per BACKEND_SPECIFICATION.md
/// §1.4. Read-only from the Flutter app — every document is written
/// exclusively by the `fanOutLiveMonitoring` Cloud Function trigger, never
/// a client write, matching `firestore.rules`' rule for this subcollection
/// (see [AlertRepository] for the same "no client write path" shape on a
/// different Cloud-Function-owned collection).
abstract interface class LiveMonitoringRepository {
  /// The live per-player metrics feed for [teamId] — a shallow collection
  /// listener, per §1.4's own stated purpose ("so the Coach Dashboard's
  /// Live Team Monitoring view can listen to one shallow collection instead
  /// of opening N per-session listeners"). Empty when no session is
  /// currently live for this team, which is the honest, real "no session"
  /// state — not an error.
  Stream<Result<List<LivePlayerMetrics>>> watchTeamLiveMonitoring(String teamId);
}
