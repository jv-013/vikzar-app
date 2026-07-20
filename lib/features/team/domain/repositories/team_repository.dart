import '../../../../core/result/result.dart';
import '../models/team.dart';

/// `teams/{teamId}` and its `members` subcollection, per
/// BACKEND_SPECIFICATION.md §1.2/§1.3, revised for client-direct writes at
/// Phase 8B (DECISIONS.md ADR-051).
abstract interface class TeamRepository {
  /// Creates a new team with [coachUid] as its sole initial coach. Returns
  /// the generated `teamId`, which is also this team's join code (there is
  /// no separate invite-code field per BACKEND_SPECIFICATION.md §1.2).
  Future<Result<String>> createTeam({
    required String coachUid,
    required String name,
    String? ageGroup,
  });

  /// Looks up a team by its id/join code — used to validate a Join Team
  /// entry before joining. `Result.success(null)` means no team exists
  /// with that id.
  Future<Result<Team?>> getTeam(String teamId);

  /// Adds [coachUid] to an existing team's `coachIds` (self-add only,
  /// never removes another coach). Fails with [CloudFailure] if no team
  /// exists with [teamId].
  Future<Result<void>> joinTeamAsCoach({
    required String teamId,
    required String coachUid,
  });

  /// Creates the caller's own `teams/{teamId}/members/{uid}` roster entry
  /// (self-service, per ADR-051). Fails with [CloudFailure] if no team
  /// exists with [teamId].
  Future<Result<void>> joinTeamAsPlayer({
    required String teamId,
    required String uid,
    required String displayName,
    String? avatarUrl,
  });

  /// The live roster for a team — no UI consumer yet this phase, provided
  /// so a future Roster screen doesn't need a new repository.
  Stream<Result<List<TeamMember>>> watchRoster(String teamId);
}
