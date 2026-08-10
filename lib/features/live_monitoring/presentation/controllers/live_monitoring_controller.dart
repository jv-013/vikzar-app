import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/result/result.dart';
import '../../../team/presentation/controllers/team_roster_controller.dart';
import '../../data/repositories/live_monitoring_repository_impl.dart';
import '../../domain/models/live_player_metrics.dart';

/// The coach's live per-player metrics feed for their own team — a `null`
/// [coachTeamIdProvider] yields an honest empty list rather than querying
/// with no team, the same "no team yet" treatment [alertsControllerProvider]
/// already uses.
///
/// `.autoDispose` — matches every other Firestore-backed provider in this
/// codebase (DECISIONS.md ADR-068).
final liveMonitoringControllerProvider = StreamProvider.autoDispose<Result<List<LivePlayerMetrics>>>((
  ref,
) {
  final teamId = ref.watch(coachTeamIdProvider);
  if (teamId == null) {
    return Stream.value(const Result.success(<LivePlayerMetrics>[]));
  }
  return ref.watch(liveMonitoringRepositoryProvider).watchTeamLiveMonitoring(teamId);
});
