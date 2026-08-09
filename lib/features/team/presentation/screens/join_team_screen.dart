import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/errors/failure_message_mapper.dart';
import '../../../../design_system/components/vikzar_button.dart';
import '../../../../design_system/components/vikzar_text_field.dart';
import '../../../../design_system/tokens/spacing.dart';
import '../../../../shared/widgets/fade_scale_in.dart';
import '../../data/repositories/team_repository_impl.dart';

/// Join Team — Phase 15. Previously there was no screen anywhere in the
/// app for a player to actually join a team: `TeamRepository.
/// joinTeamAsPlayer` existed but had zero call sites. Redeems a real
/// invite code via `joinTeamWithInvite` (Callable) — this screen never
/// touches Firestore directly.
class JoinTeamScreen extends ConsumerStatefulWidget {
  const JoinTeamScreen({super.key});

  @override
  ConsumerState<JoinTeamScreen> createState() => _JoinTeamScreenState();
}

class _JoinTeamScreenState extends ConsumerState<JoinTeamScreen> {
  final _codeController = TextEditingController();
  bool _isSubmitting = false;
  Failure? _failure;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;

    setState(() {
      _isSubmitting = true;
      _failure = null;
    });

    final result = await ref
        .read(teamRepositoryProvider)
        .joinTeamWithInvite(inviteCode: code);

    if (!mounted) return;
    result.fold(
      onSuccess: (_) => context.pop(),
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

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Join a Team')),
      body: SafeArea(
        child: FadeScaleIn(
          child: Padding(
            padding: const EdgeInsets.all(SpacingTokens.space20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Ask your coach for your team's invite code.",
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: SpacingTokens.space20),
                VikzarTextField(
                  label: 'Invite code',
                  controller: _codeController,
                  enabled: !_isSubmitting,
                  onChanged: (_) => setState(() {}),
                ),
                if (errorText != null) ...[
                  const SizedBox(height: SpacingTokens.space12),
                  Text(
                    errorText,
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error),
                  ),
                ],
                const SizedBox(height: SpacingTokens.space20),
                VikzarButton(
                  label: 'Join',
                  isLoading: _isSubmitting,
                  onPressed: _codeController.text.trim().isEmpty || _isSubmitting
                      ? null
                      : _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
