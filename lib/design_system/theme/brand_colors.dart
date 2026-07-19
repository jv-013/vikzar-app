import 'package:flutter/painting.dart';

/// The five official Vikzar brand colours, per DESIGN_SPECIFICATION.md
/// "Official Colour Palette", plus the one sanctioned exception approved at
/// the Phase 2 freeze review.
///
/// These are the only raw colour values that should ever appear in the
/// codebase — every other file references a semantic role from
/// [VikzarColors] (theme/vikzar_colors.dart) or Flutter's [ColorScheme],
/// never one of these constants directly.
abstract final class BrandColors {
  /// Primary dark background — near-black with a cool violet undertone.
  static const Color plumBlack = Color(0xFF17131E);

  /// Secondary dark surface — near-identical value to Plum Black by design,
  /// used for the subtlest possible layering distinction.
  static const Color graphiteInk = Color(0xFF17191D);

  /// Primary accent — muted teal-blue; calm, trustworthy, data-forward.
  static const Color mineralBlue = Color(0xFF597C80);

  /// Secondary accent — muted warm rust; attention without alarm.
  static const Color oxideRose = Color(0xFF9E5C55);

  /// Primary light surface / primary text-on-dark.
  static const Color warmIvory = Color(0xFFF2E9E7);

  /// The one sanctioned exception to the five-colour palette, approved at
  /// the Phase 2 freeze review — reserved exclusively for Critical
  /// risk-level indicators (DESIGN_SPECIFICATION.md §8). Never used for
  /// generic errors or destructive actions; those use [oxideRose].
  static const Color alertCrimson = Color(0xFFC4432E);
}
