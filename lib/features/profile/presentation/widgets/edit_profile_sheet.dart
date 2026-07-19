import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/components/vikzar_bottom_sheet.dart';
import '../../../../design_system/components/vikzar_button.dart';
import '../../../../design_system/components/vikzar_chip_group.dart';
import '../../../../design_system/components/vikzar_segmented_control.dart';
import '../../../../design_system/components/vikzar_text_field.dart';
import '../../../../design_system/tokens/spacing.dart';
import '../../../../shared/models/workspace_type.dart';
import '../../../onboarding/domain/models/coach_onboarding_data.dart';
import '../../../onboarding/domain/models/player_onboarding_data.dart';
import '../../../onboarding/presentation/controllers/coach_onboarding_controller.dart';
import '../../../onboarding/presentation/controllers/player_onboarding_controller.dart';

/// Edit Profile — DESIGN_SPECIFICATION.md §19.2's "each row tap-through to
/// an inline edit sheet," consolidated here into one sheet for every field
/// rather than one sheet per row (the field set is small enough that
/// splitting it further would be more taps, not less friction).
///
/// Edits the same in-memory onboarding-controller state Home/Profile
/// already read from — there is no separate "profile repository" this
/// phase (no Firestore writes), so this *is* the account's editable
/// profile data for now, exactly as honest as everywhere else nothing is
/// persisted server-side yet.
class EditProfileSheet {
  static Future<void> show(BuildContext context, {required WorkspaceType workspace}) {
    return VikzarBottomSheet.show<void>(
      context,
      builder: (_) => workspace == WorkspaceType.player
          ? const _EditPlayerProfileForm()
          : const _EditCoachProfileForm(),
    );
  }
}

class _EditPlayerProfileForm extends ConsumerStatefulWidget {
  const _EditPlayerProfileForm();

  @override
  ConsumerState<_EditPlayerProfileForm> createState() => _EditPlayerProfileFormState();
}

class _EditPlayerProfileFormState extends ConsumerState<_EditPlayerProfileForm> {
  late final TextEditingController _nameController;
  late final TextEditingController _ageController;
  PreferredFoot? _foot;
  PlayingPosition? _position;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(playerOnboardingControllerProvider).profile;
    _nameController = TextEditingController(text: profile.name);
    _ageController = TextEditingController(text: profile.age?.toString() ?? '');
    _foot = profile.preferredFoot;
    _position = profile.position;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  void _save() {
    final controller = ref.read(playerOnboardingControllerProvider.notifier);
    final current = ref.read(playerOnboardingControllerProvider).profile;
    controller.setProfile(
      PlayerProfileData(
        name: _nameController.text.trim(),
        age: int.tryParse(_ageController.text.trim()),
        height: current.height,
        weight: current.weight,
        preferredFoot: _foot,
        position: _position,
        injuryStatus: current.injuryStatus,
        injuryTypes: current.injuryTypes,
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: SpacingTokens.space20,
          right: SpacingTokens.space20,
          top: SpacingTokens.space20,
          bottom: MediaQuery.of(context).viewInsets.bottom + SpacingTokens.space20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Edit Profile', style: theme.textTheme.titleLarge),
            const SizedBox(height: SpacingTokens.space20),
            VikzarTextField(label: 'Name', controller: _nameController),
            const SizedBox(height: SpacingTokens.space16),
            VikzarTextField(
              label: 'Age',
              controller: _ageController,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: SpacingTokens.space20),
            Text('Preferred Foot', style: theme.textTheme.titleSmall),
            const SizedBox(height: SpacingTokens.space8),
            VikzarSegmentedControl<PreferredFoot>(
              options: PreferredFoot.values,
              labelBuilder: (foot) => foot.label,
              selected: _foot,
              onChanged: (value) => setState(() => _foot = value),
            ),
            const SizedBox(height: SpacingTokens.space20),
            Text('Playing Position', style: theme.textTheme.titleSmall),
            const SizedBox(height: SpacingTokens.space8),
            VikzarChipGroup<PlayingPosition>(
              options: PlayingPosition.values,
              labelBuilder: (position) => position.label,
              selected: {?_position},
              multiSelect: false,
              onChanged: (selection) => setState(
                () => _position = selection.isEmpty ? null : selection.first,
              ),
            ),
            const SizedBox(height: SpacingTokens.space24),
            Align(
              alignment: Alignment.centerRight,
              child: VikzarButton(label: 'Save', onPressed: _save),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditCoachProfileForm extends ConsumerStatefulWidget {
  const _EditCoachProfileForm();

  @override
  ConsumerState<_EditCoachProfileForm> createState() => _EditCoachProfileFormState();
}

class _EditCoachProfileFormState extends ConsumerState<_EditCoachProfileForm> {
  late final TextEditingController _nameController;
  late final TextEditingController _ageController;
  late final TextEditingController _titleController;
  late final TextEditingController _clubController;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(coachOnboardingControllerProvider).profile;
    _nameController = TextEditingController(text: profile.name);
    _ageController = TextEditingController(text: profile.age?.toString() ?? '');
    _titleController = TextEditingController(text: profile.title);
    _clubController = TextEditingController(text: profile.club);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _titleController.dispose();
    _clubController.dispose();
    super.dispose();
  }

  void _save() {
    ref.read(coachOnboardingControllerProvider.notifier).setProfile(
      CoachProfileData(
        name: _nameController.text.trim(),
        age: int.tryParse(_ageController.text.trim()),
        title: _titleController.text.trim(),
        club: _clubController.text.trim(),
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: SpacingTokens.space20,
          right: SpacingTokens.space20,
          top: SpacingTokens.space20,
          bottom: MediaQuery.of(context).viewInsets.bottom + SpacingTokens.space20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Edit Profile', style: theme.textTheme.titleLarge),
            const SizedBox(height: SpacingTokens.space20),
            VikzarTextField(label: 'Name', controller: _nameController),
            const SizedBox(height: SpacingTokens.space16),
            VikzarTextField(
              label: 'Age',
              controller: _ageController,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: SpacingTokens.space16),
            VikzarTextField(label: 'Coaching Title/Role', controller: _titleController),
            const SizedBox(height: SpacingTokens.space16),
            VikzarTextField(label: 'Club/Organization', controller: _clubController),
            const SizedBox(height: SpacingTokens.space24),
            Align(
              alignment: Alignment.centerRight,
              child: VikzarButton(label: 'Save', onPressed: _save),
            ),
          ],
        ),
      ),
    );
  }
}
