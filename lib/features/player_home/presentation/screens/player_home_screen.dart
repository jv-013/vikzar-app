import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../design_system/theme/vikzar_elevation.dart';
import '../../../../design_system/tokens/radius.dart';
import '../../../../design_system/tokens/spacing.dart';
import '../../../../routing/app_router.dart';
import '../../../../shared/providers/current_app_user_provider.dart';
import '../../../../shared/widgets/section_empty_state.dart';

/// Player Home — DESIGN_SPECIFICATION.md §19.2, revised Phase 7. "A
/// premium performance instrument panel," not a form: Greeting, Connected
/// Pod, Today's Status, Recent Sessions, Impact/Risk Summary, Quick
/// Actions, Recent Activity. No session data pipeline exists yet (no
/// Bluetooth, no ETL, no ML, no Firestore session reads built this
/// phase — DECISIONS.md ADR-030/041), so every data-dependent section is
/// a genuine, honestly-labeled placeholder — never a fabricated number or
/// invented ML prediction.
class PlayerHomeScreen extends ConsumerWidget {
  const PlayerHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final name = _greetingName(ref);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: SpacingTokens.space16,
            vertical: SpacingTokens.space16,
          ),
          children: [
            Text(_greeting(name), style: theme.textTheme.headlineLarge),
            const SizedBox(height: SpacingTokens.space24),
            const _ConnectedPodCard(),
            const SizedBox(height: SpacingTokens.space16),
            const _TodaysStatusCard(),
            const SizedBox(height: SpacingTokens.space32),
            Text('Recent Sessions', style: theme.textTheme.titleLarge),
            const SizedBox(height: SpacingTokens.space8),
            SectionEmptyState(
              icon: Symbols.event_busy,
              headline: 'No sessions yet.',
              actionLabel: 'Learn how sessions work',
              onAction: () => _showLearnMoreDialog(context),
            ),
            const SizedBox(height: SpacingTokens.space24),
            const Row(
              children: [
                Expanded(
                  child: _StatPlaceholderTile(label: 'Impact Summary', icon: Symbols.bolt),
                ),
                SizedBox(width: SpacingTokens.space12),
                Expanded(
                  child: _StatPlaceholderTile(
                    label: 'Risk Summary',
                    icon: Symbols.monitor_heart,
                  ),
                ),
              ],
            ),
            const SizedBox(height: SpacingTokens.space32),
            Text('Quick Actions', style: theme.textTheme.titleLarge),
            const SizedBox(height: SpacingTokens.space12),
            Wrap(
              spacing: SpacingTokens.space12,
              runSpacing: SpacingTokens.space8,
              children: [
                TextButton.icon(
                  onPressed: () => context.go(AppRoute.playerTimelinePath),
                  icon: const Icon(Symbols.timeline),
                  label: const Text('View Timeline'),
                ),
                TextButton.icon(
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        "Pod details will appear here once your coach assigns your Pod.",
                      ),
                    ),
                  ),
                  icon: const Icon(Symbols.sensors),
                  label: const Text('Pod Connection'),
                ),
              ],
            ),
            const SizedBox(height: SpacingTokens.space32),
            Text('Recent Activity', style: theme.textTheme.titleLarge),
            const SizedBox(height: SpacingTokens.space8),
            const SectionEmptyState(
              icon: defaultEmptyStateIcon,
              headline: 'Nothing here yet.',
              body: 'Impact events will show up here once you have a session.',
            ),
            const SizedBox(height: SpacingTokens.space32),
          ],
        ),
      ),
    );
  }
}

String _greeting(String? name) => name == null ? 'Good to see you.' : 'Hi, $name.';

/// Reads `displayName` from Firestore's `users/{uid}` document (Phase 8B —
/// previously the in-memory onboarding controller's still-live name).
/// Falls back to nothing rather than showing a stale/empty value.
String? _greetingName(WidgetRef ref) {
  final displayName = ref.watch(currentAppUserProvider)?.displayName;
  if (displayName != null && displayName.trim().isNotEmpty) {
    return displayName.trim().split(' ').first;
  }
  return null;
}

void _showLearnMoreDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('How sessions work'),
      content: const Text(
        'Once your coach starts a training session, your Vikzar Pod streams '
        'impact data through the team laptop. A summary appears here as soon '
        'as the session ends.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Got it')),
      ],
    ),
  );
}

class _ConnectedPodCard extends StatelessWidget {
  const _ConnectedPodCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final elevation = theme.extension<VikzarElevation>();
    final background = elevation == null
        ? theme.colorScheme.surface
        : Color.alphaBlend(elevation.level1Overlay, theme.colorScheme.surface);

    return Container(
      padding: const EdgeInsets.all(SpacingTokens.space16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: RadiusTokens.mediumRadius,
      ),
      child: Row(
        children: [
          Icon(Symbols.sensors_off, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: SpacingTokens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('No Pod connected', style: theme.textTheme.titleSmall),
                const SizedBox(height: SpacingTokens.space4),
                Text(
                  'Ask your coach to assign your Pod.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Symbols.battery_unknown,
            color: theme.colorScheme.onSurfaceVariant,
            size: 20,
          ),
        ],
      ),
    );
  }
}

class _TodaysStatusCard extends StatelessWidget {
  const _TodaysStatusCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final elevation = theme.extension<VikzarElevation>();
    final background = elevation == null
        ? theme.colorScheme.surface
        : Color.alphaBlend(elevation.level1Overlay, theme.colorScheme.surface);

    return Container(
      padding: const EdgeInsets.all(SpacingTokens.space20),
      decoration: BoxDecoration(
        color: background,
        borderRadius: RadiusTokens.mediumRadius,
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: theme.colorScheme.onSurface.withValues(alpha: 0.16)),
            ),
            child: Text('—', style: theme.textTheme.titleLarge),
          ),
          const SizedBox(width: SpacingTokens.space16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Today's Status", style: theme.textTheme.titleSmall),
                const SizedBox(height: SpacingTokens.space4),
                Text(
                  'No data yet — this fills in after your first session.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatPlaceholderTile extends StatelessWidget {
  const _StatPlaceholderTile({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final elevation = theme.extension<VikzarElevation>();
    final background = elevation == null
        ? theme.colorScheme.surface
        : Color.alphaBlend(elevation.level1Overlay, theme.colorScheme.surface);

    return Container(
      padding: const EdgeInsets.all(SpacingTokens.space16),
      decoration: BoxDecoration(color: background, borderRadius: RadiusTokens.mediumRadius),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: theme.colorScheme.onSurfaceVariant, size: 20),
          const SizedBox(height: SpacingTokens.space12),
          Text('—', style: theme.textTheme.titleLarge),
          const SizedBox(height: SpacingTokens.space4),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
