/// The 8-step type scale, per DESIGN_SPECIFICATION.md §5.
///
/// Sizes, weights, line heights, and tracking are typeface-agnostic and
/// frozen here. Which *typeface* renders each step (Nohemi for headings,
/// Inter for body — frozen Phase 6) is applied in
/// `design_system/theme/vikzar_text_theme.dart`, not here — see that file's
/// doc comment for the Nohemi asset swap point.
///
/// Weights used: 400 (regular), 500 (medium), 600 (semibold) only — no
/// light, no bold/700+, per the deliberately small type system in
/// DESIGN_SPECIFICATION.md §3.
abstract final class TypeScaleTokens {
  static const double displaySize = 40;
  static const double displayLineHeight = 48 / 40;
  static const int displayWeight = 600;
  static const double displayTracking = -0.5;

  static const double headlineSize = 28;
  static const double headlineLineHeight = 34 / 28;
  static const int headlineWeight = 600;
  static const double headlineTracking = -0.25;

  static const double titleLargeSize = 22;
  static const double titleLargeLineHeight = 28 / 22;
  static const int titleLargeWeight = 600;
  static const double titleLargeTracking = 0;

  static const double titleSize = 18;
  static const double titleLineHeight = 24 / 18;
  static const int titleWeight = 600;
  static const double titleTracking = 0;

  static const double bodyLargeSize = 16;
  static const double bodyLargeLineHeight = 24 / 16;
  static const int bodyLargeWeight = 400;
  static const double bodyLargeTracking = 0;

  static const double bodySize = 14;
  static const double bodyLineHeight = 20 / 14;
  static const int bodyWeight = 400;
  static const double bodyTracking = 0;

  static const double labelSize = 13;
  static const double labelLineHeight = 16 / 13;
  static const int labelWeight = 600;
  static const double labelTracking = 0.2;

  static const double captionSize = 12;
  static const double captionLineHeight = 16 / 12;
  static const int captionWeight = 500;
  static const double captionTracking = 0.1;
}
