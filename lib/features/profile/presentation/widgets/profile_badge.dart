import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../design_system/tokens/radius.dart';
import '../../../../design_system/tokens/spacing.dart';
import '../../../../shared/models/workspace_type.dart';
import '../../../../shared/providers/current_app_user_provider.dart';
import 'profile_sheet.dart';

/// The top-left app-bar control — DESIGN_SPECIFICATION.md §13's Phase 7
/// revision: the single entry point for every account-level action,
/// consolidating what used to be a separate workspace-switcher pill (see
/// [DECISIONS.md ADR-047]).
///
/// **The chevron is the only signal that switching is possible.** A
/// single-workspace account (the common case — every new account starts
/// Player-only, per this phase's explicit product direction) sees just
/// "PLAYER" or "COACH," no dropdown affordance, no hint that a second
/// workspace concept exists. Only once the account holds both workspaces
/// does the badge grow a chevron.
///
/// **Revised at Phase 8B:** "holds" now means [heldWorkspacesProvider] —
/// Firestore's `users/{uid}.workspaces`, per DECISIONS.md ADR-051 —
/// replacing Phase 7's local `onboardingCompletionProvider`. This is the
/// same source `routing/route_guards.dart` uses to decide whether a
/// workspace is "in app."
class ProfileBadge extends ConsumerWidget {
  const ProfileBadge({super.key, required this.workspace});

  final WorkspaceType workspace;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final heldWorkspaces = ref.watch(heldWorkspacesProvider);
    final isDual = heldWorkspaces.length > 1;

    return InkWell(
      borderRadius: RadiusTokens.pillRadius,
      onTap: () => ProfileSheet.show(context, workspace: workspace),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: SpacingTokens.space8,
          vertical: SpacingTokens.space4,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: colorScheme.onSurface.withValues(alpha: 0.12),
              child: Icon(Symbols.person, size: 16, color: colorScheme.onSurface),
            ),
            const SizedBox(width: SpacingTokens.space8),
            Text(
              workspace.label.toUpperCase(),
              style: theme.textTheme.labelLarge,
            ),
            if (isDual) ...[
              const SizedBox(width: SpacingTokens.space4),
              Icon(Symbols.expand_more, size: 18, color: colorScheme.onSurface),
            ],
          ],
        ),
      ),
    );
  }
}
