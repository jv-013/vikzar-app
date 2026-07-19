import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/screens/auth_screen.dart';
import '../features/onboarding/presentation/screens/coach/coach_level_screen.dart';
import '../features/onboarding/presentation/screens/coach/coach_permissions_screen.dart';
import '../features/onboarding/presentation/screens/coach/coach_profile_screen.dart';
import '../features/onboarding/presentation/screens/coach/create_join_team_screen.dart';
import '../features/onboarding/presentation/screens/onboarding_complete_screen.dart';
import '../features/onboarding/presentation/screens/player/connect_pod_screen.dart';
import '../features/onboarding/presentation/screens/player/player_level_screen.dart';
import '../features/onboarding/presentation/screens/player/player_permissions_screen.dart';
import '../features/onboarding/presentation/screens/player/player_profile_screen.dart';
import '../features/onboarding/presentation/screens/splash_screen.dart';
import '../features/workspace/presentation/screens/workspace_selection_screen.dart';
import '../shared/models/workspace_type.dart';
import 'route_guards.dart';

/// The single [GoRouter] instance, per FLUTTER_ARCHITECTURE.md §4.
///
/// Phase 6 scope: Splash, Authentication, Workspace Selection, and the
/// complete Player and Coach onboarding flows through to an Onboarding
/// Complete terminal screen are real, working, auth-gated routes.
/// Player/Coach Home and the full ShellRoute-based nested navigation from
/// FLUTTER_ARCHITECTURE.md §4's complete route table remain future work —
/// this phase explicitly does not build them.
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
        InOnboarding(:final workspace, :final alreadyCompleted) =>
          _onboardingRedirect(location, workspace, alreadyCompleted),
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
        path: OnboardingRoute.levelPath(WorkspaceType.player),
        name: 'onboarding-player-level',
        builder: (context, state) => const PlayerLevelScreen(),
      ),
      GoRoute(
        path: OnboardingRoute.profilePath(WorkspaceType.player),
        name: 'onboarding-player-profile',
        builder: (context, state) => const PlayerProfileScreen(),
      ),
      GoRoute(
        path: OnboardingRoute.permissionsPath(WorkspaceType.player),
        name: 'onboarding-player-permissions',
        builder: (context, state) => const PlayerPermissionsScreen(),
      ),
      GoRoute(
        path: OnboardingRoute.connectPodPath,
        name: 'onboarding-player-connect-pod',
        builder: (context, state) => const ConnectPodScreen(),
      ),
      GoRoute(
        path: OnboardingRoute.completePath(WorkspaceType.player),
        name: 'onboarding-player-complete',
        builder: (context, state) =>
            const OnboardingCompleteScreen(workspace: WorkspaceType.player),
      ),
      GoRoute(
        path: OnboardingRoute.levelPath(WorkspaceType.coach),
        name: 'onboarding-coach-level',
        builder: (context, state) => const CoachLevelScreen(),
      ),
      GoRoute(
        path: OnboardingRoute.profilePath(WorkspaceType.coach),
        name: 'onboarding-coach-profile',
        builder: (context, state) => const CoachProfileScreen(),
      ),
      GoRoute(
        path: OnboardingRoute.permissionsPath(WorkspaceType.coach),
        name: 'onboarding-coach-permissions',
        builder: (context, state) => const CoachPermissionsScreen(),
      ),
      GoRoute(
        path: OnboardingRoute.teamPath,
        name: 'onboarding-coach-team',
        builder: (context, state) => const CreateJoinTeamScreen(),
      ),
      GoRoute(
        path: OnboardingRoute.completePath(WorkspaceType.coach),
        name: 'onboarding-coach-complete',
        builder: (context, state) =>
            const OnboardingCompleteScreen(workspace: WorkspaceType.coach),
      ),
    ],
  );
});

/// [InOnboarding] gates an entire subtree, not one exact path — free
/// forward/back navigation among a workspace's own onboarding steps, and a
/// forced jump to that workspace's entry step only when arriving from
/// outside the subtree entirely (fresh from Auth/Workspace Selection, or a
/// stale deep link into the *other* workspace's subtree).
String? _onboardingRedirect(
  String location,
  WorkspaceType workspace,
  bool alreadyCompleted,
) {
  if (location.startsWith(OnboardingRoute.subtreePrefix(workspace))) {
    return null;
  }
  return alreadyCompleted
      ? OnboardingRoute.completePath(workspace)
      : OnboardingRoute.levelPath(workspace);
}

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

/// Path helpers for the onboarding subtree, `/onboarding/{workspace}/**`.
/// [connectPodPath]/[teamPath] are workspace-specific steps (Player-only,
/// Coach-only respectively) rather than a shared `stepPath` helper, since
/// their names and following-screen shape genuinely differ.
abstract final class OnboardingRoute {
  static String subtreePrefix(WorkspaceType workspace) =>
      '/onboarding/${workspace.firestoreKey}/';

  static String levelPath(WorkspaceType workspace) =>
      '${subtreePrefix(workspace)}level';

  static String profilePath(WorkspaceType workspace) =>
      '${subtreePrefix(workspace)}profile';

  static String permissionsPath(WorkspaceType workspace) =>
      '${subtreePrefix(workspace)}permissions';

  static const String connectPodPath = '/onboarding/player/connect-pod';
  static const String teamPath = '/onboarding/coach/team';

  static String completePath(WorkspaceType workspace) =>
      '${subtreePrefix(workspace)}complete';
}
