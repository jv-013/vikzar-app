/// The 8-step type scale, per DESIGN_SPECIFICATION.md §5.
///
/// IMPORTANT — typeface: DESIGN_SPECIFICATION.md §5 recommends "Inter" as
/// the primary typeface, but its own Open Questions list explicitly flag
/// that recommendation as **not yet confirmed** (licensing/procurement
/// pending). Per this phase's instruction to install `google_fonts` "only
/// if approved by the design specification," it has not been installed and
/// `fontFamily` is deliberately left unset below, so the app renders with
/// each platform's default system font (San Francisco / Roboto / Segoe UI
/// / Ubuntu) until that decision is made. Swapping in a confirmed typeface
/// later is a one-line change in design_system/theme/text_theme.dart —
/// nothing else in the app references a font family directly.
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
