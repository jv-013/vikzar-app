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
import '../../../alerts/presentation/controllers/alerts_controller.dart';
import '../../../notifications/presentation/controllers/notifications_controller.dart';
import '../../../sessions/domain/models/planned_session.dart';
import '../../../sessions/presentation/controllers/planned_sessions_controller.dart';
import '../../../team/presentation/controllers/team_roster_controller.dart';
import '../controllers/squad_summary_controller.dart';

/// Coach Dashboard — DESIGN_SPECIFICATION.md §19.3, **rebuilt at Phase 9**,
/// **remapped at Phase 13** (§5) to: Greeting, Today's Squad (Connected
/// Players), Today's Sessions, Active Alerts, Connected Pods, Recent
/// Reports, Recent Team Activity, Quick Actions. Deliberately a different
/// rhythm from Player Home — team-level, not a personal instrument panel.
///
/// Today's Squad, Today's Sessions, Active Alerts, and Recent Team
/// Activity are all genuinely real, aggregated signals — never a
/// fabricated count. Connected Pods and Recent Reports remain honest
/// placeholders: no device-telemetry aggregation view or reports pipeline
/// exists yet (the same "schema ready, no UI to bind to nothing" reasoning
/// Phase 11's battery-architecture pass used).
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
              Text("Today's Sessions", style: theme.textTheme.titleLarge),
              const SizedBox(height: SpacingTokens.space8),
              _TodaysSessionsSection(teamId: teamId),
              const SizedBox(height: SpacingTokens.space32),
              const _ActiveAlertsCard(),
              const SizedBox(height: SpacingTokens.space32),
              Text('Connected Pods', style: theme.textTheme.titleLarge),
              const SizedBox(height: SpacingTokens.space8),
              const SectionEmptyState(
                icon: Symbols.sensors,
                headline: 'No Pods connected.',
                body: 'Connected devices will appear here once hardware is paired.',
              ),
              const SizedBox(height: SpacingTokens.space32),
              Text('Recent Reports', style: theme.textTheme.titleLarge),
              const SizedBox(height: SpacingTokens.space8),
              const SectionEmptyState(
                icon: Symbols.description,
                headline: 'No reports yet.',
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

class _TodaysSessionsSection extends ConsumerWidget {
  const _TodaysSessionsSection({required this.teamId});

  final String? teamId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (teamId == null) {
      return const SectionEmptyState(
        icon: Symbols.event_busy,
        headline: 'No team yet.',
      );
    }
    final sessionsAsync = ref.watch(upcomingPlannedSessionsProvider(teamId!));
    return sessionsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (result) => result.fold(
        onSuccess: (sessions) {
          final today = DateTime.now();
          final todaysSessions = sessions
              .where(
                (s) =>
                    s.scheduledAt.year == today.year &&
                    s.scheduledAt.month == today.month &&
                    s.scheduledAt.day == today.day,
              )
              .toList();
          if (todaysSessions.isEmpty) {
            return const SectionEmptyState(
              icon: Symbols.event_available,
              headline: 'No sessions scheduled today.',
            );
          }
          return Column(
            children: [
              for (final session in todaysSessions) ...[
                _TodaySessionRow(session: session),
                const SizedBox(height: SpacingTokens.space8),
              ],
            ],
          );
        },
        onFailure: (_) => const SizedBox.shrink(),
      ),
    );
  }
}

class _TodaySessionRow extends StatelessWidget {
  const _TodaySessionRow({required this.session});

  final PlannedSession session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(
          session.type == PlannedSessionType.match
              ? Symbols.sports_soccer
              : Symbols.fitness_center,
          size: 18,
          color: theme.colorScheme.secondary,
        ),
        const SizedBox(width: SpacingTokens.space8),
        Expanded(child: Text(session.title, style: theme.textTheme.bodyMedium)),
      ],
    );
  }
}

class _ActiveAlertsCard extends ConsumerWidget {
  const _ActiveAlertsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final alertsAsync = ref.watch(alertsControllerProvider);
    final unacknowledgedCount = alertsAsync.value?.fold(
      onSuccess: (alerts) => alerts.where((a) => !a.acknowledged).length,
      onFailure: (_) => 0,
    );

    return InkWell(
      onTap: () => context.push(AppRoute.coachAlertsPath),
      borderRadius: RadiusTokens.mediumRadius,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Active Alerts', style: theme.textTheme.titleLarge),
          Row(
            children: [
              Text(
                unacknowledgedCount == null ? '—' : '$unacknowledgedCount',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: unacknowledgedCount != null && unacknowledgedCount > 0
                      ? theme.colorScheme.error
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Icon(Symbols.chevron_right, color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ],
      ),
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
