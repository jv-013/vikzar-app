import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../design_system/components/vikzar_text_field.dart';
import '../../../../../design_system/tokens/spacing.dart';
import '../../../../../routing/app_router.dart';
import '../../../../../shared/models/workspace_type.dart';
import '../../../domain/models/coach_onboarding_data.dart';
import '../../controllers/coach_onboarding_controller.dart';
import '../../widgets/onboarding_step_scaffold.dart';

/// Step 3 (Coach) — DESIGN_SPECIFICATION.md §19.1: Name, Age, Coaching
/// Title/Role, Club/Organization.
class CoachProfileScreen extends ConsumerStatefulWidget {
  const CoachProfileScreen({super.key});

  @override
  ConsumerState<CoachProfileScreen> createState() => _CoachProfileScreenState();
}

class _CoachProfileScreenState extends ConsumerState<CoachProfileScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _ageController;
  late final TextEditingController _titleController;
  late final TextEditingController _clubController;

  @override
  void initState() {
    super.initState();
    final existing = ref.read(coachOnboardingControllerProvider).profile;
    _nameController = TextEditingController(text: existing.name);
    _ageController = TextEditingController(text: existing.age?.toString() ?? '');
    _titleController = TextEditingController(text: existing.title);
    _clubController = TextEditingController(text: existing.club);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _titleController.dispose();
    _clubController.dispose();
    super.dispose();
  }

  CoachProfileData get _current => CoachProfileData(
    name: _nameController.text.trim(),
    age: int.tryParse(_ageController.text.trim()),
    title: _titleController.text.trim(),
    club: _clubController.text.trim(),
  );

  void _continue() {
    ref.read(coachOnboardingControllerProvider.notifier).setProfile(_current);
    context.go(OnboardingRoute.permissionsPath(WorkspaceType.coach));
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingStepScaffold(
      headline: 'Tell us about you.',
      showBackButton: true,
      onContinue: _current.isComplete ? _continue : null,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          VikzarTextField(
            label: 'Name',
            controller: _nameController,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: SpacingTokens.space16),
          VikzarTextField(
            label: 'Age',
            controller: _ageController,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: SpacingTokens.space16),
          VikzarTextField(
            label: 'Coaching Title/Role',
            controller: _titleController,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: SpacingTokens.space16),
          VikzarTextField(
            label: 'Club/Organization (optional)',
            controller: _clubController,
          ),
        ],
      ),
    );
  }
}
