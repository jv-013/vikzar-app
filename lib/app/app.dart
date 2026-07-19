import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design_system/theme/app_theme.dart';
import '../design_system/theme/theme_mode_provider.dart';
import '../routing/app_router.dart';

/// The root widget, per FLUTTER_ARCHITECTURE.md §1 (`app/` — bootstrap and
/// root-widget wiring only; no feature-specific logic lives here).
///
/// Wires together the three pieces this phase configures: Riverpod (via
/// [ConsumerWidget], reading [themeModeProvider]), go_router (via
/// `MaterialApp.router`, reading [appRouterProvider] so the router is
/// constructed once with `ref` access for its auth-aware redirect logic —
/// see `routing/route_guards.dart`), and the design-system theme
/// (`AppTheme`).
///
/// Responsive/adaptive configuration ([MediaQuery]-driven breakpoints,
/// FLUTTER_ARCHITECTURE.md §18) is not yet applied to any screen — every
/// Phase 5 screen is a single centered column that does not need it — but
/// nothing here would need to change to add it: adaptive chrome is a
/// per-screen/shell concern, not a root-widget one.
class VikzarApp extends ConsumerWidget {
  const VikzarApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Vikzar',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
