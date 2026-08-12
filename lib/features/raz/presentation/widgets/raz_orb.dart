import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../design_system/theme/brand_colors.dart';
import '../../../../design_system/tokens/motion.dart';

/// The visual state the RAZ Orb can represent — maps to the voice
/// lifecycle states from `RazVoiceState`.
enum RazOrbState {
  /// RAZ is present but inactive — subtle breathing animation.
  idle,

  /// Wake-word engine is passively listening — faint pulsing ring.
  wakeWordListening,

  /// Actively listening to the user — expanded orb, accent ring.
  listening,

  /// RAZ is processing the user's question — orbital dots.
  thinking,

  /// RAZ is speaking the answer — rhythmic pulse.
  speaking,

  /// An error occurred — dimmed, static orb.
  error,
}

/// The animated RAZ identity — the central visual element of the RAZ
/// screen. Uses the Vikzar brand palette (Mineral Blue primary, Oxide
/// Rose for listening accent) and respects reduced-motion preferences.
///
/// Deliberately not a Lottie/stock animation — this is Vikzar's own
/// visual language, built with standard Flutter animations.
class RazOrb extends StatefulWidget {
  const RazOrb({super.key, required this.state, this.size = 120, this.onTap});

  final RazOrbState state;
  final double size;
  final VoidCallback? onTap;

  @override
  State<RazOrb> createState() => _RazOrbState();
}

class _RazOrbState extends State<RazOrb> with TickerProviderStateMixin {
  late AnimationController _breathingController;
  late AnimationController _listeningController;
  late AnimationController _thinkingController;
  late AnimationController _speakingController;

  @override
  void initState() {
    super.initState();
    _breathingController = AnimationController(vsync: this, duration: MotionTokens.razBreathing);
    _listeningController = AnimationController(vsync: this, duration: MotionTokens.pulseLoop);
    _thinkingController = AnimationController(vsync: this, duration: MotionTokens.razOrbitLoop);
    _speakingController = AnimationController(vsync: this, duration: MotionTokens.razSpeakingPulse);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimations();
  }

  @override
  void didUpdateWidget(RazOrb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) _syncAnimations();
  }

  void _syncAnimations() {
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    _breathingController.stop();
    _listeningController.stop();
    _thinkingController.stop();
    _speakingController.stop();

    if (reduceMotion) return;

    switch (widget.state) {
      case RazOrbState.idle:
      case RazOrbState.wakeWordListening:
        _breathingController.repeat(reverse: true);
      case RazOrbState.listening:
        _listeningController.repeat(reverse: true);
      case RazOrbState.thinking:
        _thinkingController.repeat();
      case RazOrbState.speaking:
        _speakingController.repeat(reverse: true);
      case RazOrbState.error:
        break; // No animation
    }
  }

  @override
  void dispose() {
    _breathingController.dispose();
    _listeningController.dispose();
    _thinkingController.dispose();
    _speakingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: SizedBox(
        width: widget.size * 1.5,
        height: widget.size * 1.5,
        child: AnimatedBuilder(
          animation: Listenable.merge([
            _breathingController,
            _listeningController,
            _thinkingController,
            _speakingController,
          ]),
          builder: (context, child) {
            return CustomPaint(
              painter: _RazOrbPainter(
                state: widget.state,
                breathingValue: _breathingController.value,
                listeningValue: _listeningController.value,
                thinkingValue: _thinkingController.value,
                speakingValue: _speakingController.value,
                size: widget.size,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _RazOrbPainter extends CustomPainter {
  _RazOrbPainter({
    required this.state,
    required this.breathingValue,
    required this.listeningValue,
    required this.thinkingValue,
    required this.speakingValue,
    required this.size,
  });

  final RazOrbState state;
  final double breathingValue;
  final double listeningValue;
  final double thinkingValue;
  final double speakingValue;
  final double size;

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final center = canvasSize.center(Offset.zero);
    final baseRadius = size / 2;

    switch (state) {
      case RazOrbState.idle:
        _paintIdle(canvas, center, baseRadius);
      case RazOrbState.wakeWordListening:
        _paintWakeWordListening(canvas, center, baseRadius);
      case RazOrbState.listening:
        _paintListening(canvas, center, baseRadius);
      case RazOrbState.thinking:
        _paintThinking(canvas, center, baseRadius);
      case RazOrbState.speaking:
        _paintSpeaking(canvas, center, baseRadius);
      case RazOrbState.error:
        _paintError(canvas, center, baseRadius);
    }
  }

  void _paintIdle(Canvas canvas, Offset center, double baseRadius) {
    // Subtle breathing: scale 0.97 – 1.03
    final scale = 0.97 + (breathingValue * 0.06);
    final radius = baseRadius * scale;

    // Outer glow
    final glowPaint = Paint()
      ..color = BrandColors.mineralBlue.withValues(alpha: 0.08 + breathingValue * 0.04)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
    canvas.drawCircle(center, radius + 12, glowPaint);

    // Main orb
    final orbPaint = Paint()
      ..color = BrandColors.mineralBlue.withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, orbPaint);

    // Border
    final borderPaint = Paint()
      ..color = BrandColors.mineralBlue.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, radius, borderPaint);

    // Inner glow dot
    final innerGlow = Paint()
      ..color = BrandColors.mineralBlue.withValues(alpha: 0.15 + breathingValue * 0.1)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(center, radius * 0.3, innerGlow);
  }

  void _paintWakeWordListening(Canvas canvas, Offset center, double baseRadius) {
    // Same as idle but with a faint pulsing outer ring
    _paintIdle(canvas, center, baseRadius);

    // Pulsing ring — subtle awareness indicator
    final ringAlpha = 0.1 + breathingValue * 0.12;
    final ringPaint = Paint()
      ..color = BrandColors.mineralBlue.withValues(alpha: ringAlpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    final ringRadius = baseRadius + 16 + breathingValue * 4;
    canvas.drawCircle(center, ringRadius, ringPaint);
  }

  void _paintListening(Canvas canvas, Offset center, double baseRadius) {
    // Expanded orb with Oxide Rose accent
    final scale = 1.0 + (listeningValue * 0.1);
    final radius = baseRadius * scale;

    // Glow
    final glowPaint = Paint()
      ..color = BrandColors.oxideRose.withValues(alpha: 0.1 + listeningValue * 0.06)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24);
    canvas.drawCircle(center, radius + 16, glowPaint);

    // Main orb — shifted towards Oxide Rose
    final orbPaint = Paint()
      ..color = BrandColors.mineralBlue.withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, orbPaint);

    // Accent ring — Oxide Rose, responsive pulse
    final ringPaint = Paint()
      ..color = BrandColors.oxideRose.withValues(alpha: 0.5 + listeningValue * 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawCircle(center, radius + 2, ringPaint);

    // Outer breathing ring
    final outerRing = Paint()
      ..color = BrandColors.oxideRose.withValues(alpha: 0.15 + listeningValue * 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(center, radius + 12 + listeningValue * 6, outerRing);
  }

  void _paintThinking(Canvas canvas, Offset center, double baseRadius) {
    // Slightly contracted orb
    final radius = baseRadius * 0.95;

    // Soft glow
    final glowPaint = Paint()
      ..color = BrandColors.mineralBlue.withValues(alpha: 0.1)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);
    canvas.drawCircle(center, radius + 10, glowPaint);

    // Main orb
    final orbPaint = Paint()
      ..color = BrandColors.mineralBlue.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, orbPaint);

    final borderPaint = Paint()
      ..color = BrandColors.mineralBlue.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, radius, borderPaint);

    // Two orbiting dots
    final angle1 = thinkingValue * 2 * math.pi;
    final angle2 = angle1 + math.pi;
    final orbitRadius = radius + 10;

    final dotPaint = Paint()..color = BrandColors.mineralBlue.withValues(alpha: 0.7);

    final dot1 = center + Offset(math.cos(angle1) * orbitRadius, math.sin(angle1) * orbitRadius);
    final dot2 = center + Offset(math.cos(angle2) * orbitRadius, math.sin(angle2) * orbitRadius);

    canvas.drawCircle(dot1, 3.5, dotPaint);
    canvas.drawCircle(dot2, 3.5, dotPaint);
  }

  void _paintSpeaking(Canvas canvas, Offset center, double baseRadius) {
    // Organic rhythmic pulse
    final scale = 0.95 + (speakingValue * 0.13);
    final radius = baseRadius * scale;

    // Warm glow
    final glowPaint = Paint()
      ..color = BrandColors.mineralBlue.withValues(alpha: 0.12 + speakingValue * 0.06)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
    canvas.drawCircle(center, radius + 14, glowPaint);

    // Main orb
    final orbPaint = Paint()
      ..color = BrandColors.mineralBlue.withValues(alpha: 0.2 + speakingValue * 0.05)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, orbPaint);

    // Pulse ring
    final ringPaint = Paint()
      ..color = BrandColors.mineralBlue.withValues(alpha: 0.4 + speakingValue * 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(center, radius + 2, ringPaint);

    // Inner pulse
    final innerPaint = Paint()
      ..color = BrandColors.mineralBlue.withValues(alpha: 0.2 + speakingValue * 0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(center, radius * 0.4, innerPaint);
  }

  void _paintError(Canvas canvas, Offset center, double baseRadius) {
    // Static, dimmed
    final radius = baseRadius * 0.95;

    final orbPaint = Paint()
      ..color = BrandColors.mineralBlue.withValues(alpha: 0.1)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, orbPaint);

    final borderPaint = Paint()
      ..color = BrandColors.mineralBlue.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(center, radius, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _RazOrbPainter oldDelegate) {
    return state != oldDelegate.state ||
        breathingValue != oldDelegate.breathingValue ||
        listeningValue != oldDelegate.listeningValue ||
        thinkingValue != oldDelegate.thinkingValue ||
        speakingValue != oldDelegate.speakingValue;
  }
}
