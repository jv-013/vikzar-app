import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../design_system/tokens/spacing.dart';
import '../../features/profile/presentation/widgets/profile_badge.dart';
import '../../shared/models/workspace_type.dart';
import '../app_router.dart';

class _NavItem {
  const _NavItem({required this.icon, required this.label});
  final IconData icon;
  final String label;
}

const _playerNavItems = [
  _NavItem(icon: Symbols.home, label: 'Home'),
  _NavItem(icon: Symbols.timeline, label: 'Timeline'),
  _NavItem(icon: Symbols.bar_chart, label: 'History'),
  _NavItem(icon: Symbols.person, label: 'Profile'),
];

const _coachNavItems = [
  _NavItem(icon: Symbols.home, label: 'Home'),
  _NavItem(icon: Symbols.sensors, label: 'Live'),
  _NavItem(icon: Symbols.groups, label: 'Team'),
  _NavItem(icon: Symbols.notifications, label: 'Alerts'),
  _NavItem(icon: Symbols.person, label: 'Profile'),
];

/// The permanent application shell — DESIGN_SPECIFICATION.md §13: "one
/// consistent design language across both workspaces... the item sets
/// differ, the visual system does not." One parameterized scaffold, not a
/// `PlayerShellScaffold`/`CoachShellScaffold` pair, per
/// [DECISIONS.md ADR-048](../../../DECISIONS.md#adr-048-a-single-parameterized-app-shell-not-a-playercoach-scaffold-pair).
///
/// Top bar: [ProfileBadge] (left, the single entry point for account-level
/// actions per ADR-047) and a notification bell (right). Body: the
/// `StatefulNavigationShell` go_router hands this widget, which preserves
/// each tab's state when switching — DESIGN_SPECIFICATION.md §12's
/// "premium, not jarring" motion expectation for tab navigation.
class AppShellScaffold extends StatelessWidget {
  const AppShellScaffold({super.key, required this.workspace, required this.navigationShell});

  final WorkspaceType workspace;
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = workspace == WorkspaceType.player ? _playerNavItems : _coachNavItems;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: false,
        titleSpacing: SpacingTokens.space12,
        title: ProfileBadge(workspace: workspace),
        actions: [
          IconButton(
            icon: Icon(Symbols.notifications, color: theme.colorScheme.onSurface),
            tooltip: 'Notifications',
            onPressed: () => context.push(AppRoute.notificationsPath(workspace)),
          ),
          const SizedBox(width: SpacingTokens.space8),
        ],
      ),
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        destinations: [
          for (final item in items)
            NavigationDestination(icon: Icon(item.icon), label: item.label),
        ],
      ),
    );
  }
}
