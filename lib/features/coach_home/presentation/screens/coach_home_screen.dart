import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../design_system/theme/vikzar_elevation.dart';
import '../../../../design_system/tokens/radius.dart';
import '../../../../design_system/tokens/spacing.dart';
import '../../../../routing/app_router.dart';
import '../../../../shared/widgets/section_empty_state.dart';
import '../../../onboarding/presentation/controllers/coach_onboarding_controller.dart';

/// Coach Home — DESIGN_SPECIFICATION.md §19.3, revised Phase 7.
/// Deliberately **a different rhythm from Player Home** — team-level, not
/// a personal instrument panel: Team Status Summary, Roster Preview,
/// Today's Sessions, Recent Alerts, Team Actions. No team/roster data
/// pipeline exists yet (no Firestore team reads built this phase), so
/// every data-dependent section is a genuine, honestly-labeled empty
/// state — never an invented count.
class CoachHomeScreen extends ConsumerWidget {
  const CoachHomeScreen({super.key});

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
            const _TeamStatusSummaryCard(),
            const SizedBox(height: SpacingTokens.space32),
            Text('Roster', style: theme.textTheme.titleLarge),
            const SizedBox(height: SpacingTokens.space8),
            SectionEmptyState(
              icon: Symbols.group_off,
              headline: 'No players yet.',
              actionLabel: 'Invite Player',
              onAction: () => _showComingSoonSnackBar(context, 'Invite Player'),
            ),
            const SizedBox(height: SpacingTokens.space32),
            Text("Today's Sessions", style: theme.textTheme.titleLarge),
            const SizedBox(height: SpacingTokens.space8),
            const SectionEmptyState(
              icon: Symbols.event_available,
              headline: 'No sessions scheduled today.',
            ),
            const SizedBox(height: SpacingTokens.space32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Recent Alerts', style: theme.textTheme.titleLarge),
                TextButton(
                  onPressed: () => context.go(AppRoute.coachAlertsPath),
                  child: const Text('View All'),
                ),
              ],
            ),
            const SectionEmptyState(
              icon: defaultEmptyStateIcon,
              headline: 'No alerts.',
              body: "That's a good thing.",
            ),
            const SizedBox(height: SpacingTokens.space32),
            Text('Team Actions', style: theme.textTheme.titleLarge),
            const SizedBox(height: SpacingTokens.space12),
            Wrap(
              spacing: SpacingTokens.space12,
              runSpacing: SpacingTokens.space8,
              children: [
                TextButton.icon(
                  onPressed: () => _showComingSoonSnackBar(context, 'Invite Player'),
                  icon: const Icon(Symbols.person_add),
                  label: const Text('Invite Player'),
                ),
                TextButton.icon(
                  onPressed: () => _showComingSoonSnackBar(context, 'Create Team'),
                  icon: const Icon(Symbols.add_circle),
                  label: const Text('Create Team'),
                ),
                TextButton.icon(
                  onPressed: () => _showComingSoonSnackBar(context, 'Join Team'),
                  icon: const Icon(Symbols.group_add),
                  label: const Text('Join Team'),
                ),
              ],
            ),
            const SizedBox(height: SpacingTokens.space32),
          ],
        ),
      ),
    );
  }
}

String _greeting(String? name) => name == null ? 'Good to see you, Coach.' : 'Hi, $name.';

String? _greetingName(WidgetRef ref) {
  final onboardingName = ref.watch(
    coachOnboardingControllerProvider.select((data) => data.profile.name),
  );
  if (onboardingName.trim().isNotEmpty) return onboardingName.trim().split(' ').first;
  return null;
}

void _showComingSoonSnackBar(BuildContext context, String action) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('$action is coming in a future phase.')),
  );
}

class _TeamStatusSummaryCard extends StatelessWidget {
  const _TeamStatusSummaryCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final elevation = theme.extension<VikzarElevation>();
    final background = elevation == null
        ? theme.colorScheme.surface
        : Color.alphaBlend(elevation.level1Overlay, theme.colorScheme.surface);

    return Container(
      padding: const EdgeInsets.all(SpacingTokens.space20),
      decoration: BoxDecoration(color: background, borderRadius: RadiusTokens.largeRadius),
      child: Row(
        children: [
          Expanded(
            child: _StatusCount(label: 'Normal', value: '—', color: colorScheme.onSurface),
          ),
          Expanded(
            child: _StatusCount(
              label: 'Elevated',
              value: '—',
              color: colorScheme.primary,
            ),
          ),
          Expanded(
            child: _StatusCount(
              label: 'High',
              value: '—',
              color: colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusCount extends StatelessWidget {
  const _StatusCount({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(value, style: theme.textTheme.displayLarge?.copyWith(color: color)),
        const SizedBox(height: SpacingTokens.space4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
