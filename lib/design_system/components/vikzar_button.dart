import 'package:flutter/material.dart';

import '../tokens/radius.dart';
import '../tokens/spacing.dart';

/// DESIGN_SPECIFICATION.md §18, "Buttons" — one component covering all
/// four variants, differentiated by shape/fill (not by a second colour),
/// per §8's Phase 5 colour philosophy note on Primary vs. Destructive.
enum VikzarButtonVariant { primary, secondary, tertiary, destructive }

class VikzarButton extends StatelessWidget {
  const VikzarButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = VikzarButtonVariant.primary,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final VikzarButtonVariant variant;

  /// Shows an inline spinner in place of the label without changing the
  /// button's width, per DESIGN_SPECIFICATION.md §18's loading-state rule
  /// (avoids layout shift).
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final enabled = onPressed != null && !isLoading;

    final (Color background, Color foreground, BorderSide? border) =
        switch (variant) {
          VikzarButtonVariant.primary => (
            colorScheme.primary,
            colorScheme.onPrimary,
            null,
          ),
          VikzarButtonVariant.secondary => (
            Colors.transparent,
            colorScheme.onSurface,
            BorderSide(color: colorScheme.onSurface.withValues(alpha: 0.24)),
          ),
          VikzarButtonVariant.tertiary => (
            Colors.transparent,
            colorScheme.primary,
            null,
          ),
          VikzarButtonVariant.destructive => (
            Colors.transparent,
            colorScheme.error,
            BorderSide(color: colorScheme.error),
          ),
        };

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
      child: TextButton(
        onPressed: enabled ? onPressed : null,
        style: TextButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          disabledBackgroundColor: variant == VikzarButtonVariant.primary
              ? background.withValues(alpha: 0.32)
              : Colors.transparent,
          disabledForegroundColor: foreground.withValues(alpha: 0.32),
          side: border,
          shape: const RoundedRectangleBorder(
            borderRadius: RadiusTokens.pillRadius,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: SpacingTokens.space24,
            vertical: SpacingTokens.space12,
          ),
        ),
        child: isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(foreground),
                ),
              )
            : Text(label),
      ),
    );
  }
}
