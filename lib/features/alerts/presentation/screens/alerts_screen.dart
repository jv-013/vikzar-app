import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/errors/failure_message_mapper.dart';
import '../../../../design_system/components/vikzar_chip_group.dart';
import '../../../../design_system/theme/brand_colors.dart';
import '../../../../design_system/theme/vikzar_elevation.dart';
import '../../../../design_system/tokens/radius.dart';
import '../../../../design_system/tokens/spacing.dart';
import '../../../../shared/providers/current_uid_provider.dart';
import '../../../../shared/widgets/fade_scale_in.dart';
import '../../../../shared/widgets/notification_timeline_card.dart' show relativeTime;
import '../../../../shared/widgets/section_empty_state.dart';
import '../../data/repositories/alert_repository_impl.dart';
import '../../domain/models/alert.dart';
import '../controllers/alerts_controller.dart';

enum _AlertFilter { all, unacknowledged }

/// Alerts — DESIGN_SPECIFICATION.md §19.3/§19.4, **new at Phase 9**, fills
/// `/coach/alerts` (previously a shared `ComingSoonScreen`). The `alerts`
/// collection, its Security Rules, and its composite index all already
/// existed and were already unused — this is completing the product, not
/// new backend scope. Genuinely empty today (alert creation is Cloud
/// Function-only and no Risk Engine pipeline exists yet), so the exact
/// DESIGN_SPECIFICATION.md §19.4 empty-state copy is the honest, real
/// state for every team right now.
class AlertsScreen extends ConsumerStatefulWidget {
  const AlertsScreen({super.key});

  @override
  ConsumerState<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends ConsumerState<AlertsScreen> {
  _AlertFilter _filter = _AlertFilter.all;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final alertsAsync = ref.watch(alertsControllerProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Alerts')),
      body: SafeArea(
        child: FadeScaleIn(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(SpacingTokens.space16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: VikzarChipGroup<_AlertFilter>(
                    options: _AlertFilter.values,
                    labelBuilder: (filter) => switch (filter) {
                      _AlertFilter.all => 'All',
                      _AlertFilter.unacknowledged => 'Unacknowledged',
                    },
                    selected: {_filter},
                    onChanged: (selected) => setState(() => _filter = selected.first),
                    multiSelect: false,
                  ),
                ),
              ),
              Expanded(
                child: alertsAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SectionEmptyState(
                    icon: Symbols.error,
                    headline: "Couldn't load alerts.",
                    body: 'Check your connection and try again.',
                  ),
                  data: (result) => result.fold(
                    onSuccess: (alerts) {
                      final filtered = _filter == _AlertFilter.all
                          ? alerts
                          : alerts.where((a) => !a.acknowledged).toList();

                      if (filtered.isEmpty) {
                        return const SectionEmptyState(
                          icon: Symbols.shield,
                          headline: 'No alerts. Your team is clear.',
                        );
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: SpacingTokens.space16),
                        itemCount: filtered.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: SpacingTokens.space12),
                        itemBuilder: (context, index) => _AlertCard(alert: filtered[index]),
                      );
                    },
                    onFailure: (_) => const SectionEmptyState(
                      icon: Symbols.error,
                      headline: "Couldn't load alerts.",
                      body: 'Check your connection and try again.',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: SpacingTokens.space16),
            ],
          ),
        ),
      ),
    );
  }
}

Color _severityColor(BuildContext context, AlertSeverity severity) {
  final colorScheme = Theme.of(context).colorScheme;
  return switch (severity) {
    AlertSeverity.info => colorScheme.secondary,
    AlertSeverity.warning => colorScheme.primary,
    AlertSeverity.critical => BrandColors.alertCrimson,
  };
}

String _severityLabel(AlertSeverity severity) => switch (severity) {
  AlertSeverity.info => 'Info',
  AlertSeverity.warning => 'Warning',
  AlertSeverity.critical => 'Critical',
};

class _AlertCard extends ConsumerWidget {
  const _AlertCard({required this.alert});

  final Alert alert;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final elevation = theme.extension<VikzarElevation>();
    final background = elevation == null
        ? theme.colorScheme.surface
        : Color.alphaBlend(elevation.level1Overlay, theme.colorScheme.surface);
    final color = _severityColor(context, alert.severity);

    return InkWell(
      borderRadius: RadiusTokens.mediumRadius,
      onTap: alert.acknowledged ? null : () => _confirmAcknowledge(context, ref, alert),
      child: Container(
        padding: const EdgeInsets.all(SpacingTokens.space16),
        decoration: BoxDecoration(color: background, borderRadius: RadiusTokens.mediumRadius),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(top: 6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: alert.acknowledged ? Colors.transparent : color,
                border: Border.all(color: color),
              ),
            ),
            const SizedBox(width: SpacingTokens.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        _severityLabel(alert.severity),
                        style: theme.textTheme.labelMedium?.copyWith(color: color),
                      ),
                      const Spacer(),
                      Text(
                        relativeTime(alert.triggeredAt),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: SpacingTokens.space4),
                  Text(alert.message, style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void _confirmAcknowledge(BuildContext context, WidgetRef ref, Alert alert) {
  showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Acknowledge alert'),
        content: Text(alert.message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            // Phase 13 §16 fix: this was previously fired without
            // `await` and the dialog closed unconditionally — any
            // failure (a Firestore write denial, network loss) was
            // silently discarded, and the UI lied by showing success
            // regardless. Now awaits the real result and only closes on
            // success; a failure surfaces via a SnackBar and the dialog
            // stays open so the coach can retry.
            onPressed: () async {
              final coachUid = ref.read(currentUidProvider);
              if (coachUid == null) {
                Navigator.of(dialogContext).pop();
                return;
              }
              final result = await ref
                  .read(alertRepositoryProvider)
                  .acknowledgeAlert(alertId: alert.alertId, coachUid: coachUid);
              if (!dialogContext.mounted) return;
              result.fold(
                onSuccess: (_) => Navigator.of(dialogContext).pop(),
                onFailure: (failure) {
                  Navigator.of(dialogContext).pop();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(FailureMessageMapper.toMessage(failure))),
                  );
                },
              );
            },
            child: const Text('Acknowledge'),
          ),
        ],
      );
    },
  );
}
