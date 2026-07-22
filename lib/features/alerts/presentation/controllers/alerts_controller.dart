import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/result/result.dart';
import '../../../team/presentation/controllers/team_roster_controller.dart';
import '../../data/repositories/alert_repository_impl.dart';
import '../../domain/models/alert.dart';

/// The coach's alert feed for their own team — `null`/empty [coachTeamIdProvider]
/// yields an honest empty list rather than an error, the same "no team yet"
/// treatment [squadSummaryProvider] and the Team screen already use.
final alertsControllerProvider = StreamProvider<Result<List<Alert>>>((ref) {
  final teamId = ref.watch(coachTeamIdProvider);
  final teamIds = teamId == null ? const <String>[] : [teamId];
  return ref.watch(alertRepositoryProvider).watchAlerts(teamIds);
});
