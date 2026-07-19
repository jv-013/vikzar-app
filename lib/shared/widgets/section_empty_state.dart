import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../design_system/tokens/spacing.dart';

/// DESIGN_SPECIFICATION.md §18, "Empty States": centered icon, Title
/// headline, Body supporting sentence, exactly one action — reused across
/// Player Home and Coach Home's session/alert/roster-dependent sections
/// (Phase 7) rather than each screen building its own empty-state layout.
class SectionEmptyState extends StatelessWidget {
  const SectionEmptyState({
    super.key,
    required this.icon,
    required this.headline,
    this.body,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String headline;
  final String? body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: SpacingTokens.space32),
      child: Column(
        children: [
          Icon(icon, size: 32, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: SpacingTokens.space16),
          Text(
            headline,
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          if (body != null) ...[
            const SizedBox(height: SpacingTokens.space4),
            Text(
              body!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: SpacingTokens.space12),
            TextButton(
              onPressed: onAction,
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

/// The `Symbols.info` icon used by default when a screen doesn't have a
/// bespoke line-art icon commissioned yet — DESIGN_SPECIFICATION.md §11
/// flags custom empty-state icons as future bespoke-icon work; Material
/// Symbols is the interim placeholder throughout this codebase.
const IconData defaultEmptyStateIcon = Symbols.inbox;
