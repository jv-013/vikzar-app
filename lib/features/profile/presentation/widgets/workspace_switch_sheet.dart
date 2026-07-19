import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../design_system/components/vikzar_bottom_sheet.dart';
import '../../../../design_system/components/vikzar_list_row.dart';
import '../../../../design_system/tokens/spacing.dart';
import '../../../../services/local_storage/onboarding_progress_store.dart';
import '../../../../shared/models/workspace_type.dart';
import '../../../workspace/presentation/controllers/active_workspace_controller.dart';

/// DESIGN_SPECIFICATION.md §13, "Switch Workspace" — only ever opened for
/// an account that holds more than one workspace ([ProfileBadge]/
/// [ProfileSheet] never offer this row otherwise). Lists exactly the
/// workspaces the account holds via [onboardingCompletionProvider] — not
/// hardcoded to Player and Coach, so a future third workspace type fits by
/// extending [WorkspaceType], not by redesigning this sheet.
class WorkspaceSwitchSheet extends ConsumerWidget {
  const WorkspaceSwitchSheet({super.key});

  static Future<void> show(BuildContext context) {
    return VikzarBottomSheet.show<void>(
      context,
      builder: (_) => const WorkspaceSwitchSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final held = ref.watch(onboardingCompletionProvider);
    final active = ref.watch(activeWorkspaceProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(
          top: SpacingTokens.space16,
          bottom: SpacingTokens.space16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: SpacingTokens.space20),
              child: Text('Switch Workspace', style: theme.textTheme.titleLarge),
            ),
            const SizedBox(height: SpacingTokens.space12),
            for (final type in WorkspaceType.values.where(held.contains))
              VikzarListRow(
                leading: Icon(
                  type == WorkspaceType.player ? Symbols.sports_soccer : Symbols.groups,
                  color: theme.colorScheme.onSurface,
                ),
                title: type.label,
                trailing: type == active
                    ? Icon(Symbols.check, color: theme.colorScheme.primary)
                    : null,
                onTap: () {
                  ref.read(activeWorkspaceProvider.notifier).setActiveWorkspace(type);
                  Navigator.of(context).pop();
                },
              ),
          ],
        ),
      ),
    );
  }
}
