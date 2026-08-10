import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/errors/failure_message_mapper.dart';
import '../../../../core/result/result.dart';
import '../../../../design_system/components/vikzar_bottom_sheet.dart';
import '../../../../design_system/components/vikzar_button.dart';
import '../../../../design_system/components/vikzar_chip_group.dart';
import '../../../../design_system/components/vikzar_expandable_section.dart';
import '../../../../design_system/components/vikzar_segmented_control.dart';
import '../../../../design_system/components/vikzar_text_field.dart';
import '../../../../design_system/tokens/spacing.dart';
import '../../../../shared/models/coach_profile.dart';
import '../../../../shared/models/player_profile.dart';
import '../../../../shared/models/workspace_type.dart';
import '../../../../shared/providers/current_app_user_provider.dart';
import '../../../../shared/providers/current_uid_provider.dart';
import '../../../../shared/repositories/user_repository_impl.dart';

/// Edit Profile — DESIGN_SPECIFICATION.md §19.2's "each row tap-through to
/// an inline edit sheet," consolidated here into one sheet for every field
/// rather than one sheet per row (the field set is small enough that
/// splitting it further would be more taps, not less friction).
///
/// **Revised at Phase 8B:** writes directly to `users/{uid}` in Firestore
/// (`displayName` plus the workspace's profile map) via [UserRepository],
/// per DECISIONS.md ADR-051 — replacing Phase 7's in-memory
/// onboarding-controller edit.
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
  late final TextEditingController _heightController;
  late final TextEditingController _weightController;
  PreferredFoot? _foot;
  PlayingPosition? _position;
  PlayingLevel? _level;
  TrainingStatus? _trainingStatus;
  Set<InjuryType> _injuryTypes = {};
  RecoveryTimeframe? _recoveryTimeframe;
  bool _isSaving = false;
  Failure? _failure;

  late PlayerProfile _current;

  @override
  void initState() {
    super.initState();
    final user = ref.read(currentAppUserProvider);
    _current = user?.playerProfile ?? const PlayerProfile();
    _nameController = TextEditingController(text: user?.displayName ?? '');
    _ageController = TextEditingController(text: _current.age?.toString() ?? '');
    _heightController = TextEditingController(
      text: _current.heightCm?.toStringAsFixed(0) ?? '',
    );
    _weightController = TextEditingController(
      text: _current.weightKg?.toStringAsFixed(0) ?? '',
    );
    _foot = _current.preferredFoot;
    _position = _current.position;
    _level = _current.level;
    _trainingStatus = _current.trainingStatus;
    _injuryTypes = _current.injuryTypes;
    _recoveryTimeframe = _current.recoveryTimeframe;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  bool get _showInjuryDetail =>
      _trainingStatus != null && _trainingStatus != TrainingStatus.fullyAvailable;

  Future<void> _save() async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;

    setState(() {
      _isSaving = true;
      _failure = null;
    });

    final repository = ref.read(userRepositoryProvider);
    final displayNameResult = await repository.updateDisplayName(
      uid: uid,
      displayName: _nameController.text.trim(),
    );
    if (displayNameResult.isFailure) {
      _handleFailure(displayNameResult);
      return;
    }

    final profileResult = await repository.updatePlayerProfile(
      uid: uid,
      profile: PlayerProfile(
        level: _level,
        age: int.tryParse(_ageController.text.trim()),
        heightCm: double.tryParse(_heightController.text.trim()),
        weightKg: double.tryParse(_weightController.text.trim()),
        preferredFoot: _foot,
        position: _position,
        trainingStatus: _trainingStatus,
        // Injury detail is only ever meaningful — and only ever shown for
        // editing — once Training Status is something other than "Fully
        // Available" (DECISIONS.md ADR-060). Clearing Training Status back
        // to Fully Available clears any previously-set injury detail too,
        // rather than leaving stale values behind that the UI no longer
        // shows a path to edit.
        injuryTypes: _showInjuryDetail ? _injuryTypes : const {},
        recoveryTimeframe: _showInjuryDetail ? _recoveryTimeframe : null,
      ),
    );
    if (profileResult.isFailure) {
      _handleFailure(profileResult);
      return;
    }

    if (mounted) Navigator.of(context).pop();
  }

  void _handleFailure(Result<void> result) {
    if (!mounted) return;
    setState(() {
      _isSaving = false;
      _failure = result.fold(
        onSuccess: (_) => null,
        onFailure: (Failure failure) => failure,
      );
    });
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
            VikzarTextField(
              label: 'Name',
              controller: _nameController,
              enabled: !_isSaving,
            ),
            const SizedBox(height: SpacingTokens.space16),
            VikzarTextField(
              label: 'Age',
              controller: _ageController,
              keyboardType: TextInputType.number,
              enabled: !_isSaving,
            ),
            const SizedBox(height: SpacingTokens.space16),
            Row(
              children: [
                Expanded(
                  child: VikzarTextField(
                    label: 'Height (cm)',
                    controller: _heightController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    enabled: !_isSaving,
                  ),
                ),
                const SizedBox(width: SpacingTokens.space16),
                Expanded(
                  child: VikzarTextField(
                    label: 'Weight (kg)',
                    controller: _weightController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    enabled: !_isSaving,
                  ),
                ),
              ],
            ),
            const SizedBox(height: SpacingTokens.space20),
            Text('Level', style: theme.textTheme.titleSmall),
            const SizedBox(height: SpacingTokens.space8),
            VikzarSegmentedControl<PlayingLevel>(
              options: PlayingLevel.values,
              labelBuilder: (level) => level.label,
              selected: _level,
              onChanged: (value) => setState(() => _level = value),
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
            const SizedBox(height: SpacingTokens.space20),
            Text('Training Status', style: theme.textTheme.titleSmall),
            const SizedBox(height: SpacingTokens.space8),
            VikzarSegmentedControl<TrainingStatus>(
              options: TrainingStatus.values,
              labelBuilder: (status) => status.label,
              selected: _trainingStatus,
              onChanged: (value) => setState(() => _trainingStatus = value),
            ),
            VikzarExpandableSection(
              expanded: _showInjuryDetail,
              child: Padding(
                padding: const EdgeInsets.only(top: SpacingTokens.space20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Injury Type', style: theme.textTheme.titleSmall),
                    const SizedBox(height: SpacingTokens.space8),
                    VikzarChipGroup<InjuryType>(
                      options: InjuryType.values,
                      labelBuilder: (type) => type.label,
                      selected: _injuryTypes,
                      onChanged: (selection) => setState(() => _injuryTypes = selection),
                    ),
                    const SizedBox(height: SpacingTokens.space20),
                    Text('Expected Recovery', style: theme.textTheme.titleSmall),
                    const SizedBox(height: SpacingTokens.space8),
                    VikzarChipGroup<RecoveryTimeframe>(
                      options: RecoveryTimeframe.values,
                      labelBuilder: (timeframe) => timeframe.label,
                      selected: {?_recoveryTimeframe},
                      multiSelect: false,
                      onChanged: (selection) => setState(
                        () => _recoveryTimeframe =
                            selection.isEmpty ? null : selection.first,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_failure != null) ...[
              const SizedBox(height: SpacingTokens.space12),
              Text(
                FailureMessageMapper.toMessage(_failure!),
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error),
              ),
            ],
            const SizedBox(height: SpacingTokens.space24),
            Align(
              alignment: Alignment.centerRight,
              child: VikzarButton(
                label: 'Save',
                isLoading: _isSaving,
                onPressed: _isSaving ? null : _save,
              ),
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
  late final TextEditingController _licenseController;
  late final TextEditingController _academyController;
  bool _isSaving = false;
  Failure? _failure;

  late CoachProfile _current;

  @override
  void initState() {
    super.initState();
    final user = ref.read(currentAppUserProvider);
    _current = user?.coachProfile ?? const CoachProfile();
    _nameController = TextEditingController(text: user?.displayName ?? '');
    _ageController = TextEditingController(text: _current.age?.toString() ?? '');
    _titleController = TextEditingController(text: _current.title ?? '');
    _clubController = TextEditingController(text: _current.club ?? '');
    _licenseController = TextEditingController(text: _current.license ?? '');
    _academyController = TextEditingController(text: _current.academy ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _titleController.dispose();
    _clubController.dispose();
    _licenseController.dispose();
    _academyController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;

    setState(() {
      _isSaving = true;
      _failure = null;
    });

    final repository = ref.read(userRepositoryProvider);
    final displayNameResult = await repository.updateDisplayName(
      uid: uid,
      displayName: _nameController.text.trim(),
    );
    if (displayNameResult.isFailure) {
      _handleFailure(displayNameResult);
      return;
    }

    final profileResult = await repository.updateCoachProfile(
      uid: uid,
      profile: CoachProfile(
        level: _current.level,
        age: int.tryParse(_ageController.text.trim()),
        title: _titleController.text.trim(),
        club: _clubController.text.trim(),
        license: _licenseController.text.trim(),
        academy: _academyController.text.trim(),
      ),
    );
    if (profileResult.isFailure) {
      _handleFailure(profileResult);
      return;
    }

    if (mounted) Navigator.of(context).pop();
  }

  void _handleFailure(Result<void> result) {
    if (!mounted) return;
    setState(() {
      _isSaving = false;
      _failure = result.fold(
        onSuccess: (_) => null,
        onFailure: (Failure failure) => failure,
      );
    });
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
            VikzarTextField(label: 'Name', controller: _nameController, enabled: !_isSaving),
            const SizedBox(height: SpacingTokens.space16),
            VikzarTextField(
              label: 'Age',
              controller: _ageController,
              keyboardType: TextInputType.number,
              enabled: !_isSaving,
            ),
            const SizedBox(height: SpacingTokens.space16),
            VikzarTextField(
              label: 'Role',
              controller: _titleController,
              enabled: !_isSaving,
            ),
            const SizedBox(height: SpacingTokens.space16),
            VikzarTextField(
              label: 'Club',
              controller: _clubController,
              enabled: !_isSaving,
            ),
            const SizedBox(height: SpacingTokens.space16),
            VikzarTextField(
              label: 'Coaching License',
              controller: _licenseController,
              enabled: !_isSaving,
            ),
            const SizedBox(height: SpacingTokens.space16),
            VikzarTextField(
              label: 'Academy',
              controller: _academyController,
              enabled: !_isSaving,
            ),
            if (_failure != null) ...[
              const SizedBox(height: SpacingTokens.space12),
              Text(
                FailureMessageMapper.toMessage(_failure!),
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error),
              ),
            ],
            const SizedBox(height: SpacingTokens.space24),
            Align(
              alignment: Alignment.centerRight,
              child: VikzarButton(
                label: 'Save',
                isLoading: _isSaving,
                onPressed: _isSaving ? null : _save,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
