import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../design_system/components/vikzar_bottom_sheet.dart';
import '../../../../design_system/components/vikzar_list_row.dart';
import '../../../../design_system/components/vikzar_section_header.dart';
import '../../../../design_system/components/vikzar_segmented_control.dart';
import '../../../../design_system/theme/theme_mode_provider.dart';
import '../../../../design_system/tokens/spacing.dart';
import '../../../../routing/app_router.dart';
import '../../../../shared/models/workspace_type.dart';
import '../../../../shared/widgets/fade_scale_in.dart';
import '../../../auth/data/repositories/auth_repository_impl.dart';
import '../../../auth/domain/models/auth_state.dart';
import '../../../music/domain/models/music_provider_type.dart';
import '../../../raz/data/providers/raz_speech_providers.dart';
import '../../../raz/presentation/controllers/raz_voice_settings_controller.dart';

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
    final themeMode = ref.watch(themeModeProvider);
    final voiceSettings = ref.watch(razVoiceSettingsControllerProvider);
    final voiceSettingsNotifier = ref.read(razVoiceSettingsControllerProvider.notifier);

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
              const VikzarSectionHeader('Appearance'),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: SpacingTokens.space16,
                  vertical: SpacingTokens.space8,
                ),
                child: VikzarSegmentedControl<ThemeMode>(
                  options: ThemeMode.values,
                  selected: themeMode,
                  labelBuilder: (mode) => switch (mode) {
                    ThemeMode.system => 'System',
                    ThemeMode.light => 'Light',
                    ThemeMode.dark => 'Dark',
                  },
                  onChanged: (mode) => ref.read(themeModeProvider.notifier).setThemeMode(mode),
                ),
              ),
              // Player-only extension point (Phase 19.5 Part 9) — no
              // coach equivalent, see lib/features/music/README.md. No
              // provider is connected yet; tapping shows what's coming
              // rather than pretending to connect to anything real.
              if (workspace == WorkspaceType.player)
                VikzarListRow(
                  leading: Icon(Symbols.music_note, color: theme.colorScheme.onSurface),
                  title: 'Music',
                  subtitle: MusicProviderType.none.label,
                  onTap: () => _showInfoSheet(
                    context,
                    title: 'Music',
                    body: 'Spotify and Apple Music support is coming soon — connect your '
                        "music to play alongside your training sessions once it's ready.",
                  ),
                ),
              const VikzarSectionHeader('Voice'),
              VikzarListRow(
                leading: Icon(Symbols.mic, color: theme.colorScheme.onSurface),
                title: '"Hey Raz"',
                subtitle: 'Keeps the mic listening for "Hey Raz" while Vikzar is open. Uses more battery. Off by default.',
                trailing: Switch(
                  value: voiceSettings.wakeWordEnabled,
                  onChanged: voiceSettingsNotifier.setWakeWordEnabled,
                ),
                onTap: () => _showInfoSheet(
                  context,
                  title: '"Hey Raz"',
                  body: 'When this is on, Vikzar keeps the microphone listening for the wake '
                      "word using your phone's own speech recognition — the same recognition "
                      'used when you tap the mic to talk. It only listens while Vikzar is open '
                      "in the foreground, and switches off automatically the moment you leave "
                      "the app or put your phone to sleep — it never listens in the background. "
                      "Because the microphone stays active the whole time the app is open, this "
                      "uses more battery than Push-to-Talk. Vikzar's own servers only ever see a "
                      'question after you say "Hey Raz" and ask one — not before. This is why '
                      'it is off by default: Push-to-Talk (tap the mic) gets you the same RAZ '
                      'without the battery trade-off.',
                ),
              ),
              const _RazVoiceSelector(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: SpacingTokens.space16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Speech speed',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Slider(
                      value: voiceSettings.speechRate,
                      onChanged: voiceSettingsNotifier.setSpeechRate,
                    ),
                    Text(
                      'Speech volume',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Slider(
                      value: voiceSettings.speechVolume,
                      onChanged: voiceSettingsNotifier.setSpeechVolume,
                    ),
                  ],
                ),
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

/// "RAZ Voice" — Displays available product presets (e.g. UK English Male)
/// that are genuinely installed on this device. If none match, shows
/// Device Default.
class _RazVoiceSelector extends ConsumerWidget {
  const _RazVoiceSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presetsAsync = ref.watch(razAvailablePresetsProvider);
    final availablePresets = presetsAsync.value;
    if (availablePresets == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final voiceSettings = ref.watch(razVoiceSettingsControllerProvider);

    // If there are no resolved presets (or just one), just show device default
    if (availablePresets.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: SpacingTokens.space16, vertical: SpacingTokens.space8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'RAZ Voice',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: SpacingTokens.space8),
            Text('Device Default', style: theme.textTheme.bodyMedium),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: SpacingTokens.space16, vertical: SpacingTokens.space8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'RAZ Voice',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: SpacingTokens.space8),
          DropdownButtonFormField<String>(
            initialValue: voiceSettings.voiceName ?? 'default',
            decoration: const InputDecoration(
              contentPadding: EdgeInsets.symmetric(horizontal: SpacingTokens.space12),
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem(
                value: 'default',
                child: Text('Device Default'),
              ),
              ...availablePresets.map((preset) {
                return DropdownMenuItem(
                  value: preset.voiceName,
                  child: Text(preset.preset.displayLabel),
                );
              }),
            ],
            onChanged: (value) {
              final newVoiceName = value == 'default' ? null : value;
              ref.read(razVoiceSettingsControllerProvider.notifier).setVoiceName(newVoiceName);
            },
          ),
        ],
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
