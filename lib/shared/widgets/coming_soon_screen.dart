import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../design_system/tokens/spacing.dart';

/// A shared, honest placeholder for a real bottom-nav destination that
/// this phase wires into the shell but does not build out — Timeline,
/// History, Live Team Monitoring, Team, Alerts. Building each to
/// DESIGN_SPECIFICATION.md §19.2/§19.3's full wireframe depth is explicit
/// future-phase work (Roadmap Phases 6–11); this screen exists so the
/// bottom nav is genuinely navigable today rather than pointing at a
/// route that doesn't exist. Uses the same layout skeleton as an Empty
/// State ([§18](../../../DESIGN_SPECIFICATION.md#18-component-library)),
/// not a bespoke one.
class ComingSoonScreen extends StatelessWidget {
  const ComingSoonScreen({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(SpacingTokens.space32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Symbols.schedule,
                  size: 40,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: SpacingTokens.space20),
                Text(
                  title,
                  style: theme.textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: SpacingTokens.space8),
                Text(
                  'Coming in a future phase.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
