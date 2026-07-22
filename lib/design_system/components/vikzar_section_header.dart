import 'package:flutter/material.dart';

import '../tokens/spacing.dart';

/// DESIGN_SPECIFICATION.md §18, "List Row" — Grouping: "a Caption-size,
/// secondary-text section header above the first row of a group." Extracted
/// at Phase 9 from the identical private `_SectionHeader` widget both
/// `profile_screen.dart` and `settings_screen.dart` had independently
/// defined, so grouped-row screens share one implementation.
class VikzarSectionHeader extends StatelessWidget {
  const VikzarSectionHeader(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SpacingTokens.space16,
        SpacingTokens.space24,
        SpacingTokens.space16,
        SpacingTokens.space8,
      ),
      child: Text(
        label,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
