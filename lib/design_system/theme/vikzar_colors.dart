import 'package:flutter/material.dart';

import 'brand_colors.dart';

/// The one colour role Flutter's built-in [ColorScheme] has no slot for:
/// Alert Crimson, per DESIGN_SPECIFICATION.md §8 and the Phase 2 freeze
/// review.
///
/// Every other semantic colour role (primary, error/Oxide-Rose, surface,
/// onSurface, onSurfaceVariant for secondary text, etc.) maps directly onto
/// a standard [ColorScheme] role — see `theme/app_theme.dart` — and does
/// not need a custom extension. This is a deliberately small extension for
/// a deliberately narrow, flagged exception: `criticalRisk` is used *only*
/// for Critical risk-level indicators (risk chip/ring, the persistent
/// Critical alert banner, Critical entries in the Alert Inbox) — never for
/// generic form errors or destructive actions, which use
/// `ColorScheme.error` (Oxide Rose) instead.
@immutable
class VikzarColors extends ThemeExtension<VikzarColors> {
  const VikzarColors({required this.criticalRisk});

  final Color criticalRisk;

  static const VikzarColors standard = VikzarColors(
    criticalRisk: BrandColors.alertCrimson,
  );

  @override
  VikzarColors copyWith({Color? criticalRisk}) =>
      VikzarColors(criticalRisk: criticalRisk ?? this.criticalRisk);

  @override
  VikzarColors lerp(ThemeExtension<VikzarColors>? other, double t) {
    if (other is! VikzarColors) return this;
    return VikzarColors(
      criticalRisk: Color.lerp(criticalRisk, other.criticalRisk, t)!,
    );
  }
}
