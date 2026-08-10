import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../design_system/components/vikzar_bottom_sheet.dart';
import '../../../../design_system/theme/vikzar_elevation.dart';
import '../../../../design_system/tokens/radius.dart';
import '../../../../design_system/tokens/spacing.dart';
import '../../../../shared/widgets/fade_scale_in.dart';
import '../../../../shared/widgets/section_empty_state.dart';
import '../../../../shared/widgets/section_loading_state.dart';
import '../../../team/presentation/controllers/team_roster_controller.dart';
import '../../domain/models/planned_session.dart';
import '../controllers/planned_sessions_controller.dart';
import '../widgets/create_planned_session_sheet.dart';

/// Coach "Sessions" — Phase 13 §5. Upcoming sessions are genuinely real
/// (`plannedSessions`, created via `createPlannedSession`); session
/// *history* remains an honest empty state, since it would read from
/// `sessions/{sessionId}` (real hardware captures), which requires
/// physical Pods/EMG bands that don't exist yet — building history UI
/// bound to a collection nothing writes to would be dead UI, not
/// readiness (the same reasoning Phase 11's battery-architecture pass
/// used).
class CoachSessionsScreen extends ConsumerWidget {
  const CoachSessionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final teamId = ref.watch(coachTeamIdProvider);

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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Sessions', style: theme.textTheme.headlineLarge),
                  FilledButton.icon(
                    onPressed: teamId == null ? null : () => _showCreateSheet(context, teamId),
                    icon: const Icon(Symbols.add),
                    label: const Text('Create'),
                  ),
                ],
              ),
              const SizedBox(height: SpacingTokens.space24),
              Text('Upcoming Sessions', style: theme.textTheme.titleLarge),
              const SizedBox(height: SpacingTokens.space8),
              if (teamId == null)
                const SectionEmptyState(
                  icon: Symbols.event_busy,
                  headline: 'Create a team first.',
                  body: 'Once you have a team, you can schedule sessions for it.',
                )
              else
                _UpcomingSessions(teamId: teamId),
              const SizedBox(height: SpacingTokens.space32),
              Text('Session History', style: theme.textTheme.titleLarge),
              const SizedBox(height: SpacingTokens.space8),
              const SectionEmptyState(
                icon: Symbols.history,
                headline: 'No recorded sessions yet.',
                body: 'Session history appears here once real hardware has captured a '
                    "session — this isn't wired to any device yet.",
              ),
              const SizedBox(height: SpacingTokens.space32),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateSheet(BuildContext context, String teamId) {
    VikzarBottomSheet.show<bool>(
      context,
      builder: (context) => CreatePlannedSessionSheet(teamId: teamId),
    );
  }
}

class _UpcomingSessions extends ConsumerWidget {
  const _UpcomingSessions({required this.teamId});

  final String teamId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(upcomingPlannedSessionsProvider(teamId));

    return sessionsAsync.when(
      loading: () => const SectionLoadingState(),
      error: (_, _) => const SectionEmptyState(
        icon: Symbols.error,
        headline: "Couldn't load upcoming sessions.",
      ),
      data: (result) => result.fold(
        onSuccess: (sessions) {
          if (sessions.isEmpty) {
            return const SectionEmptyState(
              icon: Symbols.event_available,
              headline: 'No sessions scheduled.',
              body: 'Tap Create to schedule your team\'s next session.',
            );
          }
          return Column(
            children: [
              for (final session in sessions) ...[
                _PlannedSessionCard(session: session),
                const SizedBox(height: SpacingTokens.space12),
              ],
            ],
          );
        },
        onFailure: (_) => const SectionEmptyState(
          icon: Symbols.error,
          headline: "Couldn't load upcoming sessions.",
        ),
      ),
    );
  }
}

class _PlannedSessionCard extends StatelessWidget {
  const _PlannedSessionCard({required this.session});

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
            session.type == PlannedSessionType.match ? Symbols.sports_soccer : Symbols.fitness_center,
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
