import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/models/workspace_type.dart';
import 'active_workspace_controller.dart';

/// Drives the Workspace Selection screen (DESIGN_SPECIFICATION.md §19.1,
/// step 1 of the six-screen onboarding flow).
///
/// Deliberately **local-only** in this phase: per BACKEND_SPECIFICATION.md
/// §1.5, `workspaces`/`defaultWorkspace` are Cloud-Function-written, and
/// the Cloud Function that would durably record "this account now holds
/// this workspace" belongs to onboarding completion — the Profile Form /
/// Permissions / Connect-Pod-or-Create-Team steps this phase explicitly
/// does not implement ("Do not implement onboarding itself. Only navigate
/// to placeholders"). Confirming a selection here only sets the
/// **local-device** active-workspace pointer (ADR-031) so the router can
/// move to the correct placeholder — it does not yet write to Firestore.
class WorkspaceSelectionController extends Notifier<WorkspaceType?> {
  @override
  WorkspaceType? build() => null;

  void select(WorkspaceType type) => state = type;

  Future<void> confirm() async {
    final selected = state;
    if (selected == null) return;
    await ref
        .read(activeWorkspaceProvider.notifier)
        .setActiveWorkspace(selected);
  }
}

final workspaceSelectionControllerProvider =
    NotifierProvider<WorkspaceSelectionController, WorkspaceType?>(
      WorkspaceSelectionController.new,
    );
