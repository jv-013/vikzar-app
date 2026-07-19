import 'package:flutter/material.dart';

import '../../../../design_system/components/vikzar_icon.dart';
import '../../../../design_system/tokens/motion.dart';
import '../../../../design_system/tokens/spacing.dart';

/// The app's launch screen — DESIGN_SPECIFICATION.md §19.1.
///
/// Phase 5 note: now uses the official Vikzar icon mark asset (imported
/// this phase — see `design_system/components/vikzar_icon.dart`). This
/// screen itself still does nothing but render and fade in — it never
/// navigates itself. Auth-state resolution and the resulting redirect to
/// Authentication or a workspace Home are implemented entirely in
/// `routing/app_router.dart`'s `redirect` callback, per
/// DESIGN_SPECIFICATION.md §19.1 and FLUTTER_ARCHITECTURE.md §4 — keeping
/// this screen a passive, "no navigation" (no interactive control)
/// terminal view, with routing logic centralized in one place rather than
/// duplicated into every screen that happens to be an entry point.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: MotionTokens.standard,
    );
    _fade = CurvedAnimation(
      parent: _fadeController,
      curve: MotionTokens.entrance,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        child: FadeTransition(
          key: const Key('splashFadeTransition'),
          opacity: _fade,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              VikzarIcon(
                size: 96,
                color: theme.colorScheme.onSurface,
              ),
              const SizedBox(height: SpacingTokens.space24),
              Text(
                'Know Every Impact.',
                style: textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
