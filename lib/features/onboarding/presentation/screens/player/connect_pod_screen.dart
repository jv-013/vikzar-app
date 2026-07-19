import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../../design_system/theme/vikzar_elevation.dart';
import '../../../../../design_system/tokens/radius.dart';
import '../../../../../design_system/tokens/spacing.dart';
import '../../../../../routing/app_router.dart';
import '../../../../../shared/models/workspace_type.dart';
import '../../widgets/onboarding_step_scaffold.dart';

/// Step 5a (Player only) — DESIGN_SPECIFICATION.md §19.1. A **placeholder
/// pairing screen only**: no Bluetooth communication is implemented this
/// phase (explicitly out of scope). Pod assignment status is always
/// "unassigned" — the laptop-centric MVP architecture (DECISIONS.md
/// ADR-030) means matching a Pod to an account is a coach/laptop action
/// this codebase never performs.
class ConnectPodScreen extends ConsumerWidget {
  const ConnectPodScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final elevation = theme.extension<VikzarElevation>();

    return OnboardingStepScaffold(
      headline: 'Connect your first Vikzar Pod.',
      showBackButton: true,
      body: "Your coach's session laptop connects to your Pod during "
          "training and matches it to your account. Nothing to pair here — "
          "you're ready as soon as your Pod is assigned.",
      continueLabel: 'Continue anyway',
      onContinue: () => context.go(OnboardingRoute.completePath(WorkspaceType.player)),
      content: Container(
        padding: const EdgeInsets.all(SpacingTokens.space20),
        decoration: BoxDecoration(
          borderRadius: RadiusTokens.mediumRadius,
          color: elevation == null
              ? theme.colorScheme.surface
              : Color.alphaBlend(elevation.level1Overlay, theme.colorScheme.surface),
        ),
        child: Row(
          children: [
            Icon(
              Symbols.sensors_off,
              color: theme.colorScheme.onSurfaceVariant,
              size: 32,
            ),
            const SizedBox(width: SpacingTokens.space16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Not yet assigned', style: theme.textTheme.titleMedium),
                  const SizedBox(height: SpacingTokens.space4),
                  Text(
                    'Ask your coach to assign your Pod.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
