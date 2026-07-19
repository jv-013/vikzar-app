import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../design_system/components/vikzar_segmented_control.dart';
import '../../../../../routing/app_router.dart';
import '../../../../../shared/models/workspace_type.dart';
import '../../../domain/models/coach_onboarding_data.dart';
import '../../controllers/coach_onboarding_controller.dart';
import '../../widgets/onboarding_step_scaffold.dart';

/// Step 2 (Coach) — DESIGN_SPECIFICATION.md §19.1: "the identical visual
/// treatment relabeled," keeping one consistent design language across
/// both onboarding paths.
class CoachLevelScreen extends ConsumerWidget {
  const CoachLevelScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final level = ref.watch(
      coachOnboardingControllerProvider.select((data) => data.level),
    );
    final controller = ref.read(coachOnboardingControllerProvider.notifier);

    return OnboardingStepScaffold(
      headline: "What's your level?",
      content: VikzarSegmentedControl<CoachingLevel>(
        options: CoachingLevel.values,
        labelBuilder: (level) => level.label,
        selected: level,
        onChanged: controller.setLevel,
      ),
      onContinue: level == null
          ? null
          : () => context.go(OnboardingRoute.profilePath(WorkspaceType.coach)),
    );
  }
}
