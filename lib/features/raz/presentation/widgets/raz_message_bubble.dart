import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../design_system/components/vikzar_status_chip.dart';
import '../../../../design_system/theme/vikzar_elevation.dart';
import '../../../../design_system/tokens/radius.dart';
import '../../../../design_system/tokens/spacing.dart';
import '../../domain/models/raz_message.dart';
import '../../domain/models/raz_response.dart';

class RazMessageBubble extends StatelessWidget {
  const RazMessageBubble({super.key, required this.message, this.onSpeak});

  final RazMessage message;

  /// Only offered on RAZ's own replies — lets the reader hear an answer
  /// they typed for, without voice ever being required to use this
  /// screen at all.
  final ValueChanged<String>? onSpeak;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = message.sender == RazSender.user;
    final elevation = theme.extension<VikzarElevation>();
    final razBackground = elevation == null
        ? theme.colorScheme.surface
        : Color.alphaBlend(elevation.level1Overlay, theme.colorScheme.surface);

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        child: Container(
          padding: const EdgeInsets.all(SpacingTokens.space16),
          margin: const EdgeInsets.symmetric(vertical: SpacingTokens.space4),
          decoration: BoxDecoration(
            color: isUser ? theme.colorScheme.primary : razBackground,
            borderRadius: RadiusTokens.mediumRadius,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                message.text,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isUser ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
                ),
              ),
              if (!isUser && message.response != null) ..._razFooter(context, message.response!),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _razFooter(BuildContext context, RazResponse response) {
    final theme = Theme.of(context);
    return [
      if (response.highlights.isNotEmpty) ...[
        const SizedBox(height: SpacingTokens.space8),
        Wrap(
          spacing: SpacingTokens.space8,
          runSpacing: SpacingTokens.space8,
          children: [
            for (final highlight in response.highlights)
              VikzarStatusChip(label: '${highlight.label}: ${highlight.value}'),
          ],
        ),
      ],
      // Only surfaced when genuinely low — RAZ says so rather than
      // implying more certainty than the underlying data supports.
      if (response.confidence == RazConfidence.low) ...[
        const SizedBox(height: SpacingTokens.space8),
        Text(
          'Limited data available for this.',
          style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
      if (onSpeak != null) ...[
        const SizedBox(height: SpacingTokens.space4),
        InkWell(
          onTap: () => onSpeak!(response.text),
          child: Padding(
            padding: const EdgeInsets.only(top: SpacingTokens.space4),
            child: Icon(Symbols.volume_up, size: 18, color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      ],
    ];
  }
}
