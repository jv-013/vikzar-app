import 'package:flutter/animation.dart';

/// Motion durations and curves, per DESIGN_SPECIFICATION.md §12.
///
/// Motion exists to show spatial relationships, draw attention to a genuine
/// state change, or provide direct-manipulation feedback — never as
/// decoration. Every animated transition in the app references one of
/// these constants; none hardcodes a `Duration` or `Curve` literal.
abstract final class MotionTokens {
  /// Standard transition duration (most UI transitions).
  static const Duration standard = Duration(milliseconds: 200);

  /// Critical-alert entrance — faster than standard; safety information
  /// should never feel like it is taking its time to arrive.
  static const Duration criticalEntrance = Duration(milliseconds: 150);

  /// Sheet/dialog transitions, and the workspace-switch cross-fade.
  static const Duration sheetAndDialog = Duration(milliseconds: 250);

  /// Live data value updates (once-per-second ticks) — a muted cross-fade,
  /// not a slide or a counted animation, so once-a-second updates read as
  /// alive rather than noisy.
  static const Duration liveDataCrossFade = Duration(milliseconds: 120);

  /// Reduced-motion fallback — instant cross-fade, no directional movement.
  static const Duration reducedMotion = Duration(milliseconds: 100);

  /// Forward-navigation page transitions (added Phase 6) — e.g. one
  /// onboarding step to the next. A restrained slide-with-fade, distinct
  /// from the workspace-switch cross-fade ([liveDataCrossFade] duration
  /// differs; workspace switching itself is [sheetAndDialog]'s duration,
  /// never a slide).
  static const Duration pageTransition = Duration(milliseconds: 250);

  /// Soft scale-in for buttons/cards on appearance (added Phase 6) — not
  /// on every interaction, only first appearance.
  static const Duration softScaleIn = Duration(milliseconds: 150);

  static const Curve entrance = Curves.easeOut;
  static const Curve exit = Curves.easeIn;
}
