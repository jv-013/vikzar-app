import 'package:flutter/material.dart';

import '../tokens/elevation.dart';

/// The overlay-based elevation model from DESIGN_SPECIFICATION.md §9,
/// exposed as a [ThemeExtension] because Material 3's default
/// surface-tint elevation model does not match Vikzar's chosen "white
/// overlay on a dark surface" approach — see FLUTTER_ARCHITECTURE.md §10.
///
/// `design_system/components` widgets (introduced when a feature first
/// needs one) apply `overlayForLevel` to their surface colour rather than
/// relying on Flutter's built-in `elevation` property, which would produce
/// the wrong visual result for this theme.
@immutable
class VikzarElevation extends ThemeExtension<VikzarElevation> {
  const VikzarElevation({
    required this.level0Overlay,
    required this.level1Overlay,
    required this.level2Overlay,
    required this.level3Overlay,
    required this.level4Overlay,
  });

  /// Dark theme: white at the DESIGN_SPECIFICATION.md-specified opacity per
  /// level. Light theme: transparent (light theme uses shadow, not
  /// overlay — see FLUTTER_ARCHITECTURE.md §10).
  factory VikzarElevation.dark() => const VikzarElevation(
    level0Overlay: Colors.transparent,
    level1Overlay: Color.fromRGBO(255, 255, 255, ElevationTokens.level1Overlay),
    level2Overlay: Color.fromRGBO(255, 255, 255, ElevationTokens.level2Overlay),
    level3Overlay: Color.fromRGBO(255, 255, 255, ElevationTokens.level3Overlay),
    level4Overlay: Color.fromRGBO(255, 255, 255, ElevationTokens.level4Overlay),
  );

  factory VikzarElevation.light() => const VikzarElevation(
    level0Overlay: Colors.transparent,
    level1Overlay: Colors.transparent,
    level2Overlay: Colors.transparent,
    level3Overlay: Colors.transparent,
    level4Overlay: Colors.transparent,
  );

  final Color level0Overlay;
  final Color level1Overlay;
  final Color level2Overlay;
  final Color level3Overlay;
  final Color level4Overlay;

  @override
  VikzarElevation copyWith({
    Color? level0Overlay,
    Color? level1Overlay,
    Color? level2Overlay,
    Color? level3Overlay,
    Color? level4Overlay,
  }) => VikzarElevation(
    level0Overlay: level0Overlay ?? this.level0Overlay,
    level1Overlay: level1Overlay ?? this.level1Overlay,
    level2Overlay: level2Overlay ?? this.level2Overlay,
    level3Overlay: level3Overlay ?? this.level3Overlay,
    level4Overlay: level4Overlay ?? this.level4Overlay,
  );

  @override
  VikzarElevation lerp(ThemeExtension<VikzarElevation>? other, double t) {
    if (other is! VikzarElevation) return this;
    return VikzarElevation(
      level0Overlay: Color.lerp(level0Overlay, other.level0Overlay, t)!,
      level1Overlay: Color.lerp(level1Overlay, other.level1Overlay, t)!,
      level2Overlay: Color.lerp(level2Overlay, other.level2Overlay, t)!,
      level3Overlay: Color.lerp(level3Overlay, other.level3Overlay, t)!,
      level4Overlay: Color.lerp(level4Overlay, other.level4Overlay, t)!,
    );
  }
}
