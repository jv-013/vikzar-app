import 'package:flutter/foundation.dart';

import 'workspace_type.dart';

/// A player-side workspace membership — `users/{uid}.workspaces.player` in
/// BACKEND_SPECIFICATION.md §1.5.
@immutable
class PlayerWorkspace {
  const PlayerWorkspace({this.teamId});

  /// The team this player belongs to, if any. `null` until they join or
  /// are added to a team — a state this phase's Workspace Selection can
  /// produce (a brand-new Player workspace has no team yet).
  final String? teamId;
}

/// A coach-side workspace membership — `users/{uid}.workspaces.coach` in
/// BACKEND_SPECIFICATION.md §1.5.
@immutable
class CoachWorkspace {
  const CoachWorkspace({this.teamIds = const []});

  /// The team(s) this account coaches. Empty until they create or join at
  /// least one team.
  final List<String> teamIds;
}

/// `users/{uid}.workspaces` — a structured object, not an array: presence
/// of [player] / [coach] *is* the "has this workspace" signal, per
/// DECISIONS.md ADR-031's Phase 2 freeze resolution. An account may hold
/// one, both, or (transiently, mid-onboarding) neither.
@immutable
class UserWorkspaces {
  const UserWorkspaces({this.player, this.coach});

  const UserWorkspaces.empty() : player = null, coach = null;

  final PlayerWorkspace? player;
  final CoachWorkspace? coach;

  bool get isEmpty => player == null && coach == null;

  bool has(WorkspaceType type) => switch (type) {
    WorkspaceType.player => player != null,
    WorkspaceType.coach => coach != null,
  };

  /// Every workspace this account currently holds, in a stable order.
  List<WorkspaceType> get held => [
    if (player != null) WorkspaceType.player,
    if (coach != null) WorkspaceType.coach,
  ];
}
