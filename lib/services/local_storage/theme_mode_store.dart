import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'shared_preferences_provider.dart';

/// The user's explicit theme override, if they've ever set one — Settings'
/// Appearance control persists here so it survives an app restart instead
/// of silently resetting to [ThemeMode.system] every cold start.
///
/// Not [uid]-namespaced like `ActiveWorkspaceStore` (ADR-052): appearance
/// is a device-level UI preference, not per-account state — switching
/// accounts on the same device shouldn't silently flip the visual theme
/// out from under whoever's holding it. Matches `PendingEmailLinkStore`'s
/// reasoning for the same choice, for a different reason (there: no
/// account exists yet at that point in the flow; here: the preference
/// genuinely isn't account-scoped).
class ThemeModeStore {
  ThemeModeStore(this._prefs);

  final SharedPreferences _prefs;

  static const _key = 'theme_mode';

  /// `null` means "no override yet" — the caller should fall back to
  /// [ThemeMode.system], not treat `null` as a stored value in its own
  /// right.
  ThemeMode? read() {
    final stored = _prefs.getString(_key);
    return switch (stored) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      'system' => ThemeMode.system,
      _ => null,
    };
  }

  Future<void> write(ThemeMode mode) => _prefs.setString(_key, mode.name);
}

final themeModeStoreProvider = Provider<ThemeModeStore>((ref) {
  return ThemeModeStore(ref.watch(sharedPreferencesProvider));
});
