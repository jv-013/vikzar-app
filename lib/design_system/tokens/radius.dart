import 'package:flutter/widgets.dart';

/// The corner radius scale, per DESIGN_SPECIFICATION.md §10.
///
/// Radius scales with surface size, never past [medium]/[large] except the
/// dedicated [pill] treatment for buttons, tabs, and segment controls.
abstract final class RadiusTokens {
  /// Chips, status tags, small badges.
  static const double extraSmall = 8;

  /// Text fields, small/icon buttons, segment control container.
  static const double small = 12;

  /// Standard cards (player cards, session cards, timeline cards).
  static const double medium = 16;

  /// Large cards, top corners of bottom sheets.
  static const double large = 24;

  /// Fully rounded — primary/secondary buttons, tab indicators.
  static const double pill = 999;

  static const BorderRadius extraSmallRadius = BorderRadius.all(
    Radius.circular(extraSmall),
  );
  static const BorderRadius smallRadius = BorderRadius.all(
    Radius.circular(small),
  );
  static const BorderRadius mediumRadius = BorderRadius.all(
    Radius.circular(medium),
  );
  static const BorderRadius largeRadius = BorderRadius.all(
    Radius.circular(large),
  );
  static const BorderRadius pillRadius = BorderRadius.all(
    Radius.circular(pill),
  );
}
