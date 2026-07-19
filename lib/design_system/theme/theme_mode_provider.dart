import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The app's current [ThemeMode], per FLUTTER_ARCHITECTURE.md §5's
/// "Global" provider scope (app lifetime, never disposed).
///
/// Defaults to [ThemeMode.system]. No Settings screen exists yet to let a
/// user override it (Phase 4 scope excludes feature implementation) —
/// wiring a control that calls `themeModeProvider.notifier` is additive
/// once `features/profile/` implements Settings.
final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.system;

  void setThemeMode(ThemeMode mode) => state = mode;
}
