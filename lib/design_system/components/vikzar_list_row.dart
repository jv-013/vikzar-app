import 'package:flutter/material.dart';

import '../tokens/spacing.dart';

/// DESIGN_SPECIFICATION.md §18, "List Row" — the single, formal component
/// behind every plain-row content list: Settings, Pod Connection's device
/// rows, Team's Roster tab, and (Phase 6) each Permissions row. Flat, no
/// card treatment, 56dp (single-line) / 72dp (with a secondary line),
/// satisfying the 48dp minimum touch target either way.
class VikzarListRow extends StatelessWidget {
  const VikzarListRow({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.enabled = true,
  });

  final Widget? leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Opacity(
      opacity: enabled ? 1 : 0.32,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: subtitle == null ? 56 : 72),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: SpacingTokens.space16,
                vertical: SpacingTokens.space12,
              ),
              child: Row(
                children: [
                  if (leading != null) ...[
                    leading!,
                    const SizedBox(width: SpacingTokens.space16),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(title, style: theme.textTheme.titleMedium),
                        if (subtitle != null) ...[
                          const SizedBox(height: SpacingTokens.space4),
                          Text(
                            subtitle!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: SpacingTokens.space16),
                    trailing!,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
