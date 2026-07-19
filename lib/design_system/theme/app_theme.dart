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
/// **Colour role assignment, frozen at Phase 5** (DESIGN_SPECIFICATION.md
/// §8, "Colour Philosophy"): `ColorScheme.primary` is Oxide Rose (the
/// primary action colour) and `ColorScheme.secondary` is Mineral Blue (the
/// secondary informational accent) — swapped from the original Phase 2
/// draft, where Mineral Blue was primary. `ColorScheme.error` remains
/// Oxide Rose, unchanged: the Phase 2 freeze review scoped Alert Crimson
/// exclusively to Critical risk-level indicators (exposed via
/// [VikzarColors.criticalRisk]), never to generic form/destructive errors.
/// Reusing Oxide Rose for both `primary` and `error` is intentional, not
/// an oversight — the two are differentiated by component *treatment*
/// (a filled pill for Primary vs. an outlined pill for Destructive/error),
/// not by hue, exactly as DESIGN_SPECIFICATION.md §18's Button component
/// already specified before this swap.
abstract final class AppTheme {
  static ThemeData light() {
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: BrandColors.oxideRose,
      onPrimary: BrandColors.warmIvory,
      secondary: BrandColors.mineralBlue,
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
      primary: BrandColors.oxideRose,
      onPrimary: BrandColors.warmIvory,
      secondary: BrandColors.mineralBlue,
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
    final textTheme = VikzarTextTheme.build(primaryText: primaryText);

    return ThemeData(
      useMaterial3: true,
      brightness: colorScheme.brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffoldBackground,
      textTheme: textTheme,
      dividerColor: colorScheme.outline,
      extensions: <ThemeExtension<dynamic>>[VikzarColors.standard, elevation],
      // DESIGN_SPECIFICATION.md §18, "Bottom Navigation" (added Phase 7):
      // active item = filled Oxide Rose tint on icon + label, per the
      // Phase 5 colour philosophy; inactive = Warm Ivory 64%. Themed once
      // here rather than per NavigationBar instance, since both
      // AppShellScaffold(player) and AppShellScaffold(coach) share it.
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scaffoldBackground,
        indicatorColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => textTheme.labelSmall?.copyWith(
            color: states.contains(WidgetState.selected)
                ? colorScheme.primary
                : colorScheme.onSurface.withValues(alpha: 0.64),
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? colorScheme.primary
                : colorScheme.onSurface.withValues(alpha: 0.64),
          ),
        ),
      ),
    );
  }
}
