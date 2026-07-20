import 'package:flutter/foundation.dart';

import 'coach_profile.dart';
import 'player_profile.dart';
import 'user_workspaces.dart';
import 'workspace_type.dart';

/// The identity-relevant subset of `users/{uid}`, per
/// BACKEND_SPECIFICATION.md §1.5. Deliberately **not** the full schema —
/// `careerStats`, `fcmTokens`, `avatarUrl`, etc. belong to whichever
/// feature first needs them (profile, notifications), per FLUTTER_ARCHITECTURE.md's
/// feature-first modularity. This model exists for Authentication and
/// Workspace, which only need to know who the user is and which
/// workspace(s) they hold.
///
/// **Revised at Phase 8B:** [playerProfile]/[coachProfile] added — Profile,
/// Player Home, and Coach Home all need them now that onboarding persists
/// real data, per BACKEND_SPECIFICATION.md §1.5's "Added Phase 8B" fields.
@immutable
class AppUser {
  const AppUser({
    required this.uid,
    required this.email,
    this.displayName,
    this.workspaces = const UserWorkspaces.empty(),
    this.defaultWorkspace,
    this.status = 'active',
    this.playerProfile,
    this.coachProfile,
  });

  final String uid;
  final String email;
  final String? displayName;
  final UserWorkspaces workspaces;
  final WorkspaceType? defaultWorkspace;
  final String status;
  final PlayerProfile? playerProfile;
  final CoachProfile? coachProfile;

  /// Parses the identity-relevant fields out of a `users/{uid}` Firestore
  /// document map. Kept on the model itself (a pragmatic, common choice
  /// for pure data mapping with no business logic) rather than a separate
  /// mapper class.
  factory AppUser.fromMap(Map<String, dynamic> data, {required String uid}) {
    final workspacesMap = data['workspaces'] as Map<String, dynamic>?;
    final playerProfileMap = data['playerProfile'] as Map<String, dynamic>?;
    final coachProfileMap = data['coachProfile'] as Map<String, dynamic>?;
    return AppUser(
      uid: uid,
      email: data['email'] as String? ?? '',
      displayName: data['displayName'] as String?,
      workspaces: UserWorkspaces(
        player: workspacesMap?['player'] != null
            ? PlayerWorkspace(
                teamId:
                    (workspacesMap!['player'] as Map<String, dynamic>)['teamId']
                        as String?,
              )
            : null,
        coach: workspacesMap?['coach'] != null
            ? CoachWorkspace(
                teamIds:
                    ((workspacesMap!['coach']
                                as Map<String, dynamic>)['teamIds']
                            as List<dynamic>?)
                        ?.cast<String>() ??
                    const [],
              )
            : null,
      ),
      defaultWorkspace: WorkspaceType.fromFirestoreKey(
        data['defaultWorkspace'] as String?,
      ),
      status: data['status'] as String? ?? 'active',
      playerProfile: playerProfileMap != null
          ? PlayerProfile.fromMap(playerProfileMap)
          : null,
      coachProfile: coachProfileMap != null
          ? CoachProfile.fromMap(coachProfileMap)
          : null,
    );
  }
}
