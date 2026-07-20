import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failure_message_mapper.dart';
import '../../../../design_system/components/vikzar_button.dart';
import '../../../../design_system/components/vikzar_icon.dart';
import '../../../../design_system/tokens/motion.dart';
import '../../../../design_system/tokens/spacing.dart';
import '../../../../shared/models/workspace_type.dart';
import '../controllers/onboarding_completion_controller.dart';

/// Terminal screen for both onboarding paths — DESIGN_SPECIFICATION.md
/// §19.1, step 6. Calm, brief, a single "Get Started" action.
///
/// **Revised at Phase 8B:** "Get Started" now writes this workspace's
/// collected profile (and, for a coach, creates/joins its team) to
/// Firestore via [OnboardingCompletionController] — see DECISIONS.md
/// ADR-051 — replacing Phase 7's local-only completion flag. Still
/// deliberately *not* triggered automatically on mount, per this phase's
/// "the interaction must be obvious, never a hidden/automatic transition"
/// principle. Once the write succeeds, no explicit `context.go` call is
/// needed here: `routing/route_guards.dart` watches the same
/// `users/{uid}` document this write updates, and reacts on its own. A
/// **returning** user who already completed this workspace's onboarding
/// skips this screen entirely on future cold starts and lands straight on
/// Home — this remains a first-time-only celebratory moment.
class OnboardingCompleteScreen extends ConsumerWidget {
  const OnboardingCompleteScreen({super.key, required this.workspace});

  final WorkspaceType workspace;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final label = workspace == WorkspaceType.player ? 'Player' : 'Coach';
    final completionState = ref.watch(
      onboardingCompletionControllerProvider(workspace),
    );
    final errorText = completionState.failure == null
        ? null
        : FailureMessageMapper.toMessage(completionState.failure!);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: SpacingTokens.space24),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: MotionTokens.softScaleIn,
                curve: MotionTokens.entrance,
                builder: (context, value, child) => Opacity(
                  opacity: value,
                  child: Transform.scale(scale: 0.98 + (0.02 * value), child: child),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    VikzarIcon(size: 56, color: theme.colorScheme.onSurface),
                    const SizedBox(height: SpacingTokens.space32),
                    Text(
                      "You're all set.",
                      style: theme.textTheme.headlineLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: SpacingTokens.space12),
                    Text(
                      'Your $label workspace is ready.',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: SpacingTokens.space40),
                    VikzarButton(
                      label: 'Get Started',
                      isLoading: completionState.isSubmitting,
                      onPressed: completionState.isSubmitting
                          ? null
                          : () => ref
                                .read(
                                  onboardingCompletionControllerProvider(
                                    workspace,
                                  ).notifier,
                                )
                                .complete(),
                    ),
                    if (errorText != null) ...[
                      const SizedBox(height: SpacingTokens.space16),
                      Text(
                        errorText,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
