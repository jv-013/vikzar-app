import 'package:flutter/material.dart';

import 'brand_colors.dart';
import 'vikzar_colors.dart';
import 'vikzar_elevation.dart';
import 'vikzar_text_theme.dart';

/// Composes the design tokens (typography, colour, elevation) into the two
/// [ThemeData] objects the app uses, per DESIGN_SPECIFICATION.md and
/// FLUTTER_ARCHITECTURE.md §10.
///
/// Dark is the primary, identity-defining theme (DESIGN_SPECIFICATION.md
/// §3, "Design Philosophy"); light exists for contexts where dark isn't
/// appropriate, per ARCHITECTURE.md ADR-026.
///
/// `ColorScheme.error` is deliberately Oxide Rose, not Alert Crimson — the
/// Phase 2 freeze review scoped Alert Crimson exclusively to Critical
/// risk-level indicators (exposed via [VikzarColors.criticalRisk]), never
/// to generic form/destructive errors, which is exactly what Flutter's
/// built-in `error` role is used for by default widgets.
abstract final class AppTheme {
  static ThemeData light() {
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: BrandColors.mineralBlue,
      onPrimary: BrandColors.warmIvory,
      secondary: BrandColors.oxideRose,
      onSecondary: BrandColors.warmIvory,
      error: BrandColors.oxideRose,
      onError: BrandColors.warmIvory,
      surface: BrandColors.warmIvory,
      onSurface: BrandColors.plumBlack,
      onSurfaceVariant: Color(0xA317131E), // plumBlack @ ~64%
      outline: Color(0x1417131E), // plumBlack @ ~8%
      outlineVariant: Color(0x1417131E),
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: Colors.white,
      surfaceContainer: Colors.white,
      surfaceContainerHigh: Colors.white,
      surfaceContainerHighest: Colors.white,
    );

    return _themeFrom(
      colorScheme: colorScheme,
      primaryText: BrandColors.plumBlack,
      scaffoldBackground: BrandColors.warmIvory,
      elevation: VikzarElevation.light(),
    );
  }

  static ThemeData dark() {
    const colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: BrandColors.mineralBlue,
      onPrimary: BrandColors.warmIvory,
      secondary: BrandColors.oxideRose,
      onSecondary: BrandColors.warmIvory,
      error: BrandColors.oxideRose,
      onError: BrandColors.warmIvory,
      surface: BrandColors.plumBlack,
      onSurface: BrandColors.warmIvory,
      onSurfaceVariant: Color(0xA3F2E9E7), // warmIvory @ ~64%
      outline: Color(0x14F2E9E7), // warmIvory @ ~8%
      outlineVariant: Color(0x14F2E9E7),
      surfaceContainerLowest: BrandColors.plumBlack,
      surfaceContainerLow: BrandColors.graphiteInk,
      surfaceContainer: BrandColors.graphiteInk,
      surfaceContainerHigh: BrandColors.graphiteInk,
      surfaceContainerHighest: BrandColors.graphiteInk,
    );

    return _themeFrom(
      colorScheme: colorScheme,
      primaryText: BrandColors.warmIvory,
      scaffoldBackground: BrandColors.plumBlack,
      elevation: VikzarElevation.dark(),
    );
  }

  static ThemeData _themeFrom({
    required ColorScheme colorScheme,
    required Color primaryText,
    required Color scaffoldBackground,
    required VikzarElevation elevation,
  }) {
    return ThemeData(
      useMaterial3: true,
      brightness: colorScheme.brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffoldBackground,
      textTheme: VikzarTextTheme.build(primaryText: primaryText),
      dividerColor: colorScheme.outline,
      extensions: <ThemeExtension<dynamic>>[VikzarColors.standard, elevation],
    );
  }
}
