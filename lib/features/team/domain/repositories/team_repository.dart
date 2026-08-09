import '../../../../core/result/result.dart';
import '../models/team.dart';

/// `teams/{teamId}` and its `members` subcollection, per
/// BACKEND_SPECIFICATION.md §1.2/§1.3. **Revised at Phase 15**: every
/// membership-affecting write (create a team, join as coach, join as
/// player) now goes through a Callable Cloud Function — this repository
/// never writes `teams`/`members` directly. `firestore.rules` denies the
/// client writes those Callables replace, so this isn't just a
/// convention: bypassing this repository to write Firestore directly
/// would simply fail.
abstract interface class TeamRepository {
  /// Calls `createTeam` — the caller becomes the new team's sole coach.
  /// Returns the generated `teamId` and its first invite code.
  Future<Result<({String teamId, String inviteCode})>> createTeam({
    required String name,
    String? ageGroup,
  });

  /// Looks up a team by id — used to show a team's name once its id is
  /// known (e.g. after joining), never to validate a join (invite codes
  /// are opaque to the client; `firestore.rules` denies reading
  /// `teamInvites` directly).
  Future<Result<Team?>> getTeam(String teamId);

  /// Calls `joinTeamAsCoach` — adds the caller to an existing team's
  /// `coachIds`. `teamId` here is the same value Coach onboarding has
  /// always called an "invite code" (BACKEND_SPECIFICATION.md §1.2 never
  /// defined a separate coach-invite-code system) — this only moves the
  /// write server-side, the UX is unchanged.
  Future<Result<void>> joinTeamAsCoach({required String teamId});

  /// Calls `createTeamInvite` — returns the team's current active player
  /// invite code, generating one if none exists. `regenerate: true`
  /// revokes the previous code and issues a new one.
  Future<Result<String>> createTeamInvite({
    required String teamId,
    bool regenerate = false,
  });

  /// Calls `joinTeamWithInvite` — redeems a player invite code, adding
  /// the caller to that team's roster and setting their own
  /// `workspaces.player.teamId`. Returns the resolved `teamId`.
  Future<Result<String>> joinTeamWithInvite({required String inviteCode});

  /// The live roster for a team.
  Stream<Result<List<TeamMember>>> watchRoster(String teamId);
}
