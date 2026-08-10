import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../design_system/components/vikzar_status_chip.dart';
import '../../../../design_system/theme/brand_colors.dart';
import '../../../../design_system/theme/vikzar_elevation.dart';
import '../../../../design_system/tokens/radius.dart';
import '../../../../design_system/tokens/spacing.dart';
import '../../../../routing/app_router.dart';
import '../../../../shared/models/workspace_type.dart';
import '../../../../shared/widgets/fade_scale_in.dart';
import '../../../../shared/widgets/section_empty_state.dart';
import '../../domain/models/live_player_metrics.dart';
import '../controllers/live_monitoring_controller.dart';

/// Live Team Monitoring — DESIGN_SPECIFICATION.md §19.3/§21, fills
/// `AppRoute.coachLivePath`. Reads `teams/{teamId}/liveMonitoring`
/// (§1.4) directly — no fabricated/sample data anywhere on this screen;
/// an empty collection means no session is live right now, shown as the
/// exact §19.4 empty state, not an error.
///
/// Dropped as a standalone bottom-nav tab at Phase 13 (it was 100%
/// placeholder then — DECISIONS.md line ~763) and reached instead from a
/// "session is live" card on the Coach Dashboard, per
/// DESIGN_SPECIFICATION.md's own flow diagram
/// (`CHome -->|"session is live" banner| LiveMon`) — this screen itself
/// is unchanged by that navigation decision, only how it's reached.
///
/// Deliberately deferred from the full §19.3 spec, to keep this the
/// minimum real UI needed to prove Hardware -> ... -> Firestore -> Flutter
/// end-to-end, not the full richness of that section: the persistent
/// Critical alert banner (a separate cross-cutting concern already
/// partly covered by the Alerts feature) and per-card live-region
/// accessibility announcements are not built here.
class LiveTeamMonitoringScreen extends ConsumerWidget {
  const LiveTeamMonitoringScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final liveAsync = ref.watch(liveMonitoringControllerProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Live Team Monitoring')),
      body: SafeArea(
        child: FadeScaleIn(
          child: liveAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SectionEmptyState(
              icon: Symbols.error,
              headline: "Couldn't load live monitoring.",
              body: 'Check your connection and try again.',
            ),
            data: (result) => result.fold(
              onSuccess: (players) {
                if (players.isEmpty) {
                  return Center(
                    child: SectionEmptyState(
                      icon: Symbols.sensors,
                      headline: 'Start a training session from your '
                          "team's laptop to see live data here.",
                      actionLabel: 'Back to Home',
                      onAction: () => context.go(AppRoute.homePath(WorkspaceType.coach)),
                    ),
                  );
                }
                final sorted = [...players]..sort(_byRiskThenLoad);
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = _columnsFor(constraints.maxWidth);
                    return GridView.builder(
                      padding: const EdgeInsets.all(SpacingTokens.space16),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        mainAxisSpacing: SpacingTokens.space12,
                        crossAxisSpacing: SpacingTokens.space12,
                        childAspectRatio: 1.3,
                      ),
                      itemCount: sorted.length,
                      itemBuilder: (context, index) => _PlayerLiveCard(player: sorted[index]),
                    );
                  },
                );
              },
              onFailure: (_) => const SectionEmptyState(
                icon: Symbols.error,
                headline: "Couldn't load live monitoring.",
                body: 'Check your connection and try again.',
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// DESIGN_SPECIFICATION.md §7's Compact/Medium/Expanded breakpoints,
/// §21's "1 column / 2 columns / 3-4 columns" Live Team Monitoring row.
int _columnsFor(double width) {
  if (width < 600) return 1;
  if (width < 840) return 2;
  if (width < 1200) return 3;
  return 4;
}

int _riskSeverity(LiveRiskLevel level) => switch (level) {
  LiveRiskLevel.low => 0,
  LiveRiskLevel.moderate => 1,
  LiveRiskLevel.high => 2,
  LiveRiskLevel.critical => 3,
};

/// "Cards for players in Elevated/High/Critical states sort to the top
/// of the grid automatically" — DESIGN_SPECIFICATION.md §19.3.
int _byRiskThenLoad(LivePlayerMetrics a, LivePlayerMetrics b) {
  final severity = _riskSeverity(b.currentRiskLevel).compareTo(_riskSeverity(a.currentRiskLevel));
  if (severity != 0) return severity;
  return b.currentLoad.compareTo(a.currentLoad);
}

Color _riskColor(BuildContext context, LiveRiskLevel level) {
  final colorScheme = Theme.of(context).colorScheme;
  return switch (level) {
    LiveRiskLevel.low => colorScheme.secondary,
    LiveRiskLevel.moderate => colorScheme.primary,
    LiveRiskLevel.high => colorScheme.primary,
    LiveRiskLevel.critical => BrandColors.alertCrimson,
  };
}

String _riskLabel(LiveRiskLevel level) => switch (level) {
  LiveRiskLevel.low => 'Normal',
  LiveRiskLevel.moderate => 'Elevated',
  LiveRiskLevel.high => 'High',
  LiveRiskLevel.critical => 'Critical',
};

Color _connectionColor(BuildContext context, LiveConnectionStatus status) {
  final colorScheme = Theme.of(context).colorScheme;
  return switch (status) {
    LiveConnectionStatus.connected => colorScheme.secondary,
    LiveConnectionStatus.degraded => colorScheme.primary,
    LiveConnectionStatus.disconnected => colorScheme.onSurfaceVariant,
  };
}

class _PlayerLiveCard extends StatelessWidget {
  const _PlayerLiveCard({required this.player});

  final LivePlayerMetrics player;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final elevation = theme.extension<VikzarElevation>();
    final background = elevation == null
        ? theme.colorScheme.surface
        : Color.alphaBlend(elevation.level1Overlay, theme.colorScheme.surface);
    final isElevatedOrAbove = _riskSeverity(player.currentRiskLevel) >= 1;
    final riskColor = _riskColor(context, player.currentRiskLevel);
    final battery = player.lowestBattery;

    return Container(
      padding: const EdgeInsets.all(SpacingTokens.space16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: RadiusTokens.mediumRadius,
        border: isElevatedOrAbove ? Border.all(color: riskColor, width: 1.5) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.12),
                child: Icon(Symbols.person, size: 18, color: theme.colorScheme.onSurface),
              ),
              const SizedBox(width: SpacingTokens.space8),
              Expanded(
                child: Text(
                  player.displayName.isEmpty ? 'Player' : player.displayName,
                  style: theme.textTheme.titleSmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _ConnectionDot(color: _connectionColor(context, player.connectionStatus)),
            ],
          ),
          const SizedBox(height: SpacingTokens.space12),
          VikzarStatusChip(label: _riskLabel(player.currentRiskLevel), color: riskColor),
          const Spacer(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      player.currentLoad.toStringAsFixed(0),
                      style: theme.textTheme.headlineLarge?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    Text(
                      'Load',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (battery != null)
                Row(
                  children: [
                    Icon(
                      battery <= 20 ? Symbols.battery_alert : Symbols.battery_full,
                      size: 16,
                      color: battery <= 20
                          ? BrandColors.alertCrimson
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: SpacingTokens.space4),
                    Text(
                      '$battery%',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ConnectionDot extends StatelessWidget {
  const _ConnectionDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}
