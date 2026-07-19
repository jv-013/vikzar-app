import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../design_system/components/vikzar_button.dart';
import '../../../../design_system/tokens/motion.dart';
import '../../../../design_system/tokens/spacing.dart';
import '../../../../routing/app_router.dart';
import '../../../../shared/models/workspace_type.dart';

/// Confirmation screen after submitting a "Become a Coach" request —
/// DESIGN_SPECIFICATION.md's Phase 7 addition. Explicitly *not* a success
/// state implying Coach access now exists — copy is deliberately framed
/// as "submitted for review," matching the placeholder-only nature of the
/// request (DECISIONS.md ADR-049).
class BecomeACoachCompleteScreen extends StatelessWidget {
  const BecomeACoachCompleteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                    Icon(
                      Symbols.mark_email_read,
                      size: 56,
                      color: theme.colorScheme.onSurface,
                    ),
                    const SizedBox(height: SpacingTokens.space32),
                    Text(
                      'Your request has been submitted.',
                      style: theme.textTheme.headlineLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: SpacingTokens.space12),
                    Text(
                      "We'll review it and notify you once your Coach "
                      'workspace has been approved.',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: SpacingTokens.space40),
                    VikzarButton(
                      label: 'Done',
                      // Not `context.pop()`: this screen was reached via
                      // two pushes (the form, then this confirmation) —
                      // popping once would show the form again. Become a
                      // Coach is Player-only, so Home is unambiguous.
                      onPressed: () => context.go(AppRoute.homePath(WorkspaceType.player)),
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
