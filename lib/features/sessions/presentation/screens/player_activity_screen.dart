import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../design_system/tokens/spacing.dart';
import '../../../../shared/widgets/fade_scale_in.dart';
import '../../../../shared/widgets/notification_timeline_card.dart';
import '../../../../shared/widgets/section_empty_state.dart';
import '../../../notifications/presentation/controllers/notifications_controller.dart';

/// Player Activity — DESIGN_SPECIFICATION.md §14/§19.2's "Timeline"
/// destination, **rebuilt at Phase 9** as the player's full football
/// history: training, sessions, syncs, coach updates, and AI insights, in
/// one chronological feed. Not statistics — a history.
///
/// Backed entirely by the real `NotificationRepository` stream
/// (DECISIONS.md ADR-061) — there is no dedicated "activity" collection in
/// BACKEND_SPECIFICATION.md, and none is invented here. Every event shown
/// is a genuine notification record; nothing is fabricated to make the
/// timeline feel more populated than it is. The empty state says so
/// honestly: data appears once the laptop ETL/ML pipeline starts producing
/// it, not "no training sessions yet," which would misrepresent what this
/// screen actually reads.
class PlayerActivityScreen extends ConsumerWidget {
  const PlayerActivityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final notificationsAsync = ref.watch(notificationsControllerProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Activity')),
      body: SafeArea(
        child: FadeScaleIn(
          child: notificationsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => const Center(
              child: SectionEmptyState(
                icon: Symbols.error,
                headline: "Couldn't load your activity.",
                body: 'Please try again.',
              ),
            ),
            data: (notifications) {
              if (notifications.isEmpty) {
                return const Center(
                  child: SectionEmptyState(
                    icon: Symbols.timeline,
                    headline: 'No activity yet.',
                    body:
                        'Training, sessions, and coach updates will appear here once '
                        'your training data starts flowing.',
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(SpacingTokens.space16),
                itemCount: notifications.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: SpacingTokens.space12),
                itemBuilder: (context, index) =>
                    NotificationTimelineCard(notification: notifications[index]),
              );
            },
          ),
        ),
      ),
    );
  }
}
