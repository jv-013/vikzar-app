import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../design_system/components/vikzar_chip_group.dart';
import '../../../../../design_system/components/vikzar_segmented_control.dart';
import '../../../../../design_system/components/vikzar_text_field.dart';
import '../../../../../design_system/tokens/spacing.dart';
import '../../../../../routing/app_router.dart';
import '../../../../../shared/models/workspace_type.dart';
import '../../../domain/models/player_onboarding_data.dart';
import '../../controllers/player_onboarding_controller.dart';
import '../../widgets/onboarding_step_scaffold.dart';

/// Step 3 (Player) — DESIGN_SPECIFICATION.md §19.1. One vertically-stacked
/// form.
///
/// **Revised at Phase 8D (DECISIONS.md ADR-057):** the former "Injury
/// History" question (a clinical-intake-style segment control that expanded
/// into an ACL/Meniscus/Hamstring/Ankle/Other picker) is replaced by
/// "Training Status" — a single, non-medical three-option segment control
/// with no follow-up question.
class PlayerProfileScreen extends ConsumerStatefulWidget {
  const PlayerProfileScreen({super.key});

  @override
  ConsumerState<PlayerProfileScreen> createState() => _PlayerProfileScreenState();
}

class _PlayerProfileScreenState extends ConsumerState<PlayerProfileScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _ageController;
  late final TextEditingController _heightController;
  late final TextEditingController _weightController;
  PreferredFoot? _foot;
  PlayingPosition? _position;
  TrainingStatus? _trainingStatus;

  /// Inline validation only becomes visible once the user has tried to
  /// continue with the form incomplete — showing every required field as
  /// an error on first load, before anything is typed, would read as the
  /// screen accusing the user of a mistake they haven't made yet.
  bool _showValidation = false;

  @override
  void initState() {
    super.initState();
    final existing = ref.read(playerOnboardingControllerProvider).profile;
    _nameController = TextEditingController(text: existing.name);
    _ageController = TextEditingController(text: existing.age?.toString() ?? '');
    _heightController = TextEditingController(
      text: existing.height?.toString() ?? '',
    );
    _weightController = TextEditingController(
      text: existing.weight?.toString() ?? '',
    );
    _foot = existing.preferredFoot;
    _position = existing.position;
    _trainingStatus = existing.trainingStatus;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  PlayerProfileData get _current => PlayerProfileData(
    name: _nameController.text.trim(),
    age: int.tryParse(_ageController.text.trim()),
    height: double.tryParse(_heightController.text.trim()),
    weight: double.tryParse(_weightController.text.trim()),
    preferredFoot: _foot,
    position: _position,
    trainingStatus: _trainingStatus,
  );

  void _continue() {
    if (!_current.isComplete) {
      setState(() => _showValidation = true);
      return;
    }
    ref.read(playerOnboardingControllerProvider.notifier).setProfile(_current);
    context.go(OnboardingRoute.permissionsPath(WorkspaceType.player));
  }

  /// A small Caption-size, Oxide-Rose error line beneath a selection
  /// control (segment control / chip group) that has no built-in
  /// `errorText` slot the way [VikzarTextField] does — same error
  /// treatment ([DESIGN_SPECIFICATION.md §18](../../../../../../DESIGN_SPECIFICATION.md)'s
  /// Text Fields error state), just not attached to a field border.
  Widget? _selectionError(BuildContext context, bool show) {
    if (!show) return null;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: SpacingTokens.space4),
      child: Text(
        'Required',
        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showErrors = _showValidation;
    final current = _current;

    return OnboardingStepScaffold(
      headline: 'Tell us about you.',
      showBackButton: true,
      onContinue: _continue,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          VikzarTextField(
            label: 'Name',
            controller: _nameController,
            errorText: showErrors && current.name.trim().isEmpty ? 'Required' : null,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: SpacingTokens.space16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: VikzarTextField(
                  label: 'Age',
                  controller: _ageController,
                  keyboardType: TextInputType.number,
                  errorText: showErrors && current.age == null ? 'Required' : null,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: SpacingTokens.space16),
              Expanded(
                child: VikzarTextField(
                  label: 'Height (cm)',
                  controller: _heightController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  errorText: showErrors && current.height == null ? 'Required' : null,
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: SpacingTokens.space16),
          VikzarTextField(
            label: 'Weight (kg)',
            controller: _weightController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            errorText: showErrors && current.weight == null ? 'Required' : null,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: SpacingTokens.space24),
          Text('Preferred Foot', style: theme.textTheme.titleSmall),
          const SizedBox(height: SpacingTokens.space8),
          VikzarSegmentedControl<PreferredFoot>(
            options: PreferredFoot.values,
            labelBuilder: (foot) => foot.label,
            selected: _foot,
            onChanged: (value) => setState(() => _foot = value),
          ),
          ?_selectionError(context, showErrors && _foot == null),
          const SizedBox(height: SpacingTokens.space24),
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
          ?_selectionError(context, showErrors && _position == null),
          const SizedBox(height: SpacingTokens.space24),
          Text('Training Status', style: theme.textTheme.titleSmall),
          const SizedBox(height: SpacingTokens.space8),
          VikzarSegmentedControl<TrainingStatus>(
            options: TrainingStatus.values,
            labelBuilder: (status) => status.label,
            selected: _trainingStatus,
            onChanged: (value) => setState(() => _trainingStatus = value),
          ),
          ?_selectionError(context, showErrors && _trainingStatus == null),
        ],
      ),
    );
  }
}
