import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The official Vikzar standalone icon mark, per DESIGN_SPECIFICATION.md
/// "Logo and Icon" — used directly from `assets/branding/vikzar_icon.svg`,
/// unmodified, per that section's rule against redesigning or
/// reinterpreting the mark.
///
/// The source file is inked in Plum Black (the on-light rendition). Tinting
/// it at render time via [ColorFilter] to render on-dark (Warm Ivory, per
/// DESIGN_SPECIFICATION.md's on-dark usage rule) is not a redesign — no
/// asset content is modified, only how it's painted for this theme.
///
/// The full two-colour wordmark lockup (`vikzar_logo_lockup.svg` — Plum
/// Black wordmark + Oxide Rose accent, designed for a light/transparent
/// background) is deliberately **not** used on any dark, Plum-Black-surface
/// screen in this app: its wordmark would be invisible at zero contrast
/// against an identically-coloured background, and force-tinting it to a
/// single colour would erase its intentional two-colour design — a form of
/// redesign this phase explicitly forbids. It remains a registered asset,
/// reserved for a future light-surface context. Every in-app placement
/// uses this standalone icon mark instead.
class VikzarIcon extends StatelessWidget {
  const VikzarIcon({super.key, required this.size, this.color});

  /// Width and height in logical pixels. Per DESIGN_SPECIFICATION.md, the
  /// standalone icon mark is never rendered below 24dp.
  final double size;

  /// Tint applied to the whole mark. Pass the surface-appropriate colour —
  /// Warm Ivory on Plum Black / Graphite Ink, Plum Black on Warm Ivory /
  /// white — per DESIGN_SPECIFICATION.md's on-dark / on-light rule. `null`
  /// renders the source file's own ink colour (Plum Black), for the rare
  /// on-light case where that already matches.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/branding/vikzar_icon.svg',
      width: size,
      height: size,
      colorFilter: color == null
          ? null
          : ColorFilter.mode(color!, BlendMode.srcIn),
      semanticsLabel: 'Vikzar',
    );
  }
}
