import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/local_storage/theme_mode_store.dart';

/// The app's current [ThemeMode], per FLUTTER_ARCHITECTURE.md §5's
/// "Global" provider scope (app lifetime, never disposed).
///
/// Defaults to [ThemeMode.system] until the user has ever set an explicit
/// override in Settings' Appearance section, at which point the override
/// is read from [ThemeModeStore] on `build()` and persisted on every
/// [setThemeMode] call — so a restart never silently discards a choice
/// the user actually made, while an account that's never touched the
/// setting still correctly follows the OS.
final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ref.read(themeModeStoreProvider).read() ?? ThemeMode.system;

  void setThemeMode(ThemeMode mode) {
    state = mode;
    ref.read(themeModeStoreProvider).write(mode);
  }
}
