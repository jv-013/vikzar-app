import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../routing/app_router.dart';
import '../../controllers/coach_onboarding_controller.dart';
import '../../widgets/onboarding_permissions_content.dart';
import '../../widgets/onboarding_step_scaffold.dart';

/// Step 4 (Coach) — DESIGN_SPECIFICATION.md §19.1, same content as the
/// Player Permissions step (`OnboardingPermissionsContent`).
class CoachPermissionsScreen extends ConsumerWidget {
  const CoachPermissionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissions = ref.watch(
      coachOnboardingControllerProvider.select((data) => data.permissions),
    );
    final controller = ref.read(coachOnboardingControllerProvider.notifier);

    return OnboardingStepScaffold(
      headline: 'A few permissions to get the most out of Vikzar.',
      showBackButton: true,
      content: OnboardingPermissionsContent(
        bluetooth: permissions.bluetooth,
        motion: permissions.motion,
        notifications: permissions.notifications,
        onBluetoothChanged: (value) =>
            controller.setPermissions(permissions.copyWith(bluetooth: value)),
        onMotionChanged: (value) =>
            controller.setPermissions(permissions.copyWith(motion: value)),
        onNotificationsChanged: (value) => controller.setPermissions(
          permissions.copyWith(notifications: value),
        ),
      ),
      onContinue: () => context.go(OnboardingRoute.teamPath),
    );
  }
}
