import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../design_system/components/vikzar_list_row.dart';
import '../../../../design_system/tokens/spacing.dart';

/// The Permissions step's content, shared by both Player and Coach
/// onboarding — DESIGN_SPECIFICATION.md §19.1, step 4: "one screen, not
/// one screen per permission." Purely presentational — each caller owns
/// where the three booleans live and what happens on Continue.
///
/// **Phase 6 note:** toggles are local UI state only, not wired to live OS
/// permission prompts — see DECISIONS.md's Phase 6 ADR. Real
/// `permission_handler`/platform-config integration is native-platform
/// configuration work outside this UI-focused phase.
class OnboardingPermissionsContent extends StatelessWidget {
  const OnboardingPermissionsContent({
    super.key,
    required this.bluetooth,
    required this.motion,
    required this.notifications,
    required this.onBluetoothChanged,
    required this.onMotionChanged,
    required this.onNotificationsChanged,
  });

  final bool bluetooth;
  final bool motion;
  final bool notifications;
  final ValueChanged<bool> onBluetoothChanged;
  final ValueChanged<bool> onMotionChanged;
  final ValueChanged<bool> onNotificationsChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        VikzarListRow(
          leading: Icon(Symbols.bluetooth, color: colorScheme.onSurface),
          title: 'Bluetooth',
          subtitle: "Vikzar hardware connects through your team's laptop; "
              'this enables future direct-device features.',
          trailing: Switch(value: bluetooth, onChanged: onBluetoothChanged),
        ),
        const Divider(height: SpacingTokens.space4),
        VikzarListRow(
          leading: Icon(Symbols.directions_run, color: colorScheme.onSurface),
          title: 'Motion',
          subtitle: 'Improves impact detection accuracy on supported devices.',
          trailing: Switch(value: motion, onChanged: onMotionChanged),
        ),
        const Divider(height: SpacingTokens.space4),
        VikzarListRow(
          leading: Icon(Symbols.notifications, color: colorScheme.onSurface),
          title: 'Notifications',
          subtitle: 'Get notified about alerts and session updates.',
          trailing: Switch(
            value: notifications,
            onChanged: onNotificationsChanged,
          ),
        ),
      ],
    );
  }
}
