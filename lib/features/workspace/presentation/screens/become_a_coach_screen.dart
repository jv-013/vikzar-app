import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/errors/failure_message_mapper.dart';
import '../../../../design_system/components/vikzar_segmented_control.dart';
import '../../../../design_system/components/vikzar_text_field.dart';
import '../../../../design_system/tokens/spacing.dart';
import '../../../../routing/app_router.dart';
import '../../../../shared/providers/current_app_user_provider.dart';
import '../../../../shared/providers/current_uid_provider.dart';
import '../../../onboarding/domain/models/coach_onboarding_data.dart';
import '../../../onboarding/presentation/widgets/onboarding_step_scaffold.dart';
import '../../data/repositories/coach_request_repository_impl.dart';
import '../../domain/models/coach_request.dart';

/// "Become a Coach" — DESIGN_SPECIFICATION.md §13's Phase 7 addition:
/// reached from the profile sheet by a Player-only account. Collects
/// Coaching Level, Club/Academy Name, Current Role, and an optional
/// Club Email, then submits a `coachRequests` document to
/// Firestore (**Revised at Phase 8B**, DECISIONS.md ADR-051) — there is
/// still **no admin-approval flow**: submitting a request never grants
/// Coach access immediately, per
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
  bool _isSubmitting = false;
  Failure? _failure;

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

  Future<void> _submit() async {
    if (_isSubmitting) return;
    final uid = ref.read(currentUidProvider);
    final user = ref.read(currentAppUserProvider);
    if (uid == null || user == null || _level == null) return;

    setState(() {
      _isSubmitting = true;
      _failure = null;
    });

    final result = await ref.read(coachRequestRepositoryProvider).submit(
      CoachRequest(
        uid: uid,
        email: user.email,
        displayName: user.displayName ?? '',
        level: _level!,
        club: _clubController.text.trim(),
        title: _roleController.text.trim(),
        orgEmail: _orgEmailController.text.trim().isEmpty
            ? null
            : _orgEmailController.text.trim(),
      ),
    );

    if (!mounted) return;
    result.fold(
      onSuccess: (_) => context.push(AppRoute.becomeCoachCompletePath),
      onFailure: (failure) => setState(() {
        _isSubmitting = false;
        _failure = failure;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final errorText = _failure == null ? null : FailureMessageMapper.toMessage(_failure!);

    return OnboardingStepScaffold(
      headline: 'Become a Coach',
      body: "Tell us about your coaching role. We'll review your request — "
          'this does not grant Coach access immediately.',
      showBackButton: true,
      continueLabel: 'Submit',
      isLoading: _isSubmitting,
      onContinue: _isComplete && !_isSubmitting ? _submit : null,
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
            enabled: !_isSubmitting,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: SpacingTokens.space16),
          VikzarTextField(
            label: 'Current Role',
            controller: _roleController,
            enabled: !_isSubmitting,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: SpacingTokens.space16),
          VikzarTextField(
            label: 'Club Email (optional)',
            controller: _orgEmailController,
            enabled: !_isSubmitting,
            keyboardType: TextInputType.emailAddress,
          ),
          if (errorText != null) ...[
            const SizedBox(height: SpacingTokens.space16),
            Text(
              errorText,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }
}
