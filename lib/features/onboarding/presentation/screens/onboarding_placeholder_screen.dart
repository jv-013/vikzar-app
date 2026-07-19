import 'package:flutter/material.dart';

import '../../../../design_system/tokens/spacing.dart';
import '../../../../shared/models/workspace_type.dart';

/// "Role-specific onboarding (future)" — the terminal destination of this
/// phase's Identity Flow (Launch → Splash → Authentication → Workspace
/// Selection → **here**). Per this phase's explicit instruction — "Do not
/// implement onboarding itself. Only navigate to placeholders" — this is
/// deliberately not the real Profile Form / Permissions / Connect-Pod /
/// Create-Join-Team steps (DESIGN_SPECIFICATION.md §19.1, steps 2–5),
/// only proof that the router correctly reaches a workspace-specific
/// destination.
class OnboardingPlaceholderScreen extends StatelessWidget {
  const OnboardingPlaceholderScreen({super.key, required this.workspace});

  final WorkspaceType workspace;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = switch (workspace) {
      WorkspaceType.player => 'Player',
      WorkspaceType.coach => 'Coach',
    };

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(SpacingTokens.space24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$label onboarding', style: theme.textTheme.headlineLarge),
              const SizedBox(height: SpacingTokens.space12),
              Text(
                'Coming soon.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
