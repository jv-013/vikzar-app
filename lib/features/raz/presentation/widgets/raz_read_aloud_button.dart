import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/providers/raz_speech_providers.dart';

/// Voice as a platform capability, not just a chat feature — any
/// RAZ-generated text (the Daily Brief today; reports, alerts, coach
/// summaries, future notifications later) gets this exact same button.
/// Never auto-reads anything; only speaks when tapped, and only this
/// exact [text] — never a duplicate speech pipeline, just the same
/// [razSpeechSynthesizerProvider] the conversational voice path already
/// uses. Sharing one synthesizer instance means tapping this while a
/// conversational reply is speaking correctly interrupts it (the
/// synthesizer's own cancel-then-speak model), with no coordination
/// code needed here.
class RazReadAloudButton extends ConsumerStatefulWidget {
  const RazReadAloudButton({super.key, required this.text});

  final String text;

  @override
  ConsumerState<RazReadAloudButton> createState() => _RazReadAloudButtonState();
}

class _RazReadAloudButtonState extends ConsumerState<RazReadAloudButton> {
  bool _speakingThis = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return IconButton(
      icon: Icon(_speakingThis ? Symbols.stop_circle : Symbols.play_circle),
      color: theme.colorScheme.secondary,
      tooltip: _speakingThis ? 'Stop' : 'Read aloud',
      onPressed: widget.text.trim().isEmpty ? null : _toggle,
    );
  }

  Future<void> _toggle() async {
    final synthesizer = ref.read(razSpeechSynthesizerProvider);
    if (_speakingThis) {
      await synthesizer.stop();
      if (mounted) setState(() => _speakingThis = false);
      return;
    }
    setState(() => _speakingThis = true);
    await synthesizer.speak(widget.text);
    if (mounted) setState(() => _speakingThis = false);
  }
}
