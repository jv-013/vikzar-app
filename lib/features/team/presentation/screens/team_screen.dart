import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../design_system/components/vikzar_chip_group.dart';
import '../../../../design_system/components/vikzar_list_row.dart';
import '../../../../design_system/components/vikzar_section_header.dart';
import '../../../../design_system/components/vikzar_status_chip.dart';
import '../../../../design_system/components/vikzar_text_field.dart';
import '../../../../design_system/tokens/spacing.dart';
import '../../../../routing/app_router.dart';
import '../../../../shared/models/player_profile.dart';
import '../../../../shared/widgets/fade_scale_in.dart';
import '../../../../shared/widgets/section_empty_state.dart';
import '../controllers/team_roster_controller.dart';

const _positionOrder = [
  PlayingPosition.goalkeeper,
  PlayingPosition.defender,
  PlayingPosition.midfielder,
  PlayingPosition.forward,
];

const _positionGroupLabels = {
  PlayingPosition.goalkeeper: 'Goalkeepers',
  PlayingPosition.defender: 'Defenders',
  PlayingPosition.midfielder: 'Midfielders',
  PlayingPosition.forward: 'Forwards',
};

/// Team — DESIGN_SPECIFICATION.md §19.3, **new at Phase 9**, fills
/// `/coach/team` (previously a shared `ComingSoonScreen`). Search, a
/// Training Status filter, and a roster grouped by position — real data
/// via [teamRosterEntriesProvider], never fabricated. Every honest empty
/// state here reflects a genuine, currently-real gap: no player-facing
/// "join a team" flow exists yet (only coaches create/join teams during
/// onboarding — DECISIONS.md notes this as a known, out-of-scope-this-phase
/// limitation), so a real roster stays empty until that exists.
class TeamScreen extends ConsumerStatefulWidget {
  const TeamScreen({super.key});

  @override
  ConsumerState<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends ConsumerState<TeamScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  TrainingStatus? _statusFilter;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final teamId = ref.watch(coachTeamIdProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Team')),
      body: SafeArea(
        child: teamId == null
            ? const FadeScaleIn(
                child: SectionEmptyState(
                  icon: Symbols.group_off,
                  headline: 'No team yet.',
                  body: 'Create or join a team to see your roster here.',
                ),
              )
            : _RosterView(
                teamId: teamId,
                searchController: _searchController,
                query: _query,
                onQueryChanged: (value) => setState(() => _query = value),
                statusFilter: _statusFilter,
                onStatusFilterChanged: (value) => setState(() => _statusFilter = value),
              ),
      ),
    );
  }
}

class _RosterView extends ConsumerWidget {
  const _RosterView({
    required this.teamId,
    required this.searchController,
    required this.query,
    required this.onQueryChanged,
    required this.statusFilter,
    required this.onStatusFilterChanged,
  });

  final String teamId;
  final TextEditingController searchController;
  final String query;
  final ValueChanged<String> onQueryChanged;
  final TrainingStatus? statusFilter;
  final ValueChanged<TrainingStatus?> onStatusFilterChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(teamRosterEntriesProvider(teamId));

    return FadeScaleIn(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              SpacingTokens.space16,
              SpacingTokens.space16,
              SpacingTokens.space16,
              SpacingTokens.space8,
            ),
            child: VikzarTextField(
              label: 'Search players',
              controller: searchController,
              onChanged: onQueryChanged,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: SpacingTokens.space16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: VikzarChipGroup<TrainingStatus?>(
                options: const [null, ...TrainingStatus.values],
                labelBuilder: (status) => status?.label ?? 'All',
                selected: {statusFilter},
                onChanged: (selected) => onStatusFilterChanged(selected.first),
                multiSelect: false,
              ),
            ),
          ),
          const SizedBox(height: SpacingTokens.space8),
          Expanded(
            child: entriesAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SectionEmptyState(
                icon: Symbols.error,
                headline: "Couldn't load your roster.",
                body: 'Check your connection and try again.',
              ),
              data: (entries) {
                if (entries.isEmpty) {
                  return const SectionEmptyState(
                    icon: Symbols.group_off,
                    headline: 'No players yet.',
                    body: 'Players will appear here once they join your team.',
                  );
                }

                final filtered = entries.where((entry) {
                  final matchesQuery =
                      query.trim().isEmpty ||
                      entry.member.displayName.toLowerCase().contains(
                        query.trim().toLowerCase(),
                      );
                  final matchesStatus =
                      statusFilter == null || entry.trainingStatus == statusFilter;
                  return matchesQuery && matchesStatus;
                }).toList();

                if (filtered.isEmpty) {
                  return const SectionEmptyState(
                    icon: Symbols.search_off,
                    headline: 'No players match.',
                    body: 'Try a different search or filter.',
                  );
                }

                return _GroupedRoster(entries: filtered);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupedRoster extends StatelessWidget {
  const _GroupedRoster({required this.entries});

  final List<RosterEntry> entries;

  @override
  Widget build(BuildContext context) {
    final grouped = <PlayingPosition?, List<RosterEntry>>{};
    for (final entry in entries) {
      final position = PlayingPosition.fromName(entry.member.position);
      grouped.putIfAbsent(position, () => []).add(entry);
    }

    final groupOrder = [..._positionOrder, null];

    return ListView(
      children: [
        for (final position in groupOrder)
          if (grouped[position] case final members? when members.isNotEmpty) ...[
            VikzarSectionHeader(position == null ? 'Other' : _positionGroupLabels[position]!),
            for (final entry in members)
              VikzarListRow(
                title: entry.member.displayName,
                trailing: entry.trainingStatus == null
                    ? null
                    : VikzarStatusChip(label: entry.trainingStatus!.label),
                onTap: () => context.push(AppRoute.coachTeamPlayerPath(entry.member.uid)),
              ),
          ],
        const SizedBox(height: SpacingTokens.space32),
      ],
    );
  }
}
