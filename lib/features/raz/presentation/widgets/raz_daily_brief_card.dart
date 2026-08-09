import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../design_system/components/vikzar_status_chip.dart';
import '../../../../design_system/theme/vikzar_elevation.dart';
import '../../../../design_system/tokens/radius.dart';
import '../../../../design_system/tokens/spacing.dart';
import '../../../../routing/app_router.dart';
import '../../../../shared/models/workspace_type.dart';
import '../../domain/models/raz_response.dart';
import '../../domain/repositories/raz_repository.dart';
import '../controllers/raz_daily_brief_controller.dart';
import 'raz_read_aloud_button.dart';

/// The primary experience on both Home screens: "Open App -> Today's
/// Brief -> Performance summary -> Recovery advice -> Today's focus ->
/// Optional follow-up conversation" (player), the equivalent
/// team-shaped flow for a coach. Real end to end: a genuine
/// `razDailyBrief` call, narrated from real context, rendered as the
/// distinct sections the backend's Reasoning Engine actually derived —
/// never one flattened paragraph, never a canned string. Chat and voice
/// (via the RAZ conversation screen this card opens) are the secondary,
/// optional interface, reached from here or the app bar — this card is
/// not.
class RazDailyBriefCard extends ConsumerWidget {
  const RazDailyBriefCard({super.key, required this.workspace});

  final WorkspaceType workspace;

  RazAudience get _audience =>
      workspace == WorkspaceType.player ? RazAudience.player : RazAudience.coach;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final elevation = theme.extension<VikzarElevation>();
    // Level3 (the highest overlay this design system defines) — the
    // brief is meant to read as the one unmissable thing on Home, not
    // another card among equals.
    final background = elevation == null
        ? theme.colorScheme.surface
        : Color.alphaBlend(elevation.level3Overlay, theme.colorScheme.surface);
    final briefAsync = ref.watch(razDailyBriefProvider(_audience));

    return Container(
      padding: const EdgeInsets.all(SpacingTokens.space20),
      decoration: BoxDecoration(color: background, borderRadius: RadiusTokens.mediumRadius),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: RadiusTokens.mediumRadius,
            onTap: () => context.push(AppRoute.razPath(workspace)),
            child: Row(
              children: [
                Icon(Symbols.self_improvement, size: 22, color: theme.colorScheme.secondary),
                const SizedBox(width: SpacingTokens.space8),
                Text("Today's Brief", style: theme.textTheme.titleMedium),
                const Spacer(),
                Icon(Symbols.chevron_right, size: 20, color: theme.colorScheme.onSurfaceVariant),
              ],
            ),
          ),
          const SizedBox(height: SpacingTokens.space16),
          briefAsync.when(
            loading: () => Text(
              'Reading today’s data…',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            error: (_, _) => Text(
              "Couldn't load today's brief.",
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error),
            ),
            data: (result) => result.fold(
              onSuccess: (response) => _BriefBody(response: response, workspace: workspace),
              onFailure: (_) => Text(
                "Couldn't load today's brief.",
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BriefBody extends StatelessWidget {
  const _BriefBody({required this.response, required this.workspace});

  final RazResponse response;
  final WorkspaceType workspace;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(bottom: SpacingTokens.space4),
            child: RazReadAloudButton(text: response.text),
          ),
        ),
        if (response.sections.isNotEmpty)
          // The Reasoning Engine's own sections — Performance/Recovery/
          // Today's Focus, or the coach equivalent — rendered distinctly
          // rather than as one paragraph.
          for (final section in response.sections) ...[
            Text(
              section.label,
              style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.secondary),
            ),
            const SizedBox(height: SpacingTokens.space4),
            Text(section.body, style: theme.textTheme.bodyMedium),
            const SizedBox(height: SpacingTokens.space12),
          ]
        else
          Text(response.text, style: theme.textTheme.bodyMedium),
        if (response.highlights.isNotEmpty) ...[
          const SizedBox(height: SpacingTokens.space4),
          Wrap(
            spacing: SpacingTokens.space8,
            runSpacing: SpacingTokens.space8,
            children: [
              for (final highlight in response.highlights)
                VikzarStatusChip(label: '${highlight.label}: ${highlight.value}'),
            ],
          ),
          const SizedBox(height: SpacingTokens.space16),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => context.push(AppRoute.razPath(workspace)),
            icon: const Icon(Symbols.chat_bubble, size: 18),
            label: const Text('Ask a follow-up'),
          ),
        ),
      ],
    );
  }
}
