import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../design_system/tokens/spacing.dart';
import '../../../../shared/widgets/notification_timeline_card.dart' show relativeTime;
import '../../../../shared/widgets/section_empty_state.dart';
import '../../domain/models/app_notification.dart';
import '../controllers/notifications_controller.dart';

/// Notification Center — DESIGN_SPECIFICATION.md §16 row 25. Supports
/// Empty, Loading, and Populated states, per Phase 7's explicit
/// requirement. Genuinely Cloud-Function-backed since Phase 13/15/19
/// (ADR-067) — this streams real `users/{uid}/notifications` with no
/// mock/seed data; the empty state shown to a fresh account is a real
/// empty collection, not a placeholder standing in for a missing backend.
class NotificationCenterScreen extends ConsumerWidget {
  const NotificationCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final notificationsAsync = ref.watch(notificationsControllerProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: () =>
                ref.read(notificationsControllerProvider.notifier).markAllAsRead(),
            child: const Text('Mark all as read'),
          ),
        ],
      ),
      body: notificationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => const SectionEmptyState(
          icon: Symbols.error,
          headline: "Couldn't load notifications.",
          body: 'Please try again.',
        ),
        data: (notifications) {
          if (notifications.isEmpty) {
            return const Center(
              child: SectionEmptyState(
                icon: Symbols.notifications_off,
                headline: 'No notifications yet.',
                body: "You're all caught up.",
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: SpacingTokens.space8),
            itemCount: notifications.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return _NotificationRow(
                notification: notification,
                onTap: () => ref
                    .read(notificationsControllerProvider.notifier)
                    .markAsRead(notification.id),
              );
            },
          );
        },
      ),
    );
  }
}

/// RAZ's five notification categories (`razNotificationEngine.ts`'s
/// `RazNotificationCategory`) mapped to an icon — shown when present,
/// falling back to [_iconForCategory] (the coarser, always-present
/// structural type) otherwise. A RAZ category exists only for
/// alert/report-sourced notifications; every other notification shows
/// its structural-type icon instead.
IconData _iconForRazCategory(String razCategory) => switch (razCategory) {
  'recovery' => Symbols.spa,
  'coach' => Symbols.groups,
  'session' => Symbols.event_available,
  'hardware' => Symbols.sensors,
  'movement' => Symbols.directions_run,
  _ => Symbols.notifications,
};

IconData _iconForCategory(NotificationCategory category) => switch (category) {
  NotificationCategory.alert => Symbols.warning,
  NotificationCategory.reportReady => Symbols.description,
  NotificationCategory.sessionSummary => Symbols.event_available,
  NotificationCategory.teamInvite => Symbols.group_add,
  NotificationCategory.sessionScheduled => Symbols.event,
  NotificationCategory.system => Symbols.notifications,
};

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final icon = notification.razCategory != null
        ? _iconForRazCategory(notification.razCategory!)
        : _iconForCategory(notification.category);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: SpacingTokens.space16,
          vertical: SpacingTokens.space12,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: colorScheme.secondary),
            const SizedBox(width: SpacingTokens.space12),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: notification.read ? Colors.transparent : colorScheme.primary,
                  border: notification.read
                      ? Border.all(color: colorScheme.onSurfaceVariant)
                      : null,
                ),
              ),
            ),
            const SizedBox(width: SpacingTokens.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(notification.title, style: theme.textTheme.titleSmall),
                  const SizedBox(height: SpacingTokens.space4),
                  Text(
                    notification.body,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: SpacingTokens.space4),
                  Text(
                    relativeTime(notification.timestamp),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
