import 'package:flutter/material.dart';

import '../../design_system/tokens/motion.dart';

/// A restrained, purposeful entrance treatment — a 98%→100% scale-in
/// cross-faded over [MotionTokens.softScaleIn], never a bounce/spring.
/// Extracted at Phase 9 from the identical inline `TweenAnimationBuilder`
/// `onboarding_complete_screen.dart` introduced, so every screen built this
/// phase applies the exact same entrance, not a per-screen reinvention —
/// per DESIGN_SPECIFICATION.md §12's "motion should communicate continuity,
/// not excitement" and this phase's explicit priority on consistency over
/// novelty.
class FadeScaleIn extends StatelessWidget {
  const FadeScaleIn({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: MotionTokens.softScaleIn,
      curve: MotionTokens.entrance,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.scale(scale: 0.98 + (0.02 * value), child: child),
      ),
      child: child,
    );
  }
}
