import '../../../../core/result/result.dart';
import '../models/alert.dart';

/// `alerts/{alertId}`, per BACKEND_SPECIFICATION.md §1.10. Alerts are
/// created exclusively by Cloud Functions (`submitAlert`,
/// `deviceHeartbeatMonitor`) — no client `create` path exists here, matching
/// `firestore.rules`' `allow create: if false` for this collection.
abstract interface class AlertRepository {
  /// The live alert feed for every team in [teamIds], newest first —
  /// matches `firestore.indexes.json`'s `teamId ASC, triggeredAt DESC`
  /// composite index. Empty [teamIds] yields an always-empty stream rather
  /// than querying with no filter.
  Stream<Result<List<Alert>>> watchAlerts(List<String> teamIds);

  /// Sets `acknowledged`/`acknowledgedBy`/`acknowledgedAt` — the only
  /// fields the Flutter app is permitted to write on an alert document,
  /// per `firestore.rules`' `update` rule.
  Future<Result<void>> acknowledgeAlert({required String alertId, required String coachUid});
}
