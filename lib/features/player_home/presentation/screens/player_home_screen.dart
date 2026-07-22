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
import '../../../../shared/widgets/notification_timeline_card.dart';
import '../../../../shared/widgets/section_empty_state.dart';
import '../../../notifications/domain/models/app_notification.dart';
import '../../../notifications/presentation/controllers/notifications_controller.dart';

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
              const SizedBox(height: SpacingTokens.space24),
              _TodaysStatusCard(trainingStatus: user?.playerProfile?.trainingStatus),
              const SizedBox(height: SpacingTokens.space16),
              const _PodStatusCard(),
              const SizedBox(height: SpacingTokens.space32),
              Text('Next Training', style: theme.textTheme.titleLarge),
              const SizedBox(height: SpacingTokens.space8),
              const SectionEmptyState(
                icon: Symbols.event,
                headline: 'No training scheduled.',
                body: "Your coach's next session will appear here once it's set.",
              ),
              const SizedBox(height: SpacingTokens.space32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Recent Activity', style: theme.textTheme.titleLarge),
                  TextButton(
                    onPressed: () => context.go(AppRoute.playerTimelinePath),
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
                      body:
                          "This will fill in once your training data starts flowing.",
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
