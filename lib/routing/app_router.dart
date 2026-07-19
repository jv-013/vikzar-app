import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/screens/auth_screen.dart';
import '../features/onboarding/presentation/screens/onboarding_placeholder_screen.dart';
import '../features/onboarding/presentation/screens/splash_screen.dart';
import '../features/workspace/presentation/screens/workspace_selection_screen.dart';
import '../shared/models/workspace_type.dart';
import 'route_guards.dart';

/// The single [GoRouter] instance, per FLUTTER_ARCHITECTURE.md §4.
///
/// Phase 5 scope: Splash, Authentication, and Workspace Selection are real,
/// working, auth-gated routes. The destination beyond Workspace Selection
/// is a placeholder ("role-specific onboarding (future)") — Player/Coach
/// Home and the full ShellRoute-based nested navigation from
/// FLUTTER_ARCHITECTURE.md §4's complete route table remain future work,
/// since this phase explicitly does not build onboarding, Player Home, or
/// Coach Home.
///
/// A [Provider] (not a bare top-level `GoRouter`) so it can be constructed
/// with access to `ref` — needed for [RouterRefreshNotifier] and for the
/// `redirect` callback to read [routeDestinationProvider]. The provider
/// body itself does not `ref.watch` anything reactive, so it computes
/// exactly once and the router instance stays stable for the app's
/// lifetime, per go_router's own requirement not to recreate the router on
/// every rebuild.
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: SplashRoute.path,
    refreshListenable: RouterRefreshNotifier(ref),
    redirect: (context, state) {
      final destination = ref.read(routeDestinationProvider);
      final location = state.matchedLocation;

      return switch (destination) {
        StayOnSplash() => location == SplashRoute.path
            ? null
            : SplashRoute.path,
        GoToAuth() => location == AuthRoute.path ? null : AuthRoute.path,
        GoToWorkspaceSelection() => location == WorkspaceSelectionRoute.path
            ? null
            : WorkspaceSelectionRoute.path,
        GoToOnboardingPlaceholder(:final workspace) =>
          location == OnboardingPlaceholderRoute.pathFor(workspace)
              ? null
              : OnboardingPlaceholderRoute.pathFor(workspace),
      };
    },
    routes: [
      GoRoute(
        path: SplashRoute.path,
        name: SplashRoute.name,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AuthRoute.path,
        name: AuthRoute.name,
        builder: (context, state) => const AuthScreen(),
      ),
      GoRoute(
        path: WorkspaceSelectionRoute.path,
        name: WorkspaceSelectionRoute.name,
        builder: (context, state) => const WorkspaceSelectionScreen(),
      ),
      GoRoute(
        path: OnboardingPlaceholderRoute.playerPath,
        name: OnboardingPlaceholderRoute.playerName,
        builder: (context, state) =>
            const OnboardingPlaceholderScreen(workspace: WorkspaceType.player),
      ),
      GoRoute(
        path: OnboardingPlaceholderRoute.coachPath,
        name: OnboardingPlaceholderRoute.coachName,
        builder: (context, state) =>
            const OnboardingPlaceholderScreen(workspace: WorkspaceType.coach),
      ),
    ],
  );
});

/// Route constants, kept alongside the router they describe rather than
/// scattered as string literals through the app — each path is already a
/// real URL, deep-link-ready by construction, per
/// FLUTTER_ARCHITECTURE.md §4's "future deep linking" note.
abstract final class SplashRoute {
  static const String path = '/splash';
  static const String name = 'splash';
}

abstract final class AuthRoute {
  static const String path = '/auth';
  static const String name = 'auth';
}

abstract final class WorkspaceSelectionRoute {
  static const String path = '/workspace-selection';
  static const String name = 'workspace-selection';
}

abstract final class OnboardingPlaceholderRoute {
  static const String playerPath = '/onboarding/player';
  static const String playerName = 'onboarding-player';
  static const String coachPath = '/onboarding/coach';
  static const String coachName = 'onboarding-coach';

  static String pathFor(WorkspaceType workspace) => switch (workspace) {
    WorkspaceType.player => playerPath,
    WorkspaceType.coach => coachPath,
  };
}
