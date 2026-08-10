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
import '../../../../shared/widgets/recent_activity_feed.dart';
import '../../../../shared/widgets/section_empty_state.dart';
import '../../../alerts/presentation/controllers/alerts_controller.dart';
import '../../../live_monitoring/presentation/controllers/live_monitoring_controller.dart';
import '../../../notifications/presentation/controllers/notifications_controller.dart';
import '../../../raz/presentation/widgets/raz_daily_brief_card.dart';
import '../../../sessions/domain/models/planned_session.dart';
import '../../../sessions/presentation/controllers/planned_sessions_controller.dart';
import '../../../team/presentation/controllers/team_roster_controller.dart';
import '../../../team/presentation/widgets/invite_players_dialog.dart';
import '../controllers/squad_summary_controller.dart';

/// Coach Dashboard — DESIGN_SPECIFICATION.md §19.3, **rebuilt at Phase 9**,
/// **remapped at Phase 13** (§5) to: Greeting, Today's Squad (Connected
/// Players), Today's Sessions, Active Alerts, Connected Pods, Recent
/// Reports, Recent Team Activity, Quick Actions. Deliberately a different
/// rhythm from Player Home — team-level, not a personal instrument panel.
///
/// Today's Squad, Today's Sessions, Active Alerts, Recent Team Activity,
/// and (added this phase) the live-session entry banner are all genuinely
/// real, aggregated signals — never a fabricated count. Connected Pods and
/// Recent Reports remain honest placeholders: no device-pairing view or
/// reports pipeline exists yet (the same "schema ready, no UI to bind to
/// nothing" reasoning Phase 11's battery-architecture pass used).
///
/// The live-session banner (real, this phase): watches
/// `teams/{teamId}/liveMonitoring` directly and, per
/// DESIGN_SPECIFICATION.md's own flow diagram
/// (`CHome -->|"session is live" banner| LiveMon`), only renders when that
/// collection is genuinely non-empty — pushing `AppRoute.coachLivePath`
/// completes the Hardware -> ... -> Firestore -> Flutter chain.
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
              const SizedBox(height: SpacingTokens.space16),
              const RazDailyBriefCard(workspace: WorkspaceType.coach),
              const SizedBox(height: SpacingTokens.space24),
              _TodaysSquadCard(teamId: teamId),
              const _LiveSessionBanner(),
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
              RecentActivityFeed(
                title: 'Recent Team Activity',
                emptyBody: "This will fill in once your team's training data starts flowing.",
                notificationsAsync: notificationsAsync,
                onViewAll: () => context.push(AppRoute.notificationsPath(WorkspaceType.coach)),
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

/// Only renders when `teams/{teamId}/liveMonitoring` is genuinely
/// non-empty — no banner at all otherwise (loading/error/no-session all
/// collapse to nothing here, the same "render nothing rather than a
/// fabricated state" treatment [notificationsAsync]'s loading/error
/// branches already use above).
class _LiveSessionBanner extends ConsumerWidget {
  const _LiveSessionBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final liveAsync = ref.watch(liveMonitoringControllerProvider);
    final players = liveAsync.value?.fold(onSuccess: (players) => players, onFailure: (_) => null);

    if (players == null || players.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: SpacingTokens.space16),
      child: InkWell(
        onTap: () => context.push(AppRoute.coachLivePath),
        borderRadius: RadiusTokens.mediumRadius,
        child: Container(
          padding: const EdgeInsets.all(SpacingTokens.space16),
          decoration: BoxDecoration(
            color: theme.colorScheme.secondary.withValues(alpha: 0.16),
            borderRadius: RadiusTokens.mediumRadius,
          ),
          child: Row(
            children: [
              Icon(Symbols.sensors, color: theme.colorScheme.secondary),
              const SizedBox(width: SpacingTokens.space12),
              Expanded(
                child: Text(
                  'Session is live — ${players.length} '
                  '${players.length == 1 ? 'player' : 'players'} tracked',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.secondary,
                  ),
                ),
              ),
              Icon(Symbols.chevron_right, color: theme.colorScheme.secondary),
            ],
          ),
        ),
      ),
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
      // Deliberately quiet, not a SectionLoadingState — a secondary
      // section below several other independent async cards on an
      // already-rendered Coach Home screen; see RecentActivityFeed's doc
      // comment for the same reasoning applied here.
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

/// "Create Team" was removed from this row (Phase 15 dead-code pass): it
/// only ever showed a "coming in a future phase" snackbar, and a coach
/// reaching Coach Home always already has a team — onboarding requires
/// creating or joining one before Home is reachable at all.
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
          onPressed: teamId == null ? null : () => showInvitePlayersDialog(context, teamId!),
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
