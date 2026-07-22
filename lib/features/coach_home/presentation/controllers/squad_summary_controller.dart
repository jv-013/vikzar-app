import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/models/player_profile.dart';
import '../../../team/presentation/controllers/team_roster_controller.dart';

/// Today's Squad counts for a team, aggregated from each real roster
/// member's own `trainingStatus` — never fabricated. A player counts as
/// [noData] until they've set a Training Status on their own profile, or
/// while their own `users/{uid}` read hasn't resolved yet.
class SquadSummary {
  const SquadSummary({
    this.fullyAvailable = 0,
    this.individualTraining = 0,
    this.returnToPlay = 0,
    this.unavailable = 0,
    this.noData = 0,
  });

  final int fullyAvailable;
  final int individualTraining;
  final int returnToPlay;
  final int unavailable;
  final int noData;

  int get total => fullyAvailable + individualTraining + returnToPlay + unavailable + noData;
}

/// Counts [teamRosterEntriesProvider]'s per-member training statuses into
/// [SquadSummary]. Never blocks the whole summary on one member's fetch: a
/// member whose read is still loading or has failed is simply counted as
/// [SquadSummary.noData], the same honest treatment as a member who
/// genuinely hasn't set a status yet.
final squadSummaryProvider = Provider.autoDispose.family<AsyncValue<SquadSummary>, String>((
  ref,
  teamId,
) {
  final entriesAsync = ref.watch(teamRosterEntriesProvider(teamId));

  return entriesAsync.whenData((entries) {
    final counts = <TrainingStatus?, int>{};
    for (final entry in entries) {
      counts[entry.trainingStatus] = (counts[entry.trainingStatus] ?? 0) + 1;
    }
    return SquadSummary(
      fullyAvailable: counts[TrainingStatus.fullyAvailable] ?? 0,
      individualTraining: counts[TrainingStatus.individualTraining] ?? 0,
      returnToPlay: counts[TrainingStatus.returnToPlay] ?? 0,
      unavailable: counts[TrainingStatus.unavailable] ?? 0,
      noData: counts[null] ?? 0,
    );
  });
});
