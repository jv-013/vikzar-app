import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failure_message_mapper.dart';
import '../../../../design_system/tokens/spacing.dart';
import '../../data/repositories/team_repository_impl.dart';

/// Real invite-code generation (`createTeamInvite`) — shared by Coach
/// Home's Quick Actions and Profile's "Invite Players" row rather than
/// duplicated in both. Previously each caller showed the team's raw
/// `teamId` as if it were an invite code, with no backend behind it.
void showInvitePlayersDialog(BuildContext context, String teamId) {
  showDialog<void>(
    context: context,
    builder: (context) => _InvitePlayersDialog(teamId: teamId),
  );
}

class _InvitePlayersDialog extends ConsumerStatefulWidget {
  const _InvitePlayersDialog({required this.teamId});

  final String teamId;

  @override
  ConsumerState<_InvitePlayersDialog> createState() => _InvitePlayersDialogState();
}

class _InvitePlayersDialogState extends ConsumerState<_InvitePlayersDialog> {
  String? _code;
  String? _errorText;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool regenerate = false}) async {
    setState(() {
      _isLoading = true;
      _errorText = null;
    });
    final result = await ref
        .read(teamRepositoryProvider)
        .createTeamInvite(teamId: widget.teamId, regenerate: regenerate);
    if (!mounted) return;
    result.fold(
      onSuccess: (code) => setState(() {
        _code = code;
        _isLoading = false;
      }),
      onFailure: (failure) => setState(() {
        _errorText = FailureMessageMapper.toMessage(failure);
        _isLoading = false;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Invite Players'),
      content: SizedBox(
        width: 280,
        child: _isLoading
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: SpacingTokens.space20),
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_errorText != null)
                    Text(
                      _errorText!,
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error),
                    )
                  else ...[
                    Text(
                      'Share this code — a player enters it to join your team:',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: SpacingTokens.space12),
                    SelectableText(
                      _code ?? '',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => _load(regenerate: true),
          child: const Text('New Code'),
        ),
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Done')),
      ],
    );
  }
}
