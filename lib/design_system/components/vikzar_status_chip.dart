import 'package:flutter/material.dart';

import '../tokens/radius.dart';
import '../tokens/spacing.dart';

/// DESIGN_SPECIFICATION.md §18, "Status Chips" — `radius-xs`, filled at 16%
/// opacity of the semantic colour with full-opacity text/icon of the same
/// colour. Colour is always paired with a text label, never load-bearing on
/// its own (UX Principle 2).
///
/// **Added at Phase 9.** Defaults to Mineral Blue (`colorScheme.secondary`)
/// — per this phase's colour philosophy, Mineral Blue is the consistent
/// informational/intelligence colour (readiness, connection state, squad
/// status, timeline/activity accents) across every screen built this
/// phase, distinct from Oxide Rose (`colorScheme.primary`), which stays
/// reserved for actions/CTAs. An explicit [color] override exists for the
/// rare case a caller genuinely needs a different semantic colour, but no
/// screen built this phase uses it.
class VikzarStatusChip extends StatelessWidget {
  const VikzarStatusChip({super.key, required this.label, this.icon, this.color});

  final String label;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chipColor = color ?? theme.colorScheme.secondary;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.16),
        borderRadius: RadiusTokens.extraSmallRadius,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: SpacingTokens.space8,
          vertical: SpacingTokens.space4,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: chipColor),
              const SizedBox(width: SpacingTokens.space4),
            ],
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(color: chipColor),
            ),
          ],
        ),
      ),
    );
  }
}
