import 'package:flutter/material.dart';

import '../tokens/motion.dart';
import '../tokens/radius.dart';
import '../tokens/spacing.dart';

/// A wrapping row of selectable pill chips — Playing Position and the
/// Injury History detail list (DESIGN_SPECIFICATION.md §19.1). Generic
/// over [T] and multi-select by default; pass `multiSelect: false` for a
/// single-choice chip row.
class VikzarChipGroup<T> extends StatelessWidget {
  const VikzarChipGroup({
    super.key,
    required this.options,
    required this.labelBuilder,
    required this.selected,
    required this.onChanged,
    this.multiSelect = true,
  });

  final List<T> options;
  final String Function(T) labelBuilder;
  final Set<T> selected;
  final ValueChanged<Set<T>> onChanged;
  final bool multiSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Wrap(
      spacing: SpacingTokens.space8,
      runSpacing: SpacingTokens.space8,
      children: options.map((option) {
        final isSelected = selected.contains(option);
        return GestureDetector(
          onTap: () {
            if (!multiSelect) {
              onChanged({option});
              return;
            }
            final next = Set<T>.from(selected);
            if (isSelected) {
              next.remove(option);
            } else {
              next.add(option);
            }
            onChanged(next);
          },
          child: AnimatedContainer(
            duration: MotionTokens.standard,
            curve: MotionTokens.entrance,
            padding: const EdgeInsets.symmetric(
              horizontal: SpacingTokens.space16,
              vertical: SpacingTokens.space8,
            ),
            decoration: BoxDecoration(
              borderRadius: RadiusTokens.pillRadius,
              color: isSelected ? colorScheme.primary : Colors.transparent,
              border: Border.all(
                color: isSelected
                    ? colorScheme.primary
                    : colorScheme.onSurface.withValues(alpha: 0.24),
              ),
            ),
            child: Text(
              labelBuilder(option),
              style: theme.textTheme.labelLarge?.copyWith(
                color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
