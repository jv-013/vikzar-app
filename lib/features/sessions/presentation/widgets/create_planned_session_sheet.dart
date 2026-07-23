import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/errors/failure_message_mapper.dart';
import '../../../../design_system/components/vikzar_segmented_control.dart';
import '../../../../design_system/components/vikzar_text_field.dart';
import '../../../../design_system/tokens/spacing.dart';
import '../../domain/models/planned_session.dart';
import '../controllers/planned_sessions_controller.dart';

/// Phase 13 §5's "Create Session" — the UI exposes this action, but the
/// frontend never writes `plannedSessions` directly: submitting calls
/// `createPlannedSession` (the Callable Cloud Function). Presented via
/// `VikzarBottomSheet.show`, matching this codebase's established sheet
/// pattern (`workspace_switch_sheet.dart` et al.) rather than a full
/// pushed screen for a short, single-purpose form.
class CreatePlannedSessionSheet extends ConsumerStatefulWidget {
  const CreatePlannedSessionSheet({super.key, required this.teamId});

  final String teamId;

  @override
  ConsumerState<CreatePlannedSessionSheet> createState() => _CreatePlannedSessionSheetState();
}

class _CreatePlannedSessionSheetState extends ConsumerState<CreatePlannedSessionSheet> {
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  PlannedSessionType _type = PlannedSessionType.training;
  DateTime? _scheduledAt;
  bool _isSubmitting = false;
  Failure? _failure;

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  bool get _isComplete => _titleController.text.trim().isNotEmpty && _scheduledAt != null;

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduledAt ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduledAt ?? now),
    );
    if (time == null) return;
    setState(() {
      _scheduledAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _submit() async {
    final scheduledAt = _scheduledAt;
    if (scheduledAt == null) return;

    setState(() {
      _isSubmitting = true;
      _failure = null;
    });

    final result = await ref.read(createPlannedSessionProvider)(
      teamId: widget.teamId,
      title: _titleController.text.trim(),
      type: _type,
      scheduledAt: scheduledAt,
      notes: _notesController.text,
    );

    if (!mounted) return;
    result.fold(
      onSuccess: (_) => Navigator.of(context).pop(true),
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

    return Padding(
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
          Text('Create Session', style: theme.textTheme.headlineSmall),
          const SizedBox(height: SpacingTokens.space20),
          VikzarTextField(
            label: 'Title',
            controller: _titleController,
            enabled: !_isSubmitting,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: SpacingTokens.space16),
          Text('Type', style: theme.textTheme.titleSmall),
          const SizedBox(height: SpacingTokens.space8),
          VikzarSegmentedControl<PlannedSessionType>(
            options: PlannedSessionType.values,
            labelBuilder: (type) => type.label,
            selected: _type,
            onChanged: (value) => setState(() => _type = value),
          ),
          const SizedBox(height: SpacingTokens.space16),
          OutlinedButton.icon(
            onPressed: _isSubmitting ? null : _pickDateTime,
            icon: const Icon(Icons.event),
            label: Text(
              _scheduledAt == null ? 'Choose date & time' : _formatDateTime(_scheduledAt!),
            ),
          ),
          const SizedBox(height: SpacingTokens.space16),
          VikzarTextField(
            label: 'Notes (optional)',
            controller: _notesController,
            enabled: !_isSubmitting,
          ),
          if (errorText != null) ...[
            const SizedBox(height: SpacingTokens.space12),
            Text(
              errorText,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error),
            ),
          ],
          const SizedBox(height: SpacingTokens.space20),
          FilledButton(
            onPressed: _isComplete && !_isSubmitting ? _submit : null,
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Create Session'),
          ),
        ],
      ),
    );
  }
}

String _formatDateTime(DateTime dateTime) {
  final hour = dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12;
  final minute = dateTime.minute.toString().padLeft(2, '0');
  final period = dateTime.hour < 12 ? 'AM' : 'PM';
  return '${dateTime.month}/${dateTime.day}/${dateTime.year} $hour:$minute $period';
}
