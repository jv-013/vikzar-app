import 'package:flutter/material.dart';

import '../../../../design_system/tokens/motion.dart';
import '../../../../design_system/tokens/spacing.dart';

/// The app's launch screen — DESIGN_SPECIFICATION.md §19.1.
///
/// Deliberately minimal for Phase 4 (bootstrap): it proves the app
/// launches and nothing more. No auth-state check, no redirect, no
/// loading indicator — that routing logic (FLUTTER_ARCHITECTURE.md §4) is
/// introduced once Authentication exists (Phase 5+), which this phase's
/// scope explicitly excludes.
///
/// Logo asset: the official Vikzar icon mark is a fixed brand asset that
/// must not be redesigned or reinterpreted (DESIGN_SPECIFICATION.md, "Logo
/// and Icon"). No image file for it exists in this repository yet — only
/// the icon *was shown* during design review, never supplied as an asset
/// file. Until `assets/branding/vikzar_icon.png` (or `.svg`) is provided,
/// this screen renders the wordmark as styled text (typography only, no
/// invented graphic mark) so the app has a correct, honest placeholder
/// rather than a fabricated logo. Swapping in the real asset is a
/// one-line change below.
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
              // TODO(branding): replace with Image.asset(
              //   'assets/branding/vikzar_icon.png',
              // ) once the official icon asset file is supplied — see the
              // class-level doc comment above. Not `Image` today because no
              // asset file exists to reference.
              Text(
                'VIKZAR',
                style: textTheme.headlineLarge,
                semanticsLabel: 'Vikzar',
              ),
              const SizedBox(height: SpacingTokens.space16),
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
