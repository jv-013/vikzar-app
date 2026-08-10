import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'shared_preferences_provider.dart';

/// The email address a Firebase sign-in link was last sent to — Firebase's
/// own magic-link flow needs it back for [FirebaseAuth.signInWithEmailLink],
/// and the link itself doesn't carry it if completed on a different device
/// or a fresh app session than the one that requested it.
///
/// Not [uid]-namespaced like `ActiveWorkspaceStore` (ADR-052): at this
/// point in the flow there is no signed-in account yet, by definition.
class PendingEmailLinkStore {
  PendingEmailLinkStore(this._prefs);

  final SharedPreferences _prefs;

  static const _key = 'pending_email_link_address';

  String? read() => _prefs.getString(_key);

  Future<void> write(String email) => _prefs.setString(_key, email);

  Future<void> clear() => _prefs.remove(_key);
}

final pendingEmailLinkStoreProvider = Provider<PendingEmailLinkStore>((ref) {
  return PendingEmailLinkStore(ref.watch(sharedPreferencesProvider));
});
