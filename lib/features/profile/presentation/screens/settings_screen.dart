import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../design_system/components/vikzar_bottom_sheet.dart';
import '../../../../design_system/components/vikzar_list_row.dart';
import '../../../../design_system/components/vikzar_section_header.dart';
import '../../../../design_system/tokens/spacing.dart';
import '../../../../routing/app_router.dart';
import '../../../../shared/models/workspace_type.dart';
import '../../../../shared/widgets/fade_scale_in.dart';
import '../../../auth/data/repositories/auth_repository_impl.dart';
import '../../../auth/domain/models/auth_state.dart';

/// Settings — DESIGN_SPECIFICATION.md §19.2/§19.3 (shared layout for both
/// workspaces). **Rebuilt at Phase 9** to the product's exact minimal list:
/// Account, Notifications, Privacy, Support, About, Sign Out — nothing
/// unnecessary. Drops the Workspace row (redundant with the profile badge),
/// the Device/Bluetooth section (now covered by Profile's Connected Pod
/// row), Legal, and the previously-dead, unwired Delete Account row.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key, required this.workspace});

  final WorkspaceType workspace;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final authState = ref.watch(authStateProvider).value;
    final email = authState is Authenticated ? authState.email : null;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: FadeScaleIn(
          child: ListView(
            children: [
              const VikzarSectionHeader('Account'),
              VikzarListRow(
                leading: Icon(Symbols.mail, color: theme.colorScheme.onSurface),
                title: 'Email',
                subtitle: email ?? 'Unavailable',
              ),
              const VikzarSectionHeader('Notifications'),
              VikzarListRow(
                leading: Icon(Symbols.notifications, color: theme.colorScheme.onSurface),
                title: 'Notifications',
                subtitle: 'View your notification history',
                onTap: () => context.push(AppRoute.notificationsPath(workspace)),
              ),
              const VikzarSectionHeader('Support'),
              VikzarListRow(
                leading: Icon(Symbols.privacy_tip, color: theme.colorScheme.onSurface),
                title: 'Privacy',
                onTap: () => _showInfoSheet(
                  context,
                  title: 'Privacy',
                  body:
                      'Vikzar collects only the training-status and profile data you '
                      'provide, and session data once your Pod is connected. It is never '
                      'shared outside your team without your knowledge.',
                ),
              ),
              VikzarListRow(
                leading: Icon(Symbols.help, color: theme.colorScheme.onSurface),
                title: 'Support',
                onTap: () => _showInfoSheet(
                  context,
                  title: 'Support',
                  body: 'Questions or issues? Reach your club or academy administrator, '
                      'or the Vikzar team, for help.',
                ),
              ),
              VikzarListRow(
                leading: Icon(Symbols.info, color: theme.colorScheme.onSurface),
                title: 'About',
                onTap: () => _showInfoSheet(
                  context,
                  title: 'About Vikzar',
                  body: 'Vikzar is a sports performance and biomechanics analytics '
                      'platform for football. Know Every Impact.',
                ),
              ),
              const SizedBox(height: SpacingTokens.space16),
              VikzarListRow(
                leading: Icon(Symbols.logout, color: theme.colorScheme.onSurface),
                title: 'Sign Out',
                onTap: () => ref.read(authRepositoryProvider).signOut(),
              ),
              const SizedBox(height: SpacingTokens.space32),
            ],
          ),
        ),
      ),
    );
  }
}

void _showInfoSheet(BuildContext context, {required String title, required String body}) {
  VikzarBottomSheet.show<void>(
    context,
    builder: (context) {
      final theme = Theme.of(context);
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(SpacingTokens.space20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleLarge),
              const SizedBox(height: SpacingTokens.space12),
              Text(
                body,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: SpacingTokens.space8),
            ],
          ),
        ),
      );
    },
  );
}
