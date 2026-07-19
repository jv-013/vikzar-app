import 'package:flutter/material.dart';

import '../tokens/motion.dart';
import '../tokens/spacing.dart';

/// Fades a section open beneath a chip/segment row **in place, on the same
/// screen** — the Injury History detail chips in the Profile Form
/// (DESIGN_SPECIFICATION.md §19.1: "never a new screen, never a new
/// page"). Deliberately narrow-purpose rather than a generic
/// accordion/collapsible — this app has exactly one inline-expand pattern.
class VikzarExpandableSection extends StatelessWidget {
  const VikzarExpandableSection({
    super.key,
    required this.expanded,
    required this.child,
  });

  final bool expanded;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: MotionTokens.standard,
      curve: MotionTokens.entrance,
      alignment: Alignment.topCenter,
      child: AnimatedOpacity(
        duration: MotionTokens.standard,
        opacity: expanded ? 1 : 0,
        child: expanded
            ? Padding(
                padding: const EdgeInsets.only(top: SpacingTokens.space16),
                child: child,
              )
            : const SizedBox(width: double.infinity),
      ),
    );
  }
}
