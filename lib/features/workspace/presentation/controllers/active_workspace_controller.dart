import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../services/local_storage/active_workspace_store.dart';
import '../../../../shared/models/workspace_type.dart';
import '../../../../shared/providers/current_uid_provider.dart';

/// Which workspace is currently active — **local, per-device state only**,
/// per DECISIONS.md ADR-031. Global scope (app lifetime, never disposed),
/// per FLUTTER_ARCHITECTURE.md §5's provider hierarchy.
///
/// `build()` reads synchronously from [ActiveWorkspaceStore], which is
/// itself synchronous once `SharedPreferences` has resolved at bootstrap
/// (`app/bootstrap.dart` awaits `SharedPreferences.getInstance()` before
/// `runApp`) — so `routing/route_guards.dart` can read this provider's
/// value directly in a redirect callback with no async gap.
///
/// Per DECISIONS.md ADR-052, this watches [currentUidProvider] and rebuilds
/// (re-reading the *new* account's own stored value, never the previous
/// account's) whenever the authenticated uid changes.
final activeWorkspaceProvider =
    NotifierProvider<ActiveWorkspaceNotifier, WorkspaceType?>(
      ActiveWorkspaceNotifier.new,
    );

class ActiveWorkspaceNotifier extends Notifier<WorkspaceType?> {
  @override
  WorkspaceType? build() {
    final uid = ref.watch(currentUidProvider);
    if (uid == null) return null;
    return ref.watch(activeWorkspaceStoreProvider).read(uid);
  }

  /// Switches the active workspace: updates in-memory state immediately
  /// (so the router's `refreshListenable` fires and redirects, per
  /// FLUTTER_ARCHITECTURE.md §4) and persists it locally — never to
  /// Firestore.
  Future<void> setActiveWorkspace(WorkspaceType type) async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    await ref.read(activeWorkspaceStoreProvider).write(uid, type);
    state = type;
  }

  Future<void> clear() async {
    final uid = ref.read(currentUidProvider);
    if (uid != null) {
      await ref.read(activeWorkspaceStoreProvider).clear(uid);
    }
    state = null;
  }
}
