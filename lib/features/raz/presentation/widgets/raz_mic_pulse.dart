import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../design_system/tokens/motion.dart';

enum RazMicPulseVisualState { idle, listening, thinking, speaking }

/// The large mic affordance at the centre of Voice Mode — this app's
/// first looping animation, and its first [MediaQuery.disableAnimations]
/// (reduced motion) consumer. Isolated in its own widget specifically so
/// both precedents live in one small, directly-reviewable place rather
/// than buried inside the larger sheet.
class RazMicPulse extends StatefulWidget {
  const RazMicPulse({super.key, required this.visualState, this.onTap});

  final RazMicPulseVisualState visualState;
  final VoidCallback? onTap;

  @override
  State<RazMicPulse> createState() => _RazMicPulseState();
}

class _RazMicPulseState extends State<RazMicPulse> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: MotionTokens.pulseLoop);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(RazMicPulse oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visualState != widget.visualState) _syncAnimation();
  }

  void _syncAnimation() {
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (widget.visualState == RazMicPulseVisualState.listening && !reduceMotion) {
      _controller.repeat(reverse: true);
    } else {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = switch (widget.visualState) {
      RazMicPulseVisualState.idle => theme.colorScheme.onSurfaceVariant,
      RazMicPulseVisualState.listening => theme.colorScheme.error,
      RazMicPulseVisualState.thinking => theme.colorScheme.secondary,
      RazMicPulseVisualState.speaking => theme.colorScheme.secondary,
    };
    final icon = switch (widget.visualState) {
      RazMicPulseVisualState.idle => Symbols.mic_none,
      RazMicPulseVisualState.listening => Symbols.mic,
      RazMicPulseVisualState.thinking => Symbols.self_improvement,
      RazMicPulseVisualState.speaking => Symbols.graphic_eq,
    };
    final label = switch (widget.visualState) {
      RazMicPulseVisualState.idle => 'Tap to talk to RAZ',
      RazMicPulseVisualState.listening => 'Listening',
      RazMicPulseVisualState.thinking => 'RAZ is thinking',
      RazMicPulseVisualState.speaking => 'RAZ is speaking',
    };

    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final scale = widget.visualState == RazMicPulseVisualState.listening
                ? 1.0 + (_controller.value * 0.12)
                : 1.0;
            return Transform.scale(scale: scale, child: child);
          },
          child: Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.16),
              border: Border.all(color: color, width: 2),
            ),
            child: Icon(icon, size: 40, color: color),
          ),
        ),
      ),
    );
  }
}
