import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../design_system/components/vikzar_segmented_control.dart';
import '../../../../design_system/components/vikzar_text_field.dart';
import '../../../../design_system/tokens/spacing.dart';
import '../../../../routing/app_router.dart';
import '../../../onboarding/domain/models/coach_onboarding_data.dart';
import '../../../onboarding/presentation/widgets/onboarding_step_scaffold.dart';

/// "Become a Coach" — DESIGN_SPECIFICATION.md §13's Phase 7 addition:
/// reached from the profile sheet by a Player-only account. Collects
/// Coaching Level, Club/Academy Name, Current Role, and an optional
/// Organization Email, then submits to — nowhere. **No backend exists to
/// act on this request** (no Cloud Function, no Firestore write); this is
/// a complete, honest UI flow ending in a submitted-for-review
/// confirmation, never an immediate grant. See
/// [DECISIONS.md ADR-049](../../../../../DECISIONS.md#adr-049-become-a-coach-is-a-placeholder-request-flow-with-no-real-approval).
///
/// Reuses [CoachingLevel] from the Coach onboarding domain model rather
/// than defining a near-duplicate enum — the same three tiers apply here.
class BecomeACoachScreen extends ConsumerStatefulWidget {
  const BecomeACoachScreen({super.key});

  @override
  ConsumerState<BecomeACoachScreen> createState() => _BecomeACoachScreenState();
}

class _BecomeACoachScreenState extends ConsumerState<BecomeACoachScreen> {
  CoachingLevel? _level;
  final _clubController = TextEditingController();
  final _roleController = TextEditingController();
  final _orgEmailController = TextEditingController();

  @override
  void dispose() {
    _clubController.dispose();
    _roleController.dispose();
    _orgEmailController.dispose();
    super.dispose();
  }

  bool get _isComplete =>
      _level != null &&
      _clubController.text.trim().isNotEmpty &&
      _roleController.text.trim().isNotEmpty;

  void _submit() {
    context.push(AppRoute.becomeCoachCompletePath);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return OnboardingStepScaffold(
      headline: 'Become a Coach',
      body: "Tell us about your coaching role. We'll review your request — "
          'this does not grant Coach access immediately.',
      showBackButton: true,
      continueLabel: 'Submit',
      onContinue: _isComplete ? _submit : null,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Coaching Level', style: theme.textTheme.titleSmall),
          const SizedBox(height: SpacingTokens.space8),
          VikzarSegmentedControl<CoachingLevel>(
            options: CoachingLevel.values,
            labelBuilder: (level) => level.label,
            selected: _level,
            onChanged: (value) => setState(() => _level = value),
          ),
          const SizedBox(height: SpacingTokens.space24),
          VikzarTextField(
            label: 'Club / Academy Name',
            controller: _clubController,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: SpacingTokens.space16),
          VikzarTextField(
            label: 'Current Role',
            controller: _roleController,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: SpacingTokens.space16),
          VikzarTextField(
            label: 'Organization Email (optional)',
            controller: _orgEmailController,
            keyboardType: TextInputType.emailAddress,
          ),
        ],
      ),
    );
  }
}
