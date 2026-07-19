import 'package:go_router/go_router.dart';

import '../features/onboarding/presentation/screens/splash_screen.dart';

/// The single [GoRouter] instance, per FLUTTER_ARCHITECTURE.md §4.
///
/// Phase 4 (bootstrap) scope: **Splash is the only working route.**
/// Everything else in FLUTTER_ARCHITECTURE.md §4's full route table — the
/// auth gate, onboarding steps, and the Player/Coach shell routes — is
/// deliberately not wired up yet, since it depends on Authentication and
/// workspace state that do not exist until later phases. Adding those
/// routes is additive: this file gains more `GoRoute`/`ShellRoute` entries
/// and a `redirect` callback; nothing here needs to be restructured.
final GoRouter appRouter = GoRouter(
  initialLocation: SplashRoute.path,
  routes: [
    GoRoute(
      path: SplashRoute.path,
      name: SplashRoute.name,
      builder: (context, state) => const SplashScreen(),
    ),
  ],
);

/// Route constants, kept alongside the router they describe rather than
/// scattered as string literals through the app.
abstract final class SplashRoute {
  static const String path = '/splash';
  static const String name = 'splash';
}
