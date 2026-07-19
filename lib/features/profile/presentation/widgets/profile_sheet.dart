import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../design_system/components/vikzar_bottom_sheet.dart';
import '../../../../design_system/components/vikzar_list_row.dart';
import '../../../../design_system/tokens/spacing.dart';
import '../../../../routing/app_router.dart';
import '../../../../services/local_storage/onboarding_progress_store.dart';
import '../../../../shared/models/workspace_type.dart';
import '../../../auth/data/repositories/auth_repository_impl.dart';
import 'workspace_switch_sheet.dart';

/// DESIGN_SPECIFICATION.md §13/§16 — the profile bottom sheet, the single
/// entry point for account-level actions (Phase 7, [DECISIONS.md
/// ADR-047](../../../../../DECISIONS.md#adr-047-the-profile-badge-is-the-single-entry-point-for-account-level-actions)).
/// Content is account-shape-dependent, never a fixed list:
///
/// - **Single-workspace account:** Profile, Settings, Notifications,
///   **Become a Coach** (Player-only — there is no symmetric "become a
///   player" path for a Coach-only account), Help, About, Sign Out.
/// - **Dual-workspace account:** the same rows, with **Switch Workspace**
///   in place of Become a Coach.
class ProfileSheet extends ConsumerWidget {
  const ProfileSheet({super.key, required this.workspace});

  final WorkspaceType workspace;

  static Future<void> show(BuildContext context, {required WorkspaceType workspace}) {
    return VikzarBottomSheet.show<void>(
      context,
      builder: (_) => ProfileSheet(workspace: workspace),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final held = ref.watch(onboardingCompletionProvider);
    final isDual = held.length > 1;

    void closeSheetThen(void Function() action) {
      Navigator.of(context).pop();
      action();
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: SpacingTokens.space16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: SpacingTokens.space20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: colorScheme.onSurface.withValues(alpha: 0.12),
                    child: Icon(Symbols.person, color: colorScheme.onSurface),
                  ),
                  const SizedBox(width: SpacingTokens.space12),
                  Text('${workspace.label} workspace', style: theme.textTheme.titleMedium),
                ],
              ),
            ),
            const SizedBox(height: SpacingTokens.space12),
            VikzarListRow(
              leading: Icon(Symbols.account_circle, color: colorScheme.onSurface),
              title: 'Profile',
              onTap: () =>
                  closeSheetThen(() => context.go(AppRoute.profilePath(workspace))),
            ),
            VikzarListRow(
              leading: Icon(Symbols.settings, color: colorScheme.onSurface),
              title: 'Settings',
              onTap: () =>
                  closeSheetThen(() => context.push(AppRoute.settingsPath(workspace))),
            ),
            VikzarListRow(
              leading: Icon(Symbols.notifications, color: colorScheme.onSurface),
              title: 'Notifications',
              onTap: () => closeSheetThen(
                () => context.push(AppRoute.notificationsPath(workspace)),
              ),
            ),
            if (isDual)
              VikzarListRow(
                leading: Icon(Symbols.swap_horiz, color: colorScheme.onSurface),
                title: 'Switch Workspace',
                onTap: () =>
                    closeSheetThen(() => WorkspaceSwitchSheet.show(context)),
              )
            else if (workspace == WorkspaceType.player)
              VikzarListRow(
                leading: Icon(Symbols.military_tech, color: colorScheme.primary),
                title: 'Become a Coach',
                onTap: () =>
                    closeSheetThen(() => context.push(AppRoute.becomeCoachPath)),
              ),
            const Divider(height: SpacingTokens.space24),
            VikzarListRow(
              leading: Icon(Symbols.help, color: colorScheme.onSurface),
              title: 'Help',
              onTap: () => Navigator.of(context).pop(),
            ),
            VikzarListRow(
              leading: Icon(Symbols.info, color: colorScheme.onSurface),
              title: 'About',
              onTap: () => Navigator.of(context).pop(),
            ),
            VikzarListRow(
              leading: Icon(Symbols.logout, color: colorScheme.error),
              title: 'Sign Out',
              onTap: () => closeSheetThen(
                () => ref.read(authRepositoryProvider).signOut(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
