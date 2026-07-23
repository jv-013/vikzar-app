import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../design_system/components/vikzar_status_chip.dart';
import '../../design_system/theme/vikzar_elevation.dart';
import '../../design_system/tokens/radius.dart';
import '../../design_system/tokens/spacing.dart';
import '../../features/notifications/domain/models/app_notification.dart';

/// A single entry in an activity timeline — DESIGN_SPECIFICATION.md §18's
/// Timeline Card (timestamp, event type label, severity/category chip),
/// reused by Player Home's Recent Activity, Player Activity (the full
/// timeline), and Coach Home's Recent Team Activity.
///
/// **Added at Phase 9.** Backed entirely by [AppNotification] — the only
/// real, already-secured, already-Firestore-backed signal that matches the
/// event types this phase's brief describes (training/session/coach/AI
/// events), per DECISIONS.md's Phase 9 activity-feed reuse ADR. Never
/// fabricates a football-specific event type that isn't genuinely one of
/// [NotificationCategory]'s real values.
///
/// Deliberately a **different visual treatment from Notification Center's**
/// read/unread row (`_NotificationRow` in `notification_center_screen.dart`)
/// — a self-contained card, not a flat list row, so the two surfaces don't
/// read as the same screen twice.
class NotificationTimelineCard extends StatelessWidget {
  const NotificationTimelineCard({super.key, required this.notification});

  final AppNotification notification;

  IconData get _icon => switch (notification.category) {
    NotificationCategory.alert => Symbols.warning,
    NotificationCategory.reportReady => Symbols.description,
    NotificationCategory.sessionSummary => Symbols.timer,
    NotificationCategory.teamInvite => Symbols.groups,
    NotificationCategory.sessionScheduled => Symbols.event,
    NotificationCategory.system => Symbols.info,
  };

  String get _categoryLabel => switch (notification.category) {
    NotificationCategory.alert => 'Alert',
    NotificationCategory.reportReady => 'Report',
    NotificationCategory.sessionSummary => 'Session',
    NotificationCategory.teamInvite => 'Team',
    NotificationCategory.sessionScheduled => 'Scheduled',
    NotificationCategory.system => 'System',
  };

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_icon, size: 20, color: theme.colorScheme.secondary),
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
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: SpacingTokens.space8),
                Row(
                  children: [
                    VikzarStatusChip(label: _categoryLabel),
                    const SizedBox(width: SpacingTokens.space8),
                    Text(
                      relativeTime(notification.timestamp),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Shared relative-time formatter — matches
/// `notification_center_screen.dart`'s own `_relativeTime`, extracted here
/// so both surfaces render identical wording for identical data rather than
/// two independently-maintained implementations drifting apart.
String relativeTime(DateTime timestamp) {
  final difference = DateTime.now().difference(timestamp);
  if (difference.inMinutes < 1) return 'Just now';
  if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
  if (difference.inHours < 24) return '${difference.inHours}h ago';
  return '${difference.inDays}d ago';
}
