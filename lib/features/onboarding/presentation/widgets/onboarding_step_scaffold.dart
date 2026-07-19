import 'package:flutter/material.dart';

import '../../../../design_system/components/vikzar_button.dart';
import '../../../../design_system/tokens/spacing.dart';

/// The shared layout every onboarding step screen (Level, Profile,
/// Permissions, Connect Pod / Create-Join Team) is built from — headline,
/// optional body copy, the step's own content, a single primary "Continue"
/// action bottom-right. Not used by Splash/Auth (their own layouts predate
/// this phase) or Onboarding Complete (a terminal screen with a
/// deliberately different, centered layout).
class OnboardingStepScaffold extends StatelessWidget {
  const OnboardingStepScaffold({
    super.key,
    required this.headline,
    this.body,
    required this.content,
    required this.onContinue,
    this.continueLabel = 'Continue',
    this.isLoading = false,
    this.showBackButton = false,
  });

  final String headline;
  final String? body;
  final Widget content;
  final VoidCallback? onContinue;
  final String continueLabel;
  final bool isLoading;
  final bool showBackButton;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: showBackButton
          ? AppBar(backgroundColor: Colors.transparent, elevation: 0)
          : null,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: SpacingTokens.space24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: showBackButton
                        ? SpacingTokens.space16
                        : SpacingTokens.space64,
                  ),
                  Text(headline, style: theme.textTheme.headlineLarge),
                  if (body != null) ...[
                    const SizedBox(height: SpacingTokens.space12),
                    Text(
                      body!,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: SpacingTokens.space32),
                  content,
                  const SizedBox(height: SpacingTokens.space32),
                  Align(
                    alignment: Alignment.centerRight,
                    child: VikzarButton(
                      label: continueLabel,
                      isLoading: isLoading,
                      onPressed: onContinue,
                    ),
                  ),
                  const SizedBox(height: SpacingTokens.space64),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
