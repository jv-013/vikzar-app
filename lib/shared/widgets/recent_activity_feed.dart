import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../design_system/tokens/spacing.dart';
import '../../features/notifications/domain/models/app_notification.dart';
import 'notification_timeline_card.dart';
import 'section_empty_state.dart';

/// A section header + up-to-2-most-recent-notifications strip, shared by
/// Player Home's "Recent Activity" and Coach Home's "Recent Team
/// Activity" — the two were byte-identical apart from their title, empty
/// -state copy, and "View All" destination before this was extracted.
///
/// Deliberately quiet (renders nothing) on loading/error, matching the
/// existing convention for a secondary section embedded in an
/// already-populated dashboard: a spinner here would mean several
/// independent async sections flashing loading indicators across one
/// screen at once, which is worse than briefly showing nothing.
class RecentActivityFeed extends StatelessWidget {
  const RecentActivityFeed({
    super.key,
    required this.title,
    required this.emptyBody,
    required this.notificationsAsync,
    required this.onViewAll,
  });

  final String title;
  final String emptyBody;
  final AsyncValue<List<AppNotification>> notificationsAsync;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: theme.textTheme.titleLarge),
            TextButton(onPressed: onViewAll, child: const Text('View All')),
          ],
        ),
        const SizedBox(height: SpacingTokens.space8),
        notificationsAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
          data: (notifications) {
            if (notifications.isEmpty) {
              return SectionEmptyState(
                icon: Symbols.timeline,
                headline: 'No activity yet.',
                body: emptyBody,
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
      ],
    );
  }
}
