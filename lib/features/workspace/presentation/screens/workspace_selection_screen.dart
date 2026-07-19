import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../design_system/components/vikzar_button.dart';
import '../../../../design_system/components/vikzar_selectable_card.dart';
import '../../../../design_system/tokens/spacing.dart';
import '../../../../shared/models/workspace_type.dart';
import '../controllers/workspace_selection_controller.dart';

/// Workspace Selection — DESIGN_SPECIFICATION.md §19.1, step 1 of the
/// six-screen onboarding flow. "You can switch between Player and Coach
/// anytime — this just picks where you start."
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
                    'You can switch between Player and Coach anytime — '
                    'this just picks where you start.',
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
