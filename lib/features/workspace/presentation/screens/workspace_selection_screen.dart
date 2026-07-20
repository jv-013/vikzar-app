import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../design_system/components/vikzar_button.dart';
import '../../../../design_system/components/vikzar_selectable_card.dart';
import '../../../../design_system/tokens/spacing.dart';
import '../../../../shared/models/workspace_type.dart';
import '../controllers/workspace_selection_controller.dart';

/// Workspace Selection — DESIGN_SPECIFICATION.md §19.1, step 1 of the
/// six-screen onboarding flow.
///
/// **Revised at Phase 8C:** the body copy no longer claims switching
/// between Player and Coach is available "anytime" — every new account
/// starts Player-only, and gaining a Coach workspace requires the
/// separate "Become a Coach" request-and-review flow (no auto-grant, per
/// DECISIONS.md ADR-049), so "anytime" overstated what this screen
/// actually does: pick the account's one starting workspace.
class WorkspaceSelectionScreen extends ConsumerWidget {
  const WorkspaceSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final selected = ref.watch(workspaceSelectionControllerProvider);
    final controller = ref.read(workspaceSelectionControllerProvider.notifier);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: SpacingTokens.space24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'How will you use Vikzar?',
                    style: theme.textTheme.headlineLarge,
                  ),
                  const SizedBox(height: SpacingTokens.space12),
                  Text(
                    "This is the workspace you'll start in — you can "
                    'request the other one later from your profile.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: SpacingTokens.space32),
                  VikzarSelectableCard(
                    icon: Symbols.sports_soccer,
                    title: 'Player',
                    subtitle: 'Track your own sessions and risk.',
                    selected: selected == WorkspaceType.player,
                    onTap: () => controller.select(WorkspaceType.player),
                  ),
                  const SizedBox(height: SpacingTokens.space16),
                  VikzarSelectableCard(
                    icon: Symbols.groups,
                    title: 'Coach',
                    subtitle: 'Monitor your team in real time.',
                    selected: selected == WorkspaceType.coach,
                    onTap: () => controller.select(WorkspaceType.coach),
                  ),
                  const SizedBox(height: SpacingTokens.space32),
                  Align(
                    alignment: Alignment.centerRight,
                    child: VikzarButton(
                      label: 'Continue',
                      onPressed: selected == null ? null : controller.confirm,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
