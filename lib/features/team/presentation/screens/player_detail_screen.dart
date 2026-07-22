import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../design_system/components/vikzar_list_row.dart';
import '../../../../design_system/components/vikzar_section_header.dart';
import '../../../../design_system/components/vikzar_status_chip.dart';
import '../../../../design_system/tokens/spacing.dart';
import '../../../../shared/models/app_user.dart';
import '../../../../shared/models/player_profile.dart';
import '../../../../shared/repositories/user_repository_impl.dart';
import '../../../../shared/widgets/fade_scale_in.dart';
import '../../../../shared/widgets/section_empty_state.dart';

/// Player Detail — DESIGN_SPECIFICATION.md §21, **new at Phase 9**, pushed
/// from the Team screen. A coach-facing, read-only view of one player:
/// Training Status (real, plus conditional injury detail — same signal
/// and same "only when relevant" rule as the player's own Profile),
/// Latest Session, Recent Activity, Future AI, and Coach Notes, all
/// honest empty states — no session pipeline, no cross-player notification
/// read (Security Rules scope `users/{uid}/notifications` to self-only —
/// a coach genuinely cannot read another account's notifications), no AI
/// pipeline, and no `coachNotes` schema field exist yet. **No fake AI**:
/// Future AI shows the same non-committal placeholder copy as Player
/// Home's Insights, never an invented number or verdict.
class PlayerDetailScreen extends ConsumerWidget {
  const PlayerDetailScreen({super.key, required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final userAsync = ref.watch(watchUserProvider(uid));

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Player')),
      body: SafeArea(
        child: FadeScaleIn(
          child: userAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => const SectionEmptyState(
              icon: Symbols.error,
              headline: "Couldn't load this player.",
              body: 'Check your connection and try again.',
            ),
            data: (result) => result.fold(
              onSuccess: (user) {
                if (user == null) {
                  return const SectionEmptyState(
                    icon: Symbols.person_off,
                    headline: 'Player not found.',
                  );
                }
                return _PlayerDetailBody(user: user);
              },
              onFailure: (_) => const SectionEmptyState(
                icon: Symbols.error,
                headline: "Couldn't load this player.",
                body: 'Check your connection and try again.',
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayerDetailBody extends StatelessWidget {
  const _PlayerDetailBody({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = user.playerProfile ?? const PlayerProfile();
    final name = (user.displayName ?? '').trim();
    final showInjuryDetail =
        profile.trainingStatus != null && profile.trainingStatus != TrainingStatus.fullyAvailable;

    return ListView(
      children: [
        const SizedBox(height: SpacingTokens.space16),
        Center(
          child: Column(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.12),
                child: Icon(Symbols.person, size: 40, color: theme.colorScheme.onSurface),
              ),
              const SizedBox(height: SpacingTokens.space12),
              Text(name.isEmpty ? 'Player' : name, style: theme.textTheme.titleLarge),
              if (profile.position != null) ...[
                const SizedBox(height: SpacingTokens.space4),
                Text(
                  profile.position!.label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        const VikzarSectionHeader('Training Status'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: SpacingTokens.space16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: profile.trainingStatus == null
                ? Text(
                    'Not set',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  )
                : VikzarStatusChip(label: profile.trainingStatus!.label),
          ),
        ),
        if (showInjuryDetail) ...[
          const SizedBox(height: SpacingTokens.space16),
          const VikzarSectionHeader('Injury Detail'),
          VikzarListRow(
            title: 'Type',
            subtitle: profile.injuryTypes.isEmpty
                ? 'Not set'
                : profile.injuryTypes.map((t) => t.label).join(', '),
          ),
          VikzarListRow(
            title: 'Expected recovery',
            subtitle: profile.recoveryTimeframe?.label ?? 'Not set',
          ),
        ],
        const VikzarSectionHeader('Latest Session'),
        const SectionEmptyState(
          icon: Symbols.event,
          headline: 'No sessions yet.',
          body: 'This will fill in once training data starts flowing.',
        ),
        const VikzarSectionHeader('Recent Activity'),
        const SectionEmptyState(
          icon: Symbols.timeline,
          headline: 'No activity yet.',
        ),
        const VikzarSectionHeader('Future AI'),
        const SectionEmptyState(
          icon: Symbols.insights,
          headline: 'Insights will appear once enough training data has been collected.',
        ),
        const VikzarSectionHeader('Coach Notes'),
        const SectionEmptyState(
          icon: Symbols.edit_note,
          headline: 'No notes yet.',
        ),
        const SizedBox(height: SpacingTokens.space32),
      ],
    );
  }
}
