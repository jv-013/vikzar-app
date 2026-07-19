import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../../design_system/components/vikzar_list_row.dart';
import '../../../../design_system/tokens/spacing.dart';
import '../../../../routing/app_router.dart';
import '../../../../shared/models/workspace_type.dart';
import '../../../onboarding/presentation/controllers/coach_onboarding_controller.dart';
import '../../../onboarding/presentation/controllers/player_onboarding_controller.dart';
import '../widgets/edit_profile_sheet.dart';

final appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return '${info.version} (${info.buildNumber})';
});

/// Profile — DESIGN_SPECIFICATION.md §19.2/§19.3, revised Phase 7: avatar
/// + name, an "About You" section (workspace-specific fields, edited via
/// [EditProfileSheet]), Workspace Information, Connected Device Summary,
/// and Application Version. One screen adapting by [workspace] rather
/// than a `PlayerProfileScreen`/`CoachProfileScreen` pair — the layout
/// skeleton is identical per the frozen spec ("same layout skeleton as
/// Player Profile, with Coach Profile fields instead").
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key, required this.workspace});

  final WorkspaceType workspace;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isPlayer = workspace == WorkspaceType.player;
    final name = isPlayer
        ? ref.watch(playerOnboardingControllerProvider.select((d) => d.profile.name))
        : ref.watch(coachOnboardingControllerProvider.select((d) => d.profile.name));
    final versionAsync = ref.watch(appVersionProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Symbols.settings),
            tooltip: 'Settings',
            onPressed: () => context.push(AppRoute.settingsPath(workspace)),
          ),
        ],
      ),
      body: ListView(
        children: [
          const SizedBox(height: SpacingTokens.space16),
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.12),
                  child: Icon(Symbols.person, size: 40, color: theme.colorScheme.onSurface),
                ),
                const SizedBox(height: SpacingTokens.space12),
                Text(
                  name.trim().isEmpty ? '${workspace.label} account' : name.trim(),
                  style: theme.textTheme.titleLarge,
                ),
              ],
            ),
          ),
          const SizedBox(height: SpacingTokens.space24),
          const _SectionHeader('About You'),
          if (isPlayer) ..._playerAboutRows(ref) else ..._coachAboutRows(ref),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: SpacingTokens.space16),
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => EditProfileSheet.show(context, workspace: workspace),
                child: const Text('Edit Profile'),
              ),
            ),
          ),
          const _SectionHeader('Workspace Information'),
          VikzarListRow(
            leading: Icon(Symbols.badge, color: theme.colorScheme.onSurface),
            title: '${workspace.label} workspace',
            subtitle: 'Active on this device',
          ),
          const _SectionHeader('Connected Device'),
          VikzarListRow(
            leading: Icon(Symbols.sensors_off, color: theme.colorScheme.onSurface),
            title: 'No Pod connected',
            subtitle: 'Assigned by your coach once training begins',
          ),
          const _SectionHeader('About'),
          VikzarListRow(
            leading: Icon(Symbols.info, color: theme.colorScheme.onSurface),
            title: 'Application Version',
            subtitle: versionAsync.when(
              data: (value) => value,
              loading: () => '—',
              error: (_, _) => 'Unavailable',
            ),
          ),
          const SizedBox(height: SpacingTokens.space32),
        ],
      ),
    );
  }
}

List<Widget> _playerAboutRows(WidgetRef ref) {
  final profile = ref.watch(playerOnboardingControllerProvider).profile;
  return [
    VikzarListRow(title: 'Age', subtitle: profile.age?.toString() ?? 'Not set'),
    VikzarListRow(
      title: 'Preferred Foot',
      subtitle: profile.preferredFoot?.label ?? 'Not set',
    ),
    VikzarListRow(title: 'Playing Position', subtitle: profile.position?.label ?? 'Not set'),
  ];
}

List<Widget> _coachAboutRows(WidgetRef ref) {
  final profile = ref.watch(coachOnboardingControllerProvider).profile;
  return [
    VikzarListRow(title: 'Age', subtitle: profile.age?.toString() ?? 'Not set'),
    VikzarListRow(
      title: 'Coaching Title/Role',
      subtitle: profile.title.isEmpty ? 'Not set' : profile.title,
    ),
    VikzarListRow(
      title: 'Club/Organization',
      subtitle: profile.club.isEmpty ? 'Not set' : profile.club,
    ),
  ];
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
