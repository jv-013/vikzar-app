import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../design_system/components/vikzar_status_chip.dart';
import '../../../../design_system/theme/vikzar_elevation.dart';
import '../../../../design_system/tokens/radius.dart';
import '../../../../design_system/tokens/spacing.dart';
import '../../domain/models/raz_response.dart';

/// RAZ's Awareness card — Part 6. Shows exactly what informed the last
/// response: which data sources are active, and RAZ's own internal
/// confidence in what it just said. Deliberately minimal — a label row
/// of source chips and one confidence line, nothing else. Hardware
/// upgrades this card's chip list; it never gates whether the card (or
/// RAZ itself) is available at all — Level 0, no hardware connected, is
/// a fully legitimate, fully-served state, shown here the same calm way
/// Level 1/2 would be.
class RazAwarenessCard extends StatelessWidget {
  const RazAwarenessCard({super.key, required this.awareness, required this.confidence});

  final RazAwareness awareness;
  final RazConfidence confidence;

  String get _confidenceLabel => switch (confidence) {
    RazConfidence.high => 'High',
    RazConfidence.moderate => 'Moderate',
    RazConfidence.low => 'Low',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final elevation = theme.extension<VikzarElevation>();
    final background = elevation == null
        ? theme.colorScheme.surface
        : Color.alphaBlend(elevation.level1Overlay, theme.colorScheme.surface);

    return Container(
      padding: const EdgeInsets.all(SpacingTokens.space16),
      decoration: BoxDecoration(color: background, borderRadius: RadiusTokens.mediumRadius),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Symbols.sensors, size: 18, color: theme.colorScheme.secondary),
              const SizedBox(width: SpacingTokens.space8),
              Text('Awareness', style: theme.textTheme.labelLarge),
            ],
          ),
          const SizedBox(height: SpacingTokens.space12),
          Wrap(
            spacing: SpacingTokens.space8,
            runSpacing: SpacingTokens.space8,
            children: [
              for (final source in awareness.sources)
                VikzarStatusChip(
                  label: source.label,
                  icon: source.active ? Symbols.check_circle : Symbols.circle,
                  color: source.active
                      ? theme.colorScheme.secondary
                      : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                ),
            ],
          ),
          const SizedBox(height: SpacingTokens.space12),
          Row(
            children: [
              Text(
                'Confidence',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const Spacer(),
              Text(_confidenceLabel, style: theme.textTheme.labelMedium),
            ],
          ),
        ],
      ),
    );
  }
}
