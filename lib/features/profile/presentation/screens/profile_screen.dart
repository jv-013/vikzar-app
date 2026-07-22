import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../../design_system/components/vikzar_list_row.dart';
import '../../../../design_system/components/vikzar_section_header.dart';
import '../../../../design_system/components/vikzar_status_chip.dart';
import '../../../../design_system/tokens/spacing.dart';
import '../../../../routing/app_router.dart';
import '../../../../shared/models/coach_profile.dart';
import '../../../../shared/models/player_profile.dart';
import '../../../../shared/models/workspace_type.dart';
import '../../../../shared/providers/current_app_user_provider.dart';
import '../../../../shared/widgets/fade_scale_in.dart';
import '../widgets/edit_profile_sheet.dart';

final appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return '${info.version} (${info.buildNumber})';
});

/// Profile — DESIGN_SPECIFICATION.md §19.2/§19.3. **Player branch rebuilt
/// at Phase 9** to the product's exact Player Card structure: Personal,
/// Football, Physical, Training Status, and (conditionally) injury detail,
/// each its own labeled section rather than one flat "About You" list —
/// Height/Weight/Level are shown here for the first time (collected at
/// onboarding, never surfaced before this phase). The Coach branch is
/// unchanged this phase. One screen adapting by [workspace] rather than a
/// `PlayerProfileScreen`/`CoachProfileScreen` pair.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key, required this.workspace});

  final WorkspaceType workspace;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isPlayer = workspace == WorkspaceType.player;
    final user = ref.watch(currentAppUserProvider);
    final name = user?.displayName ?? '';
    final versionAsync = ref.watch(appVersionProvider);
    final playerProfile = user?.playerProfile ?? const PlayerProfile();

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
      body: SafeArea(
        child: FadeScaleIn(
          child: ListView(
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
                    if (isPlayer && playerProfile.position != null) ...[
                      const SizedBox(height: SpacingTokens.space4),
                      Text(
                        playerProfile.position!.label,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: SpacingTokens.space16),
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
              if (isPlayer)
                ..._playerSections(context, playerProfile)
              else ...[
                const VikzarSectionHeader('About You'),
                ..._coachAboutRows(ref),
              ],
              const VikzarSectionHeader('Connected Pod'),
              VikzarListRow(
                leading: Icon(Symbols.sensors_off, color: theme.colorScheme.secondary),
                title: 'No Pod connected',
                subtitle: 'Assigned by your coach once training begins',
              ),
              const VikzarSectionHeader('About'),
              VikzarListRow(
                leading: Icon(Symbols.info, color: theme.colorScheme.onSurface),
                title: 'App Version',
                subtitle: versionAsync.when(
                  data: (value) => value,
                  loading: () => '—',
                  error: (_, _) => 'Unavailable',
                ),
              ),
              const SizedBox(height: SpacingTokens.space32),
            ],
          ),
        ),
      ),
    );
  }
}

List<Widget> _playerSections(BuildContext context, PlayerProfile profile) {
  final theme = Theme.of(context);
  final showInjuryDetail =
      profile.trainingStatus != null && profile.trainingStatus != TrainingStatus.fullyAvailable;

  return [
    const VikzarSectionHeader('Personal'),
    VikzarListRow(title: 'Age', subtitle: profile.age?.toString() ?? 'Not set'),
    const VikzarSectionHeader('Football'),
    VikzarListRow(title: 'Level', subtitle: profile.level?.label ?? 'Not set'),
    VikzarListRow(title: 'Playing Position', subtitle: profile.position?.label ?? 'Not set'),
    VikzarListRow(title: 'Preferred Foot', subtitle: profile.preferredFoot?.label ?? 'Not set'),
    const VikzarSectionHeader('Physical'),
    VikzarListRow(
      title: 'Height',
      subtitle: profile.heightCm == null ? 'Not set' : '${profile.heightCm!.toStringAsFixed(0)} cm',
    ),
    VikzarListRow(
      title: 'Weight',
      subtitle: profile.weightKg == null ? 'Not set' : '${profile.weightKg!.toStringAsFixed(0)} kg',
    ),
    const VikzarSectionHeader('Training Status'),
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: SpacingTokens.space16),
      child: Align(
        alignment: Alignment.centerLeft,
        child: profile.trainingStatus == null
            ? Text(
                'Not set',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            : VikzarStatusChip(label: profile.trainingStatus!.label),
      ),
    ),
    if (showInjuryDetail) ...[
      const SizedBox(height: SpacingTokens.space16),
      const VikzarSectionHeader('Injury Detail'),
      VikzarListRow(
        title: 'Type',
        subtitle: profile.injuryTypes.isEmpty
            ? 'Not set'
            : profile.injuryTypes.map((t) => t.label).join(', '),
      ),
      VikzarListRow(
        title: 'Expected recovery',
        subtitle: profile.recoveryTimeframe?.label ?? 'Not set',
      ),
    ],
  ];
}

List<Widget> _coachAboutRows(WidgetRef ref) {
  final profile = ref.watch(currentAppUserProvider)?.coachProfile ?? const CoachProfile();
  return [
    VikzarListRow(title: 'Age', subtitle: profile.age?.toString() ?? 'Not set'),
    VikzarListRow(
      title: 'Role',
      subtitle: (profile.title ?? '').isEmpty ? 'Not set' : profile.title!,
    ),
    VikzarListRow(
      title: 'Club',
      subtitle: (profile.club ?? '').isEmpty ? 'Not set' : profile.club!,
    ),
  ];
}

