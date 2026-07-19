/// The elevation scale, per DESIGN_SPECIFICATION.md §9.
///
/// Vikzar's dark theme communicates elevation primarily through a subtle
/// white-opacity overlay on the surface colour (the Material dark-theme
/// technique), not heavy drop shadows — reserving shadow for the light
/// theme and the highest levels. There is no level beyond [level4]: if a
/// surface needs more separation than a dialog, it should be its own
/// screen instead.
///
/// These are raw values only. They are exposed to widgets via the
/// `VikzarElevation` ThemeExtension (design_system/theme/), never consumed
/// directly by feature code — see FLUTTER_ARCHITECTURE.md §10.
abstract final class ElevationTokens {
  /// Screen background. No overlay, no shadow.
  static const double level0Overlay = 0;
  static const double level0ShadowDp = 0;

  /// Resting cards.
  static const double level1Overlay = 0.02;
  static const double level1ShadowDp = 1;

  /// Interactive/pressed cards, active list items.
  static const double level2Overlay = 0.04;
  static const double level2ShadowDp = 2;

  /// Bottom sheets, dropdowns, popovers.
  static const double level3Overlay = 0.08;
  static const double level3ShadowDp = 4;

  /// Dialogs, the workspace switcher sheet, Critical alert modals.
  static const double level4Overlay = 0.12;
  static const double level4ShadowDp = 8;
}
