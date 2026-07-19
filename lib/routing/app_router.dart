import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/screens/auth_screen.dart';
import '../features/coach_home/presentation/screens/coach_home_screen.dart';
import '../features/notifications/presentation/screens/notification_center_screen.dart';
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
import '../features/player_home/presentation/screens/player_home_screen.dart';
import '../features/profile/presentation/screens/profile_screen.dart';
import '../features/profile/presentation/screens/settings_screen.dart';
import '../features/workspace/presentation/screens/become_a_coach_complete_screen.dart';
import '../features/workspace/presentation/screens/become_a_coach_screen.dart';
import '../features/workspace/presentation/screens/workspace_selection_screen.dart';
import '../shared/models/workspace_type.dart';
import '../shared/widgets/coming_soon_screen.dart';
import 'route_guards.dart';
import 'shells/app_shell_scaffold.dart';

/// The single [GoRouter] instance, per FLUTTER_ARCHITECTURE.md §4.
///
/// Phase 7 adds the main application shell: Player Home, Coach Home, a
/// shared bottom-nav shell for each workspace, Settings, Notifications,
/// Profile, and the Become-a-Coach request flow. Timeline/History (Player)
/// and Live/Team/Alerts (Coach) are wired as real, navigable destinations
/// but render a shared placeholder screen — building them out is explicitly
/// future-phase work (Roadmap Phases 6–11), out of this phase's "Player
/// Home, Coach Home, Application Shell" scope.
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
        InOnboarding(:final workspace) => _onboardingRedirect(location, workspace),
        InApp(:final workspace) => _appRedirect(location, workspace),
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
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShellScaffold(workspace: WorkspaceType.player, navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoute.homePath(WorkspaceType.player),
                name: 'player-home',
                builder: (context, state) => const PlayerHomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoute.playerTimelinePath,
                name: 'player-timeline',
                builder: (context, state) => const ComingSoonScreen(title: 'Timeline'),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoute.playerHistoryPath,
                name: 'player-history',
                builder: (context, state) => const ComingSoonScreen(title: 'History'),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoute.profilePath(WorkspaceType.player),
                name: 'player-profile',
                builder: (context, state) =>
                    const ProfileScreen(workspace: WorkspaceType.player),
              ),
            ],
          ),
        ],
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShellScaffold(workspace: WorkspaceType.coach, navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoute.homePath(WorkspaceType.coach),
                name: 'coach-home',
                builder: (context, state) => const CoachHomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoute.coachLivePath,
                name: 'coach-live',
                builder: (context, state) =>
                    const ComingSoonScreen(title: 'Live Team Monitoring'),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoute.coachTeamPath,
                name: 'coach-team',
                builder: (context, state) => const ComingSoonScreen(title: 'Team'),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoute.coachAlertsPath,
                name: 'coach-alerts',
                builder: (context, state) => const ComingSoonScreen(title: 'Alerts'),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoute.profilePath(WorkspaceType.coach),
                name: 'coach-profile',
                builder: (context, state) =>
                    const ProfileScreen(workspace: WorkspaceType.coach),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoute.settingsPath(WorkspaceType.player),
        name: 'player-settings',
        builder: (context, state) => const SettingsScreen(workspace: WorkspaceType.player),
      ),
      GoRoute(
        path: AppRoute.settingsPath(WorkspaceType.coach),
        name: 'coach-settings',
        builder: (context, state) => const SettingsScreen(workspace: WorkspaceType.coach),
      ),
      GoRoute(
        path: AppRoute.notificationsPath(WorkspaceType.player),
        name: 'player-notifications',
        builder: (context, state) => const NotificationCenterScreen(),
      ),
      GoRoute(
        path: AppRoute.notificationsPath(WorkspaceType.coach),
        name: 'coach-notifications',
        builder: (context, state) => const NotificationCenterScreen(),
      ),
      GoRoute(
        path: AppRoute.becomeCoachPath,
        name: 'become-a-coach',
        builder: (context, state) => const BecomeACoachScreen(),
      ),
      GoRoute(
        path: AppRoute.becomeCoachCompletePath,
        name: 'become-a-coach-complete',
        builder: (context, state) => const BecomeACoachCompleteScreen(),
      ),
    ],
  );
});

/// [InOnboarding] gates an entire subtree, not one exact path — free
/// forward/back navigation among a workspace's own onboarding steps, and a
/// forced jump to that workspace's entry step (Level) only when arriving
/// from outside the subtree entirely.
String? _onboardingRedirect(String location, WorkspaceType workspace) {
  if (location.startsWith(OnboardingRoute.subtreePrefix(workspace))) {
    return null;
  }
  return OnboardingRoute.levelPath(workspace);
}

/// [InApp] gates the app shell subtree (`/{workspace}/**` — the bottom-nav
/// tabs plus Settings/Notifications/Become-a-Coach, all sharing the same
/// prefix), the same subtree-gating pattern as onboarding. A forced jump
/// to that workspace's Home only when arriving from outside the subtree.
String? _appRedirect(String location, WorkspaceType workspace) {
  if (location.startsWith(AppRoute.subtreePrefix(workspace))) {
    return null;
  }
  return AppRoute.homePath(workspace);
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

/// Path helpers for the app shell subtree, `/{workspace}/**` — added
/// Phase 7. [playerTimelinePath]/[playerHistoryPath]/[coachLivePath]/
/// [coachTeamPath]/[coachAlertsPath] are workspace-specific bottom-nav
/// destinations (their names differ per workspace, unlike [homePath]/
/// [profilePath]/[settingsPath]/[notificationsPath], which every
/// workspace has an equivalent of).
abstract final class AppRoute {
  static String subtreePrefix(WorkspaceType workspace) =>
      '/${workspace.firestoreKey}/';

  static String homePath(WorkspaceType workspace) => '${subtreePrefix(workspace)}home';

  static const String playerTimelinePath = '/player/timeline';
  static const String playerHistoryPath = '/player/history';
  static const String coachLivePath = '/coach/live';
  static const String coachTeamPath = '/coach/team';
  static const String coachAlertsPath = '/coach/alerts';

  static String profilePath(WorkspaceType workspace) =>
      '${subtreePrefix(workspace)}profile';

  static String settingsPath(WorkspaceType workspace) =>
      '${subtreePrefix(workspace)}settings';

  static String notificationsPath(WorkspaceType workspace) =>
      '${subtreePrefix(workspace)}notifications';

  static const String becomeCoachPath = '/player/become-a-coach';
  static const String becomeCoachCompletePath = '/player/become-a-coach/complete';
}
