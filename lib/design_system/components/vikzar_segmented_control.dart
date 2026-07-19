import 'package:flutter/material.dart';

import '../tokens/motion.dart';
import '../tokens/radius.dart';
import '../tokens/spacing.dart';

/// DESIGN_SPECIFICATION.md §18, "Segment Controls" — pill outer container,
/// active segment filled Oxide Rose (primary action colour). Generic over
/// [T] so Level, Preferred Foot, and Injury History can each drive it with
/// their own option type without three near-duplicate widgets.
class VikzarSegmentedControl<T> extends StatelessWidget {
  const VikzarSegmentedControl({
    super.key,
    required this.options,
    required this.labelBuilder,
    required this.selected,
    required this.onChanged,
  });

  final List<T> options;
  final String Function(T) labelBuilder;
  final T? selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        borderRadius: RadiusTokens.pillRadius,
        border: Border.all(color: colorScheme.onSurface.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: options.map((option) {
          final isSelected = option == selected;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(option),
              child: AnimatedContainer(
                duration: MotionTokens.standard,
                curve: MotionTokens.entrance,
                padding: const EdgeInsets.symmetric(vertical: SpacingTokens.space8),
                decoration: BoxDecoration(
                  color: isSelected ? colorScheme.primary : Colors.transparent,
                  borderRadius: RadiusTokens.pillRadius,
                ),
                child: Center(
                  child: Text(
                    labelBuilder(option),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
