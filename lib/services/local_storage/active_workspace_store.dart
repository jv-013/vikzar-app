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
///
/// Per DECISIONS.md ADR-052, every key is namespaced by the authenticated
/// Firebase [uid] so signing out of one account and into another on the
/// same device can never read the previous account's cached choice.
class ActiveWorkspaceStore {
  ActiveWorkspaceStore(this._prefs);

  final SharedPreferences _prefs;

  static const _keyPrefix = 'active_workspace';

  String _keyFor(String uid) => '$_keyPrefix::$uid';

  WorkspaceType? read(String uid) {
    final stored = _prefs.getString(_keyFor(uid));
    return WorkspaceType.fromFirestoreKey(stored);
  }

  Future<void> write(String uid, WorkspaceType type) => _prefs.setString(
    _keyFor(uid),
    type.firestoreKey,
  );

  Future<void> clear(String uid) => _prefs.remove(_keyFor(uid));
}

final activeWorkspaceStoreProvider = Provider<ActiveWorkspaceStore>((ref) {
  return ActiveWorkspaceStore(ref.watch(sharedPreferencesProvider));
});
