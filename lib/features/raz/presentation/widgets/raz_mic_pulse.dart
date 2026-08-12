import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../design_system/tokens/motion.dart';

/// The mic-pulse visual states — **RC2.1:** Added `error` and
/// `wakeWordListening` for the complete RAZ voice lifecycle.
enum RazMicPulseVisualState { idle, wakeWordListening, listening, thinking, speaking, error }

/// The compact mic affordance — used in the input bar at the bottom of
/// the RAZ screen. The RAZ Orb (`raz_orb.dart`) is now the primary
/// visual identity; this widget is secondary, providing a small tappable
/// mic icon.
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
      RazMicPulseVisualState.wakeWordListening => theme.colorScheme.secondary,
      RazMicPulseVisualState.listening => theme.colorScheme.error,
      RazMicPulseVisualState.thinking => theme.colorScheme.secondary,
      RazMicPulseVisualState.speaking => theme.colorScheme.secondary,
      RazMicPulseVisualState.error => theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
    };
    final icon = switch (widget.visualState) {
      RazMicPulseVisualState.idle => Symbols.mic_none,
      RazMicPulseVisualState.wakeWordListening => Symbols.mic_none,
      RazMicPulseVisualState.listening => Symbols.mic,
      RazMicPulseVisualState.thinking => Symbols.self_improvement,
      RazMicPulseVisualState.speaking => Symbols.graphic_eq,
      RazMicPulseVisualState.error => Symbols.mic_off,
    };
    final label = switch (widget.visualState) {
      RazMicPulseVisualState.idle => 'Tap to talk to RAZ',
      RazMicPulseVisualState.wakeWordListening => 'Say "Hey Raz"',
      RazMicPulseVisualState.listening => 'Listening',
      RazMicPulseVisualState.thinking => 'RAZ is thinking',
      RazMicPulseVisualState.speaking => 'RAZ is speaking',
      RazMicPulseVisualState.error => 'Mic unavailable',
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
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.12),
            ),
            child: Icon(icon, size: 24, color: color),
          ),
        ),
      ),
    );
  }
}
