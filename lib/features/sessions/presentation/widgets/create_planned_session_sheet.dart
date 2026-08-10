import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/errors/failure_message_mapper.dart';
import '../../../../design_system/components/vikzar_chip_group.dart';
import '../../../../design_system/components/vikzar_section_header.dart';
import '../../../../design_system/components/vikzar_segmented_control.dart';
import '../../../../design_system/components/vikzar_text_field.dart';
import '../../../../design_system/tokens/spacing.dart';
import '../../../team/presentation/controllers/team_roster_controller.dart';
import '../../domain/models/planned_session.dart';
import '../controllers/planned_sessions_controller.dart';

const _durationOptions = [30, 45, 60, 90, 120];

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
  final _locationController = TextEditingController();
  PlannedSessionType _type = PlannedSessionType.training;
  DateTime? _scheduledAt;
  int? _durationMinutes;
  Set<String> _selectedPlayerIds = {};
  bool _isSubmitting = false;
  Failure? _failure;

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    _locationController.dispose();
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
    if (_isSubmitting) return;
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
      durationMinutes: _durationMinutes,
      location: _locationController.text,
      playerIds: _selectedPlayerIds.isEmpty ? null : _selectedPlayerIds.toList(),
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
      child: SingleChildScrollView(
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
          Text('Duration', style: theme.textTheme.titleSmall),
          const SizedBox(height: SpacingTokens.space8),
          VikzarSegmentedControl<int>(
            options: _durationOptions,
            labelBuilder: (minutes) => '$minutes min',
            selected: _durationMinutes,
            onChanged: (value) => setState(() => _durationMinutes = value),
          ),
          const SizedBox(height: SpacingTokens.space16),
          VikzarTextField(
            label: 'Location (optional)',
            controller: _locationController,
            enabled: !_isSubmitting,
          ),
          const SizedBox(height: SpacingTokens.space16),
          VikzarTextField(
            label: 'Notes (optional)',
            controller: _notesController,
            enabled: !_isSubmitting,
          ),
          const SizedBox(height: SpacingTokens.space16),
          const VikzarSectionHeader('Players (optional — leave empty for whole squad)'),
          _PlayerSelector(
            teamId: widget.teamId,
            selected: _selectedPlayerIds,
            onChanged: (value) => setState(() => _selectedPlayerIds = value),
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
      ),
    );
  }
}

class _PlayerSelector extends ConsumerWidget {
  const _PlayerSelector({required this.teamId, required this.selected, required this.onChanged});

  final String teamId;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final entriesAsync = ref.watch(teamRosterEntriesProvider(teamId));

    return entriesAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => Text(
        "Couldn't load your roster.",
        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
      data: (entries) {
        if (entries.isEmpty) {
          return Text(
            'No players on your roster yet.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          );
        }
        return VikzarChipGroup<String>(
          options: [for (final entry in entries) entry.member.uid],
          labelBuilder: (uid) => entries
              .firstWhere((entry) => entry.member.uid == uid)
              .member
              .displayName,
          selected: selected,
          onChanged: onChanged,
        );
      },
    );
  }
}

String _formatDateTime(DateTime dateTime) {
  final hour = dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12;
  final minute = dateTime.minute.toString().padLeft(2, '0');
  final period = dateTime.hour < 12 ? 'AM' : 'PM';
  return '${dateTime.month}/${dateTime.day}/${dateTime.year} $hour:$minute $period';
}
