import 'package:flutter/material.dart';

import '../tokens/type_scale.dart';

/// Maps DESIGN_SPECIFICATION.md §5's 8-step type scale onto Flutter's
/// Material 3 [TextTheme] roles, per FLUTTER_ARCHITECTURE.md §10.
///
/// Material 3's [TextTheme] has more size slots (13) than Vikzar's scale
/// (8) — each Vikzar step is reused across the closest matching M3 roles
/// rather than inventing additional sizes. `fontFamily` is deliberately
/// left unset everywhere (see tokens/type_scale.dart) pending typeface
/// confirmation.
abstract final class VikzarTextTheme {
  static TextTheme build({required Color primaryText}) {
    TextStyle style({
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

    final display = style(
      size: TypeScaleTokens.displaySize,
      height: TypeScaleTokens.displayLineHeight,
      weight: TypeScaleTokens.displayWeight,
      tracking: TypeScaleTokens.displayTracking,
    );
    final headline = style(
      size: TypeScaleTokens.headlineSize,
      height: TypeScaleTokens.headlineLineHeight,
      weight: TypeScaleTokens.headlineWeight,
      tracking: TypeScaleTokens.headlineTracking,
    );
    final titleLarge = style(
      size: TypeScaleTokens.titleLargeSize,
      height: TypeScaleTokens.titleLargeLineHeight,
      weight: TypeScaleTokens.titleLargeWeight,
      tracking: TypeScaleTokens.titleLargeTracking,
    );
    final title = style(
      size: TypeScaleTokens.titleSize,
      height: TypeScaleTokens.titleLineHeight,
      weight: TypeScaleTokens.titleWeight,
      tracking: TypeScaleTokens.titleTracking,
    );
    final bodyLarge = style(
      size: TypeScaleTokens.bodyLargeSize,
      height: TypeScaleTokens.bodyLargeLineHeight,
      weight: TypeScaleTokens.bodyLargeWeight,
      tracking: TypeScaleTokens.bodyLargeTracking,
    );
    final body = style(
      size: TypeScaleTokens.bodySize,
      height: TypeScaleTokens.bodyLineHeight,
      weight: TypeScaleTokens.bodyWeight,
      tracking: TypeScaleTokens.bodyTracking,
    );
    final label = style(
      size: TypeScaleTokens.labelSize,
      height: TypeScaleTokens.labelLineHeight,
      weight: TypeScaleTokens.labelWeight,
      tracking: TypeScaleTokens.labelTracking,
    );
    final caption = style(
      size: TypeScaleTokens.captionSize,
      height: TypeScaleTokens.captionLineHeight,
      weight: TypeScaleTokens.captionWeight,
      tracking: TypeScaleTokens.captionTracking,
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

  static FontWeight _weightFrom(int weight) => switch (weight) {
    400 => FontWeight.w400,
    500 => FontWeight.w500,
    600 => FontWeight.w600,
    _ => FontWeight.w400,
  };
}
