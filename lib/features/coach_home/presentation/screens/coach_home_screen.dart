import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../design_system/theme/vikzar_elevation.dart';
import '../../../../design_system/tokens/radius.dart';
import '../../../../design_system/tokens/spacing.dart';
import '../../../../routing/app_router.dart';
import '../../../../shared/models/workspace_type.dart';
import '../../../../shared/providers/current_app_user_provider.dart';
import '../../../../shared/widgets/fade_scale_in.dart';
import '../../../../shared/widgets/notification_timeline_card.dart';
import '../../../../shared/widgets/section_empty_state.dart';
import '../../../notifications/presentation/controllers/notifications_controller.dart';
import '../../../team/presentation/controllers/team_roster_controller.dart';
import '../controllers/squad_summary_controller.dart';

/// Coach Home — DESIGN_SPECIFICATION.md §19.3, **rebuilt at Phase 9** to
/// the product's exact section list: Greeting, Today's Squad, Players
/// Requiring Attention, Today's Training, Recent Team Activity, Quick
/// Actions. Deliberately a different rhythm from Player Home — team-level,
/// not a personal instrument panel.
///
/// Today's Squad is the one section with a genuinely real, aggregated
/// signal: each roster member's own `trainingStatus`, combined by
/// [squadSummaryProvider] — never a fabricated count. Players Requiring
/// Attention and Today's Training remain honest placeholders — no AI
/// pipeline or scheduling collection exists yet. Recent Team Activity is
/// backed by the coach's own real notification stream, the same pattern
/// Player Activity uses (a coach cannot read a specific other player's
/// notifications — Security Rules scope that subcollection to self-only).
class CoachHomeScreen extends ConsumerWidget {
  const CoachHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(currentAppUserProvider);
    final name = _firstName(user?.displayName);
    final club = user?.coachProfile?.club;
    final teamId = ref.watch(coachTeamIdProvider);
    final notificationsAsync = ref.watch(notificationsControllerProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: FadeScaleIn(
          child: ListView(
            padding: const EdgeInsets.symmetric(
              horizontal: SpacingTokens.space16,
              vertical: SpacingTokens.space16,
            ),
            children: [
              Text(_greeting(name), style: theme.textTheme.headlineLarge),
              if (club != null && club.trim().isNotEmpty) ...[
                const SizedBox(height: SpacingTokens.space4),
                Text(
                  club.trim(),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: SpacingTokens.space24),
              _TodaysSquadCard(teamId: teamId),
              const SizedBox(height: SpacingTokens.space32),
              Text('Players Requiring Attention', style: theme.textTheme.titleLarge),
              const SizedBox(height: SpacingTokens.space8),
              const SectionEmptyState(
                icon: Symbols.priority_high,
                headline: 'Nothing to flag right now.',
                body: 'Players needing attention will surface here once enough '
                    'training data has been collected.',
              ),
              const SizedBox(height: SpacingTokens.space32),
              Text("Today's Training", style: theme.textTheme.titleLarge),
              const SizedBox(height: SpacingTokens.space8),
              const SectionEmptyState(
                icon: Symbols.event_available,
                headline: 'No training scheduled today.',
              ),
              const SizedBox(height: SpacingTokens.space32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Recent Team Activity', style: theme.textTheme.titleLarge),
                  TextButton(
                    onPressed: () =>
                        context.push(AppRoute.notificationsPath(WorkspaceType.coach)),
                    child: const Text('View All'),
                  ),
                ],
              ),
              const SizedBox(height: SpacingTokens.space8),
              notificationsAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
                data: (notifications) {
                  if (notifications.isEmpty) {
                    return const SectionEmptyState(
                      icon: Symbols.timeline,
                      headline: 'No activity yet.',
                      body: "This will fill in once your team's training data "
                          'starts flowing.',
                    );
                  }
                  return Column(
                    children: [
                      for (final notification in notifications.take(2)) ...[
                        NotificationTimelineCard(notification: notification),
                        const SizedBox(height: SpacingTokens.space12),
                      ],
                    ],
                  );
                },
              ),
              const SizedBox(height: SpacingTokens.space32),
              Text('Quick Actions', style: theme.textTheme.titleLarge),
              const SizedBox(height: SpacingTokens.space12),
              _QuickActions(teamId: teamId),
              const SizedBox(height: SpacingTokens.space32),
            ],
          ),
        ),
      ),
    );
  }
}

String _greeting(String? name) => name == null ? 'Good to see you, Coach.' : 'Hi, $name.';

String? _firstName(String? displayName) {
  if (displayName == null || displayName.trim().isEmpty) return null;
  return displayName.trim().split(' ').first;
}

class _TodaysSquadCard extends ConsumerWidget {
  const _TodaysSquadCard({required this.teamId});

  final String? teamId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final elevation = theme.extension<VikzarElevation>();
    final background = elevation == null
        ? theme.colorScheme.surface
        : Color.alphaBlend(elevation.level1Overlay, theme.colorScheme.surface);
    final summary = teamId == null ? null : ref.watch(squadSummaryProvider(teamId!)).value;

    return Container(
      padding: const EdgeInsets.all(SpacingTokens.space20),
      decoration: BoxDecoration(color: background, borderRadius: RadiusTokens.largeRadius),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Today's Squad", style: theme.textTheme.titleSmall),
          const SizedBox(height: SpacingTokens.space16),
          Row(
            children: [
              Expanded(
                child: _SquadCount(
                  label: 'Available',
                  value: summary?.fullyAvailable,
                  color: theme.colorScheme.secondary,
                ),
              ),
              Expanded(
                child: _SquadCount(
                  label: 'Individual',
                  value: summary?.individualTraining,
                  color: theme.colorScheme.secondary,
                ),
              ),
              Expanded(
                child: _SquadCount(
                  label: 'Return to Play',
                  value: summary?.returnToPlay,
                  color: theme.colorScheme.secondary,
                ),
              ),
              Expanded(
                child: _SquadCount(
                  label: 'Unavailable',
                  value: summary?.unavailable,
                  color: theme.colorScheme.secondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SquadCount extends StatelessWidget {
  const _SquadCount({required this.label, required this.value, required this.color});

  final String label;
  final int? value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          value == null ? '—' : '$value',
          style: theme.textTheme.displayLarge?.copyWith(color: color),
        ),
        const SizedBox(height: SpacingTokens.space4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.teamId});

  final String? teamId;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: SpacingTokens.space12,
      runSpacing: SpacingTokens.space8,
      children: [
        TextButton.icon(
          onPressed: () => _showComingSoonSnackBar(context, 'Create Team'),
          icon: const Icon(Symbols.add_circle),
          label: const Text('Create Team'),
        ),
        TextButton.icon(
          onPressed: () => _showInvitePlayerSheet(context, teamId),
          icon: const Icon(Symbols.person_add),
          label: const Text('Invite Player'),
        ),
        TextButton.icon(
          onPressed: () => context.go(AppRoute.coachTeamPath),
          icon: const Icon(Symbols.group),
          label: const Text('View Team'),
        ),
        TextButton.icon(
          onPressed: () => context.push(AppRoute.notificationsPath(WorkspaceType.coach)),
          icon: const Icon(Symbols.notifications),
          label: const Text('Notifications'),
        ),
      ],
    );
  }
}

void _showComingSoonSnackBar(BuildContext context, String action) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('$action is coming in a future phase.')),
  );
}

void _showInvitePlayerSheet(BuildContext context, String? teamId) {
  showDialog<void>(
    context: context,
    builder: (context) {
      final theme = Theme.of(context);
      return AlertDialog(
        title: const Text('Invite Player'),
        content: teamId == null
            ? const Text('Create a team first — then its Team ID becomes the invite code.')
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Share this Team ID so a player can join your team:',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: SpacingTokens.space12),
                  SelectableText(teamId, style: theme.textTheme.titleMedium),
                ],
              ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Done')),
        ],
      );
    },
  );
}
