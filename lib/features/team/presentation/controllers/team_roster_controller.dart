import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/result/result.dart';
import '../../../../shared/models/player_profile.dart';
import '../../../../shared/providers/current_app_user_provider.dart';
import '../../../../shared/repositories/user_repository_impl.dart';
import '../../data/repositories/team_repository_impl.dart';
import '../../domain/models/team.dart';

/// Resolves the coach's own team — the first of `workspaces.coach.teamIds`
/// (BACKEND_SPECIFICATION.md §1.5's schema allows more than one, but no
/// multi-team switcher UI exists yet; using the first is the same
/// "first of list" simplification [heldWorkspacesProvider] already makes).
/// `null` until the coach has created or joined a team.
final coachTeamIdProvider = Provider<String?>((ref) {
  final teamIds = ref.watch(currentAppUserProvider)?.workspaces.coach?.teamIds;
  if (teamIds == null || teamIds.isEmpty) return null;
  return teamIds.first;
});

/// The live roster for [teamId] — a thin [StreamProvider] wrapper around
/// [TeamRepository.watchRoster] so every screen that needs it (Coach
/// Home's squad summary, the Team screen) shares one subscription pattern
/// instead of each calling the repository directly. **`autoDispose`**
/// (edge-case audit, platform-lock pass): closes the Firestore listener
/// once no screen is watching this team's roster anymore.
final teamRosterProvider = StreamProvider.autoDispose.family<Result<List<TeamMember>>, String>((
  ref,
  teamId,
) {
  return ref.watch(teamRepositoryProvider).watchRoster(teamId);
});

/// The resolved [Team] document for [teamId] — a one-shot fetch, since
/// team metadata (name, age group) doesn't need a live stream the way the
/// roster does.
final teamProvider = FutureProvider.autoDispose.family<Result<Team?>, String>((ref, teamId) {
  return ref.watch(teamRepositoryProvider).getTeam(teamId);
});

/// A roster member paired with their own real `trainingStatus` — `null`
/// until they've set one, or while their own `users/{uid}` read hasn't
/// resolved yet. Coach entries are excluded; `members` only ever holds
/// players (a coach's own membership lives on `teams/{teamId}.coachIds`,
/// never in this subcollection).
class RosterEntry {
  const RosterEntry({required this.member, this.trainingStatus});

  final TeamMember member;
  final TrainingStatus? trainingStatus;
}

/// Combines [teamRosterProvider] with a per-member [watchUserProvider]
/// read — the one place this N-read aggregation happens, shared by Coach
/// Home's [squadSummaryProvider][] (`coach_home/presentation/controllers/squad_summary_controller.dart`)
/// and the Team screen, rather than each re-deriving it. No denormalized
/// status field exists on `TeamMember` (no Cloud Function writes one), so
/// reading each player's own document individually is an accepted MVP
/// tradeoff, the same shape as DECISIONS.md ADR-051's
/// self-service-over-Cloud-Function pattern.
final teamRosterEntriesProvider = Provider.autoDispose.family<AsyncValue<List<RosterEntry>>, String>((
  ref,
  teamId,
) {
  final rosterAsync = ref.watch(teamRosterProvider(teamId));

  return rosterAsync.when(
    loading: () => const AsyncValue.loading(),
    error: AsyncValue.error,
    data: (result) => result.fold(
      onSuccess: (members) => AsyncValue.data([
        for (final member in members.where((m) => m.role == 'player'))
          RosterEntry(
            member: member,
            trainingStatus: ref
                .watch(watchUserProvider(member.uid))
                .value
                ?.fold(
                  onSuccess: (user) => user?.playerProfile?.trainingStatus,
                  onFailure: (_) => null,
                ),
          ),
      ]),
      onFailure: (failure) => AsyncValue.error(failure, StackTrace.current),
    ),
  );
});
