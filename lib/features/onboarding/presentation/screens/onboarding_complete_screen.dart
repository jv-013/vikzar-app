import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/components/vikzar_icon.dart';
import '../../../../design_system/tokens/motion.dart';
import '../../../../design_system/tokens/spacing.dart';
import '../../../../services/local_storage/onboarding_progress_store.dart';
import '../../../../shared/models/workspace_type.dart';

/// Terminal screen for both onboarding paths — DESIGN_SPECIFICATION.md
/// §19.1, step 6 (added Phase 6, superseding the original "lands directly
/// on Home" wireframe: Player/Coach Home are not built this phase). Calm,
/// brief, no further action required — matches Splash's "momentary
/// screen, not an interactive one" character.
///
/// Marks this workspace's onboarding as locally complete on first
/// appearance, so a returning user lands here directly rather than
/// repeating Level/Profile/Permissions every cold start (the router's
/// `InOnboarding.alreadyCompleted` gate, `routing/route_guards.dart`).
class OnboardingCompleteScreen extends ConsumerStatefulWidget {
  const OnboardingCompleteScreen({super.key, required this.workspace});

  final WorkspaceType workspace;

  @override
  ConsumerState<OnboardingCompleteScreen> createState() =>
      _OnboardingCompleteScreenState();
}

class _OnboardingCompleteScreenState
    extends ConsumerState<OnboardingCompleteScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(onboardingCompletionProvider.notifier)
          .markComplete(widget.workspace);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = widget.workspace == WorkspaceType.player ? 'Player' : 'Coach';

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
