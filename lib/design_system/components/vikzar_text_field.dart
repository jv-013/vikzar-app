import 'package:flutter/material.dart';

import '../tokens/radius.dart';

/// DESIGN_SPECIFICATION.md §18, "Text Fields" — floating label (never a
/// placeholder-only field, per that section's accessibility rule), Oxide
/// Rose focus border (primary action colour, per §8's Phase 5 colour
/// philosophy), Oxide Rose error state.
class VikzarTextField extends StatelessWidget {
  const VikzarTextField({
    super.key,
    required this.label,
    this.controller,
    this.errorText,
    this.obscureText = false,
    this.keyboardType,
    this.autofillHints,
    this.enabled = true,
    this.onSubmitted,
  });

  final String label;
  final TextEditingController? controller;
  final String? errorText;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final bool enabled;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      autofillHints: autofillHints,
      enabled: enabled,
      onSubmitted: onSubmitted,
      style: TextStyle(color: colorScheme.onSurface),
      decoration: InputDecoration(
        labelText: label,
        errorText: errorText,
        border: OutlineInputBorder(
          borderRadius: RadiusTokens.smallRadius,
          borderSide: BorderSide(
            color: colorScheme.onSurface.withValues(alpha: 0.24),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: RadiusTokens.smallRadius,
          borderSide: BorderSide(
            color: colorScheme.onSurface.withValues(alpha: 0.24),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: RadiusTokens.smallRadius,
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: RadiusTokens.smallRadius,
          borderSide: BorderSide(color: colorScheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: RadiusTokens.smallRadius,
          borderSide: BorderSide(color: colorScheme.error, width: 2),
        ),
      ),
    );
  }
}
