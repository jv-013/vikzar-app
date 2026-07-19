import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../tokens/type_scale.dart';

/// Maps DESIGN_SPECIFICATION.md §5's 8-step type scale onto Flutter's
/// Material 3 [TextTheme] roles, per FLUTTER_ARCHITECTURE.md §10.
///
/// Material 3's [TextTheme] has more size slots (13) than Vikzar's scale
/// (8) — each Vikzar step is reused across the closest matching M3 roles
/// rather than inventing additional sizes.
///
/// **Typeface freeze (Phase 6):** Display/Headline/Title Large/Title are
/// "headings" (Nohemi); Body Large/Body/Label/Caption are "body" (Inter).
///
/// **Nohemi swap point:** Nohemi's font files are not present in this
/// repository — obtaining and licensing a specific commercial font file is
/// a design-team/procurement decision, not one this phase can make. Until
/// that asset exists, [_heading] deliberately returns the *unmodified* base
/// style (no `fontFamily` set), so headings render in the platform default
/// system font — an honest, visibly-provisional placeholder, not a silent
/// Inter substitution that would look "finished." Once Nohemi's `.ttf`/`.otf`
/// files are added under `assets/fonts/` and registered in `pubspec.yaml`,
/// swap this function's body for
/// `GoogleFonts.getFont('Nohemi', textStyle: base)` (if distributed via a
/// Google Fonts-compatible catalog) or a `TextStyle(fontFamily: 'Nohemi')`
/// override — no other file in the app references a font family directly.
abstract final class VikzarTextTheme {
  static TextTheme build({required Color primaryText}) {
    TextStyle base({
      required double size,
      required double height,
      required int weight,
      required double tracking,
    }) => TextStyle(
      fontSize: size,
      height: height,
      fontWeight: _weightFrom(weight),
      letterSpacing: tracking,
      color: primaryText,
    );

    final display = _heading(
      base(
        size: TypeScaleTokens.displaySize,
        height: TypeScaleTokens.displayLineHeight,
        weight: TypeScaleTokens.displayWeight,
        tracking: TypeScaleTokens.displayTracking,
      ),
    );
    final headline = _heading(
      base(
        size: TypeScaleTokens.headlineSize,
        height: TypeScaleTokens.headlineLineHeight,
        weight: TypeScaleTokens.headlineWeight,
        tracking: TypeScaleTokens.headlineTracking,
      ),
    );
    final titleLarge = _heading(
      base(
        size: TypeScaleTokens.titleLargeSize,
        height: TypeScaleTokens.titleLargeLineHeight,
        weight: TypeScaleTokens.titleLargeWeight,
        tracking: TypeScaleTokens.titleLargeTracking,
      ),
    );
    final title = _heading(
      base(
        size: TypeScaleTokens.titleSize,
        height: TypeScaleTokens.titleLineHeight,
        weight: TypeScaleTokens.titleWeight,
        tracking: TypeScaleTokens.titleTracking,
      ),
    );
    final bodyLarge = _body(
      base(
        size: TypeScaleTokens.bodyLargeSize,
        height: TypeScaleTokens.bodyLargeLineHeight,
        weight: TypeScaleTokens.bodyLargeWeight,
        tracking: TypeScaleTokens.bodyLargeTracking,
      ),
    );
    final body = _body(
      base(
        size: TypeScaleTokens.bodySize,
        height: TypeScaleTokens.bodyLineHeight,
        weight: TypeScaleTokens.bodyWeight,
        tracking: TypeScaleTokens.bodyTracking,
      ),
    );
    final label = _body(
      base(
        size: TypeScaleTokens.labelSize,
        height: TypeScaleTokens.labelLineHeight,
        weight: TypeScaleTokens.labelWeight,
        tracking: TypeScaleTokens.labelTracking,
      ),
    );
    final caption = _body(
      base(
        size: TypeScaleTokens.captionSize,
        height: TypeScaleTokens.captionLineHeight,
        weight: TypeScaleTokens.captionWeight,
        tracking: TypeScaleTokens.captionTracking,
      ),
    );

    return TextTheme(
      displayLarge: display,
      displayMedium: display,
      displaySmall: display,
      headlineLarge: headline,
      headlineMedium: headline,
      headlineSmall: headline,
      titleLarge: titleLarge,
      titleMedium: title,
      titleSmall: title,
      bodyLarge: bodyLarge,
      bodyMedium: body,
      bodySmall: caption,
      labelLarge: label,
      labelMedium: label,
      labelSmall: caption,
    );
  }

  /// Nohemi swap point — see class doc comment. Currently a no-op (platform
  /// default system font).
  static TextStyle _heading(TextStyle base) => base;

  /// Inter, confirmed Phase 6. `GoogleFonts.inter` preserves every property
  /// of [base] (size, height, weight, tracking, color) and only sets the
  /// font family/fallback.
  static TextStyle _body(TextStyle base) => GoogleFonts.inter(textStyle: base);

  static FontWeight _weightFrom(int weight) => switch (weight) {
    400 => FontWeight.w400,
    500 => FontWeight.w500,
    600 => FontWeight.w600,
    _ => FontWeight.w400,
  };
}
