import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../tokens/radius.dart';
import '../tokens/spacing.dart';

/// A row of individually-boxed digit inputs behaving as one field —
/// DESIGN_SPECIFICATION.md §19.1's 6-digit code step. Auto-advances focus
/// on entry, moves back on backspace from an empty box, and distributes a
/// paste (or platform autofill) across boxes from wherever focus lands.
class VikzarOtpField extends StatefulWidget {
  const VikzarOtpField({
    super.key,
    this.length = 6,
    required this.onCompleted,
    this.onChanged,
    this.enabled = true,
    this.errorText,
  });

  final int length;
  final ValueChanged<String> onCompleted;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  final String? errorText;

  @override
  State<VikzarOtpField> createState() => _VikzarOtpFieldState();
}

class _VikzarOtpFieldState extends State<VikzarOtpField> {
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(widget.length, (_) => TextEditingController());
    _focusNodes = List.generate(widget.length, (_) => FocusNode());
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  String get _value => _controllers.map((c) => c.text).join();

  void _handleChanged(int index, String rawValue) {
    final digitsOnly = rawValue.replaceAll(RegExp(r'\D'), '');

    if (digitsOnly.length > 1) {
      _distribute(index, digitsOnly);
      return;
    }

    _controllers[index].text = digitsOnly;
    if (digitsOnly.isNotEmpty && index < widget.length - 1) {
      _focusNodes[index + 1].requestFocus();
    }
    _notify();
  }

  void _distribute(int startIndex, String digits) {
    for (var i = 0; i < digits.length && startIndex + i < widget.length; i++) {
      _controllers[startIndex + i].text = digits[i];
    }
    final nextEmpty = _controllers.indexWhere((c) => c.text.isEmpty);
    if (nextEmpty == -1) {
      _focusNodes[widget.length - 1].unfocus();
    } else {
      _focusNodes[nextEmpty].requestFocus();
    }
    _notify();
  }

  void _handleBackspace(int index) {
    if (_controllers[index].text.isNotEmpty) return;
    if (index == 0) return;
    _focusNodes[index - 1].requestFocus();
    _controllers[index - 1].clear();
    _notify();
  }

  void _notify() {
    final value = _value;
    widget.onChanged?.call(value);
    if (value.length == widget.length) {
      widget.onCompleted(value);
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasError = widget.errorText != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(widget.length, (index) {
            final borderColor = hasError
                ? colorScheme.error
                : _focusNodes[index].hasFocus
                ? colorScheme.primary
                : colorScheme.onSurface.withValues(alpha: 0.24);

            return SizedBox(
              width: 44,
              height: 56,
              child: KeyboardListener(
                focusNode: FocusNode(skipTraversal: true, canRequestFocus: false),
                onKeyEvent: (event) {
                  if (event is KeyDownEvent &&
                      event.logicalKey == LogicalKeyboardKey.backspace) {
                    _handleBackspace(index);
                  }
                },
                child: TextField(
                  controller: _controllers[index],
                  focusNode: _focusNodes[index],
                  enabled: widget.enabled,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  autofillHints: index == 0 ? const [AutofillHints.oneTimeCode] : null,
                  // Deliberately widget.length, not 1: a paste or platform
                  // autofill can land the whole code in a single box's
                  // onChanged before it's manually redistributed below —
                  // maxLength: 1 would silently truncate it first.
                  maxLength: widget.length,
                  style: theme.textTheme.titleLarge,
                  onChanged: (value) => _handleChanged(index, value),
                  decoration: InputDecoration(
                    counterText: '',
                    contentPadding: EdgeInsets.zero,
                    border: OutlineInputBorder(
                      borderRadius: RadiusTokens.smallRadius,
                      borderSide: BorderSide(color: borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: RadiusTokens.smallRadius,
                      borderSide: BorderSide(color: borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: RadiusTokens.smallRadius,
                      borderSide: BorderSide(color: colorScheme.primary, width: 2),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
        if (hasError) ...[
          const SizedBox(height: SpacingTokens.space8),
          Text(
            widget.errorText!,
            style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.error),
          ),
        ],
      ],
    );
  }
}
