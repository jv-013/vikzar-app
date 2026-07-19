import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../design_system/components/vikzar_list_row.dart';
import '../../../../design_system/tokens/spacing.dart';
import '../../../../shared/models/workspace_type.dart';
import '../../../auth/data/repositories/auth_repository_impl.dart';
import '../../../auth/domain/models/auth_state.dart';

/// Settings — DESIGN_SPECIFICATION.md §19.2/§19.3 (shared layout for both
/// workspaces), revised Phase 7: Account (Email only — no Password row,
/// per [DECISIONS.md ADR-043](../../../../../DECISIONS.md#adr-043-passwordless-email-otp-authentication-replaces-email--password)),
/// Workspace, Notifications, Bluetooth (placeholder), Connected Pod
/// (placeholder), Privacy, Help, About, Legal, Sign Out, Delete Account.
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
      body: ListView(
        children: [
          const _SectionHeader('Account'),
          VikzarListRow(
            leading: Icon(Symbols.mail, color: theme.colorScheme.onSurface),
            title: 'Email',
            subtitle: email ?? 'Unavailable',
          ),
          const _SectionHeader('Workspace'),
          VikzarListRow(
            leading: Icon(Symbols.badge, color: theme.colorScheme.onSurface),
            title: '${workspace.label} workspace',
            subtitle: 'Active on this device',
          ),
          const _SectionHeader('Notifications'),
          VikzarListRow(
            leading: Icon(Symbols.notifications, color: theme.colorScheme.onSurface),
            title: 'Notification Preferences',
            subtitle: 'Manage what you get notified about',
          ),
          const _SectionHeader('Device'),
          VikzarListRow(
            leading: Icon(Symbols.bluetooth, color: theme.colorScheme.onSurface),
            title: 'Bluetooth',
            subtitle: 'Not connected — managed by your team laptop',
          ),
          VikzarListRow(
            leading: Icon(Symbols.sensors, color: theme.colorScheme.onSurface),
            title: 'Connected Pod',
            subtitle: 'No Pod assigned',
          ),
          const _SectionHeader('Support'),
          VikzarListRow(
            leading: Icon(Symbols.privacy_tip, color: theme.colorScheme.onSurface),
            title: 'Privacy',
          ),
          VikzarListRow(
            leading: Icon(Symbols.help, color: theme.colorScheme.onSurface),
            title: 'Help',
          ),
          VikzarListRow(
            leading: Icon(Symbols.info, color: theme.colorScheme.onSurface),
            title: 'About',
          ),
          VikzarListRow(
            leading: Icon(Symbols.gavel, color: theme.colorScheme.onSurface),
            title: 'Legal',
          ),
          const SizedBox(height: SpacingTokens.space16),
          VikzarListRow(
            leading: Icon(Symbols.logout, color: theme.colorScheme.onSurface),
            title: 'Sign Out',
            onTap: () => ref.read(authRepositoryProvider).signOut(),
          ),
          const SizedBox(height: SpacingTokens.space32),
          VikzarListRow(
            leading: Icon(Symbols.delete_forever, color: theme.colorScheme.error),
            title: 'Delete Account',
          ),
          const SizedBox(height: SpacingTokens.space32),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SpacingTokens.space16,
        SpacingTokens.space24,
        SpacingTokens.space16,
        SpacingTokens.space8,
      ),
      child: Text(
        label,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
