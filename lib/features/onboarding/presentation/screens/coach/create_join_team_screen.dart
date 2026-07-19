import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../../design_system/components/vikzar_expandable_section.dart';
import '../../../../../design_system/components/vikzar_selectable_card.dart';
import '../../../../../design_system/components/vikzar_text_field.dart';
import '../../../../../design_system/tokens/spacing.dart';
import '../../../../../routing/app_router.dart';
import '../../../../../shared/models/workspace_type.dart';
import '../../../domain/models/coach_onboarding_data.dart';
import '../../controllers/coach_onboarding_controller.dart';
import '../../widgets/onboarding_step_scaffold.dart';

/// Step 5b (Coach) — DESIGN_SPECIFICATION.md §19.1. Two options as large
/// selectable Cards, each opening an inline field — never a new screen.
/// **UI only this phase**: no Cloud Function is called (Firestore/Cloud
/// Functions are out of scope), so nothing is actually created or joined —
/// see DECISIONS.md's Phase 6 onboarding-state ADR.
class CreateJoinTeamScreen extends ConsumerStatefulWidget {
  const CreateJoinTeamScreen({super.key});

  @override
  ConsumerState<CreateJoinTeamScreen> createState() => _CreateJoinTeamScreenState();
}

class _CreateJoinTeamScreenState extends ConsumerState<CreateJoinTeamScreen> {
  late final TextEditingController _teamNameController;
  late final TextEditingController _inviteCodeController;
  TeamSetupMode? _mode;

  @override
  void initState() {
    super.initState();
    final existing = ref.read(coachOnboardingControllerProvider).team;
    _teamNameController = TextEditingController(text: existing.teamName);
    _inviteCodeController = TextEditingController(text: existing.inviteCode);
    _mode = existing.mode;
  }

  @override
  void dispose() {
    _teamNameController.dispose();
    _inviteCodeController.dispose();
    super.dispose();
  }

  TeamSetupData get _current => TeamSetupData(
    mode: _mode,
    teamName: _teamNameController.text.trim(),
    inviteCode: _inviteCodeController.text.trim(),
  );

  void _continue() {
    ref.read(coachOnboardingControllerProvider.notifier).setTeam(_current);
    context.go(OnboardingRoute.completePath(WorkspaceType.coach));
  }

  @override
  Widget build(BuildContext context) {
    final continueLabel = switch (_mode) {
      TeamSetupMode.create => 'Create',
      TeamSetupMode.join => 'Join',
      null => 'Continue',
    };

    return OnboardingStepScaffold(
      headline: 'Set up your team.',
      showBackButton: true,
      continueLabel: continueLabel,
      onContinue: _current.isComplete ? _continue : null,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          VikzarSelectableCard(
            icon: Symbols.add_circle,
            title: 'Create a new team',
            subtitle: 'Start fresh and invite your players.',
            selected: _mode == TeamSetupMode.create,
            onTap: () => setState(() => _mode = TeamSetupMode.create),
          ),
          VikzarExpandableSection(
            expanded: _mode == TeamSetupMode.create,
            child: VikzarTextField(
              label: 'Team name',
              controller: _teamNameController,
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(height: SpacingTokens.space16),
          VikzarSelectableCard(
            icon: Symbols.groups,
            title: 'Join an existing team',
            subtitle: 'Use an invite code from your club.',
            selected: _mode == TeamSetupMode.join,
            onTap: () => setState(() => _mode = TeamSetupMode.join),
          ),
          VikzarExpandableSection(
            expanded: _mode == TeamSetupMode.join,
            child: VikzarTextField(
              label: 'Invite code',
              controller: _inviteCodeController,
              onChanged: (_) => setState(() {}),
            ),
          ),
        ],
      ),
    );
  }
}
