import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/vikzar_elevation.dart';
import '../tokens/motion.dart';
import '../tokens/radius.dart';
import '../tokens/spacing.dart';

/// DESIGN_SPECIFICATION.md §19.1's Workspace Selection card: "`radius-md`,
/// Elevation 1 at rest / 2 selected."
///
/// The selected state is also this app's one deliberate use of a glass
/// effect, per this phase's Permanent Design Principle ("restrained…used
/// only where hierarchy benefits"): a subtle backdrop blur communicates
/// "this one is chosen" at the exact moment selection changes — a genuine
/// hierarchy signal, not a decorative background treatment. It is not
/// applied to any other surface in this app.
class VikzarSelectableCard extends StatelessWidget {
  const VikzarSelectableCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final elevation = theme.extension<VikzarElevation>();
    final overlay = selected
        ? elevation?.level2Overlay
        : elevation?.level1Overlay;

    return ClipRRect(
      borderRadius: RadiusTokens.mediumRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: selected ? 12 : 0,
          sigmaY: selected ? 12 : 0,
        ),
        child: AnimatedContainer(
          duration: MotionTokens.standard,
          curve: MotionTokens.entrance,
          decoration: BoxDecoration(
            borderRadius: RadiusTokens.mediumRadius,
            border: Border.all(
              color: selected
                  ? colorScheme.primary
                  : colorScheme.onSurface.withValues(alpha: 0.12),
              width: selected ? 2 : 1,
            ),
            color: overlay == null
                ? colorScheme.surface
                : Color.alphaBlend(overlay, colorScheme.surface),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: RadiusTokens.mediumRadius,
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(SpacingTokens.space20),
                child: Row(
                  children: [
                    Icon(icon, color: colorScheme.onSurface, size: 32),
                    const SizedBox(width: SpacingTokens.space16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: theme.textTheme.titleMedium),
                          const SizedBox(height: SpacingTokens.space4),
                          Text(
                            subtitle,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
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
