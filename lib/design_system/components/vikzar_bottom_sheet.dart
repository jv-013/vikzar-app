import 'package:flutter/material.dart';

import '../theme/vikzar_elevation.dart';
import '../tokens/radius.dart';

/// DESIGN_SPECIFICATION.md §18, "Bottom Sheets" — Elevation 3, `radius-lg`
/// top corners only. Used for the profile sheet, the workspace switcher,
/// and any future contextual action list — one shared presentation
/// mechanism rather than each caller building its own `showModalBottomSheet`
/// configuration.
abstract final class VikzarBottomSheet {
  static Future<T?> show<T>(BuildContext context, {required WidgetBuilder builder}) {
    final theme = Theme.of(context);
    final elevation = theme.extension<VikzarElevation>();
    final backgroundColor = elevation == null
        ? theme.colorScheme.surface
        : Color.alphaBlend(elevation.level3Overlay, theme.colorScheme.surface);

    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: backgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(RadiusTokens.large)),
      ),
      isScrollControlled: true,
      builder: builder,
    );
  }
}
