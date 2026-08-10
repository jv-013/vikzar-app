import 'package:flutter/material.dart';

import '../../design_system/tokens/spacing.dart';

/// The loading counterpart to [SectionEmptyState] (same file's sibling —
/// see `section_empty_state.dart`): a centered spinner with the same
/// vertical rhythm, for a section that is genuinely the screen's primary
/// content rather than a secondary strip embedded in an
/// already-populated dashboard. Screens where a loading indicator would
/// mean several independent async sections flashing spinners at once
/// (e.g. Player/Coach Home's Recent Activity feed) deliberately render
/// nothing instead — see `RecentActivityFeed`'s own doc comment for that
/// reasoning; this widget is for the opposite case.
class SectionLoadingState extends StatelessWidget {
  const SectionLoadingState({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: SpacingTokens.space32),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}
