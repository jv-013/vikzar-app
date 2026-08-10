import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../design_system/components/vikzar_status_chip.dart';
import '../../../../design_system/theme/vikzar_elevation.dart';
import '../../../../design_system/tokens/radius.dart';
import '../../../../design_system/tokens/spacing.dart';
import '../../../../routing/app_router.dart';
import '../../../../shared/models/player_profile.dart';
import '../../../../shared/models/workspace_type.dart';
import '../../../../shared/providers/current_app_user_provider.dart';
import '../../../../shared/widgets/fade_scale_in.dart';
import '../../../../shared/widgets/recent_activity_feed.dart';
import '../../../../shared/widgets/section_empty_state.dart';
import '../../../notifications/domain/models/app_notification.dart';
import '../../../notifications/presentation/controllers/notifications_controller.dart';
import '../../../raz/presentation/widgets/raz_daily_brief_card.dart';
import '../../../sessions/domain/models/planned_session.dart';
import '../../../sessions/presentation/controllers/planned_sessions_controller.dart';

/// Player Home — DESIGN_SPECIFICATION.md §19.2, **rebuilt at Phase 9** to
/// the product's exact section list: Greeting, Today's Status, Pod Status,
/// Next Training, Recent Activity, Insights, Notification Preview. Answers
/// exactly one question — "how am I doing today?" — a football companion,
/// not a dashboard: no stat tiles, no Quick Actions row (Phase 7's design,
/// superseded here).
///
/// Today's Status is the one section with a genuinely real, non-fabricated
/// signal: the player's own `playerProfile.trainingStatus` (DECISIONS.md
/// ADR-059). Pod Status and Next Training remain honest placeholders — no
/// device or scheduling pipeline exists yet. Recent Activity and
/// Notification Preview are both backed by the real (currently
/// near-empty) notification stream (DECISIONS.md ADR-061) — Recent
/// Activity as a timeline of what happened, Notification Preview as a
/// compact "what needs attention" strip, so the same underlying data
/// doesn't simply repeat itself twice on one screen.
class PlayerHomeScreen extends ConsumerWidget {
  const PlayerHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(currentAppUserProvider);
    final name = _firstName(user?.displayName);
    final teamId = user?.workspaces.player?.teamId;
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
              const SizedBox(height: SpacingTokens.space16),
              const RazDailyBriefCard(workspace: WorkspaceType.player),
              const SizedBox(height: SpacingTokens.space24),
              if (teamId == null) ...[
                const _NoTeamCard(),
                const SizedBox(height: SpacingTokens.space16),
              ],
              _TodaysStatusCard(trainingStatus: user?.playerProfile?.trainingStatus),
              const SizedBox(height: SpacingTokens.space16),
              const _PodStatusCard(),
              const SizedBox(height: SpacingTokens.space32),
              Text('Next Training', style: theme.textTheme.titleLarge),
              const SizedBox(height: SpacingTokens.space8),
              _NextTrainingSection(teamId: teamId),
              const SizedBox(height: SpacingTokens.space32),
              RecentActivityFeed(
                title: 'Recent Activity',
                emptyBody: 'This will fill in once your training data starts flowing.',
                notificationsAsync: notificationsAsync,
                onViewAll: () => context.go(AppRoute.playerTimelinePath),
              ),
              const SizedBox(height: SpacingTokens.space32),
              Text('Insights', style: theme.textTheme.titleLarge),
              const SizedBox(height: SpacingTokens.space8),
              const SectionEmptyState(
                icon: Symbols.insights,
                headline: 'Insights will appear once enough training data has '
                    'been collected.',
              ),
              const SizedBox(height: SpacingTokens.space32),
              _NotificationPreview(notificationsAsync: notificationsAsync),
              const SizedBox(height: SpacingTokens.space32),
            ],
          ),
        ),
      ),
    );
  }
}

String _greeting(String? name) {
  final hour = DateTime.now().hour;
  final timeOfDay = switch (hour) {
    >= 5 && < 12 => 'morning',
    >= 12 && < 17 => 'afternoon',
    _ => 'evening',
  };
  return name == null ? 'Good $timeOfDay.' : 'Good $timeOfDay, $name.';
}

String? _firstName(String? displayName) {
  if (displayName == null || displayName.trim().isEmpty) return null;
  return displayName.trim().split(' ').first;
}

class _TodaysStatusCard extends StatelessWidget {
  const _TodaysStatusCard({required this.trainingStatus});

  final TrainingStatus? trainingStatus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final elevation = theme.extension<VikzarElevation>();
    final background = elevation == null
        ? theme.colorScheme.surface
        : Color.alphaBlend(elevation.level1Overlay, theme.colorScheme.surface);

    return Container(
      padding: const EdgeInsets.all(SpacingTokens.space20),
      decoration: BoxDecoration(color: background, borderRadius: RadiusTokens.mediumRadius),
      child: Row(
        children: [
          Icon(Symbols.check_circle, size: 32, color: theme.colorScheme.secondary),
          const SizedBox(width: SpacingTokens.space16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Today's Status", style: theme.textTheme.titleSmall),
                const SizedBox(height: SpacingTokens.space8),
                trainingStatus == null
                    ? Text(
                        'No data yet.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      )
                    : VikzarStatusChip(label: trainingStatus!.label),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Always the honest "not connected" state — no device-pairing pipeline
/// exists yet (`lib/features/devices/` is empty; Part 4's "clearly
/// expect live hardware" placeholders apply here). Was previously
/// parameterized for Demo Session to override; those params had no real
/// caller left once Demo Mode was removed.
class _PodStatusCard extends StatelessWidget {
  const _PodStatusCard();

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
      child: Row(
        children: [
          Icon(Symbols.sensors_off, color: theme.colorScheme.secondary),
          const SizedBox(width: SpacingTokens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Pod Status', style: theme.textTheme.titleSmall),
                const SizedBox(height: SpacingTokens.space4),
                Text(
                  'Disconnected — ask your coach to assign your Pod.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const VikzarStatusChip(label: 'No sync yet'),
        ],
      ),
    );
  }
}

/// Shown when the player has no team yet — the only way onto a team is a
/// coach's invite code (`AppRoute.playerJoinTeamPath`); nothing here is
/// fabricated or auto-assigned.
class _NoTeamCard extends StatelessWidget {
  const _NoTeamCard();

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
      child: Row(
        children: [
          Icon(Symbols.group_off, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: SpacingTokens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('No coach yet', style: theme.textTheme.titleSmall),
                const SizedBox(height: SpacingTokens.space4),
                Text(
                  'Enter an invite code from your coach to join a team.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => context.push(AppRoute.playerJoinTeamPath),
            child: const Text('Join'),
          ),
        ],
      ),
    );
  }
}

/// Real Firestore listener, per Phase 15 — previously a static empty
/// state with no query behind it at all. Shows the soonest upcoming
/// planned session for the player's team, if any.
class _NextTrainingSection extends ConsumerWidget {
  const _NextTrainingSection({required this.teamId});

  final String? teamId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (teamId == null) {
      return const SectionEmptyState(
        icon: Symbols.event,
        headline: 'No training scheduled.',
        body: "Join a team to see your coach's sessions here.",
      );
    }
    final sessionsAsync = ref.watch(upcomingPlannedSessionsProvider(teamId!));
    return sessionsAsync.when(
      // Deliberately quiet, not a SectionLoadingState — a secondary
      // section below several other independent async cards on an
      // already-rendered Home screen; see RecentActivityFeed's doc
      // comment for the same reasoning applied here.
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SectionEmptyState(
        icon: Symbols.error,
        headline: "Couldn't load your next session.",
      ),
      data: (result) => result.fold(
        onSuccess: (sessions) {
          if (sessions.isEmpty) {
            return const SectionEmptyState(
              icon: Symbols.event,
              headline: 'No training scheduled.',
              body: "Your coach's next session will appear here once it's set.",
            );
          }
          final next = sessions.first;
          return _NextTrainingCard(session: next);
        },
        onFailure: (_) => const SectionEmptyState(
          icon: Symbols.error,
          headline: "Couldn't load your next session.",
        ),
      ),
    );
  }
}

class _NextTrainingCard extends StatelessWidget {
  const _NextTrainingCard({required this.session});

  final PlannedSession session;

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
      child: Row(
        children: [
          Icon(
            session.type == PlannedSessionType.match
                ? Symbols.sports_soccer
                : Symbols.fitness_center,
            color: theme.colorScheme.secondary,
          ),
          const SizedBox(width: SpacingTokens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(session.title, style: theme.textTheme.titleSmall),
                const SizedBox(height: SpacingTokens.space4),
                Text(
                  _formatDateTime(session.scheduledAt),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (session.location != null && session.location!.trim().isNotEmpty)
                  Text(
                    session.location!,
                    style: theme.textTheme.bodySmall?.copyWith(
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

String _formatDateTime(DateTime dateTime) {
  final hour = dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12;
  final minute = dateTime.minute.toString().padLeft(2, '0');
  final period = dateTime.hour < 12 ? 'AM' : 'PM';
  return '${dateTime.month}/${dateTime.day}/${dateTime.year} $hour:$minute $period';
}

class _NotificationPreview extends StatelessWidget {
  const _NotificationPreview({required this.notificationsAsync});

  final AsyncValue<List<AppNotification>> notificationsAsync;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final notifications = notificationsAsync.value ?? const <AppNotification>[];
    final unreadCount = notifications.where((n) => !n.read).length;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(Symbols.notifications, size: 20, color: theme.colorScheme.secondary),
            const SizedBox(width: SpacingTokens.space8),
            Text(
              unreadCount == 0
                  ? "You're all caught up."
                  : '$unreadCount unread notification${unreadCount == 1 ? '' : 's'}.',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
        TextButton(
          onPressed: () => context.push(AppRoute.notificationsPath(WorkspaceType.player)),
          child: const Text('View All'),
        ),
      ],
    );
  }
}
