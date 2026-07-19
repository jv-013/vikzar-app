import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/models/workspace_type.dart';
import 'shared_preferences_provider.dart';

/// The **local-device-only** record of which workspace is currently
/// active, per DECISIONS.md ADR-031: "no `activeWorkspace` field in
/// Firestore — the currently active workspace is local, per-device app
/// state (Riverpod + local storage), never written to the server."
///
/// This is the one piece of workspace state that is *not* mirrored to
/// `users/{uid}` — `workspaces`/`defaultWorkspace` (what the account
/// *holds*) live in Firestore; *which one this device is currently
/// looking at* lives only here.
class ActiveWorkspaceStore {
  ActiveWorkspaceStore(this._prefs);

  final SharedPreferences _prefs;

  static const _key = 'active_workspace';

  WorkspaceType? read() {
    final stored = _prefs.getString(_key);
    return WorkspaceType.fromFirestoreKey(stored);
  }

  Future<void> write(WorkspaceType type) => _prefs.setString(
    _key,
    type.firestoreKey,
  );

  Future<void> clear() => _prefs.remove(_key);
}

final activeWorkspaceStoreProvider = Provider<ActiveWorkspaceStore>((ref) {
  return ActiveWorkspaceStore(ref.watch(sharedPreferencesProvider));
});
