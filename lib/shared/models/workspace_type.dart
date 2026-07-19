/// Which workspace an account holds or is currently viewing — Player or
/// Coach — per BACKEND_SPECIFICATION.md §1.5 and DECISIONS.md ADR-031.
///
/// This is the one enum every workspace-aware part of the app depends on:
/// the active-workspace store (`services/local_storage/`), the router's
/// redirect logic (`routing/route_guards.dart`), and `AppUser.workspaces`
/// all reference it — hence `shared/models/`, not a single feature.
enum WorkspaceType {
  player,
  coach;

  /// The exact key used in Firestore's `users/{uid}.workspaces` map and
  /// `defaultWorkspace` field — see BACKEND_SPECIFICATION.md §1.5.
  String get firestoreKey => name;

  /// Display label — added Phase 7 for the profile badge, workspace
  /// switcher, and Home screens, replacing what would otherwise be a
  /// `switch (type) { player => 'Player', coach => 'Coach' }` repeated at
  /// every call site.
  String get label => switch (this) {
    WorkspaceType.player => 'Player',
    WorkspaceType.coach => 'Coach',
  };

  static WorkspaceType? fromFirestoreKey(String? key) {
    for (final type in WorkspaceType.values) {
      if (type.firestoreKey == key) return type;
    }
    return null;
  }
}
