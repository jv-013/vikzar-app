import '../../core/result/result.dart';
import '../models/app_user.dart';
import '../models/coach_profile.dart';
import '../models/player_profile.dart';

/// Reads and writes the `users/{uid}` profile — shared because
/// Authentication routing, Workspace, Onboarding, and Profile all need it,
/// per FLUTTER_ARCHITECTURE.md §2's rule for what belongs in `shared/`.
///
/// **Revised at Phase 8B** (DECISIONS.md ADR-051): `workspaces`,
/// `defaultWorkspace`, `playerProfile`, and `coachProfile` are now
/// client-writable, self-scoped only, per the MVP self-service model that
/// ADR documents — superseding this interface's previous read-only scope.
abstract interface class UserRepository {
  /// Emits `Result.success(null)` if the account is authenticated but no
  /// `users/{uid}` document exists yet (e.g. a brand-new sign-up, before
  /// onboarding has completed for any workspace).
  Stream<Result<AppUser?>> watchUser(String uid);

  /// Completes Player onboarding: creates or updates `users/{uid}` with
  /// [email] (from Firebase Auth — required by BACKEND_SPECIFICATION.md
  /// §1.5 and otherwise never written, since no Cloud Function populates
  /// it), [displayName], the collected [profile], and `workspaces.player`
  /// (optionally with [teamId], if the player joined a team during
  /// onboarding — team joining is not yet wired to a real flow, so this is
  /// usually `null`). Sets `defaultWorkspace` to `player` only if the
  /// account has no default yet (i.e. this is its first completed
  /// workspace) — never overwrites an existing default.
  Future<Result<void>> completePlayerOnboarding({
    required String uid,
    required String email,
    required String displayName,
    required PlayerProfile profile,
    String? teamId,
  });

  /// Completes Coach onboarding: creates or updates `users/{uid}` with
  /// [email], [displayName], the collected [profile], and
  /// `workspaces.coach` holding [teamId] (the team just created or joined
  /// during onboarding). Sets `defaultWorkspace` to `coach` only if the
  /// account has no default yet.
  Future<Result<void>> completeCoachOnboarding({
    required String uid,
    required String email,
    required String displayName,
    required CoachProfile profile,
    required String teamId,
  });

  /// Updates only `displayName` — used by the Edit Profile sheet. Self
  /// only, per Security Rules.
  Future<Result<void>> updateDisplayName({
    required String uid,
    required String displayName,
  });

  /// Overwrites `playerProfile` as a whole map — used by the Edit Profile
  /// sheet when editing a Player workspace's profile fields.
  Future<Result<void>> updatePlayerProfile({
    required String uid,
    required PlayerProfile profile,
  });

  /// Overwrites `coachProfile` as a whole map — used by the Edit Profile
  /// sheet when editing a Coach workspace's profile fields.
  Future<Result<void>> updateCoachProfile({
    required String uid,
    required CoachProfile profile,
  });
}
