import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/data/repositories/auth_repository_impl.dart';
import '../features/auth/domain/models/auth_state.dart';
import '../features/workspace/presentation/controllers/active_workspace_controller.dart';
import '../shared/models/app_user.dart';
import '../shared/models/workspace_type.dart';
import '../shared/repositories/user_repository_impl.dart';

/// Where the router should currently be, computed from auth state, the
/// local active-workspace pointer, and — **revised at Phase 8B**, per
/// DECISIONS.md ADR-051 — the user's Firestore `users/{uid}` document,
/// which is now the source of truth for which workspace(s) an account has
/// actually completed onboarding for (`workspaces.has(type)`), not a local
/// flag. The active-workspace *pointer* itself remains local-only, per
/// ADR-031/ADR-052 — only the *completion* signal moved to Firestore.
sealed class RouteDestination {
  const RouteDestination();
}

/// Auth/profile state is still resolving — stay on Splash.
final class StayOnSplash extends RouteDestination {
  const StayOnSplash();
}

final class GoToAuth extends RouteDestination {
  const GoToAuth();
}

final class GoToWorkspaceSelection extends RouteDestination {
  const GoToWorkspaceSelection();
}

/// Authenticated with a workspace chosen, but this device hasn't completed
/// that workspace's onboarding yet. Gates the entire onboarding **subtree**
/// (`/onboarding/{workspace}/**`), not one exact path — see
/// `app_router.dart`'s redirect, which allows free forward/back navigation
/// among that workspace's onboarding steps and only forces a jump when
/// arriving from *outside* the subtree.
final class InOnboarding extends RouteDestination {
  const InOnboarding(this.workspace);

  final WorkspaceType workspace;
}

/// Authenticated, workspace chosen, and Firestore records that workspace
/// as onboarded (`users/{uid}.workspaces.{type}` present, per
/// BACKEND_SPECIFICATION.md §1.5) — the main application shell (Home,
/// Timeline, Settings, Notifications, everything under `/{workspace}/**`).
final class InApp extends RouteDestination {
  const InApp(this.workspace);

  final WorkspaceType workspace;
}

/// The single source of truth `redirect` reads from, per
/// FLUTTER_ARCHITECTURE.md §4. One provider watching every relevant piece
/// of state, recomputing automatically — `RouterRefreshNotifier` below
/// only needs to listen to this one provider, not each dependency
/// separately.
final routeDestinationProvider = Provider<RouteDestination>((ref) {
  final authAsync = ref.watch(authStateProvider);

  return authAsync.when(
    loading: () => const StayOnSplash(),
    error: (_, _) => const GoToAuth(), // safest default: treat as signed out
    data: (authState) {
      if (authState is! Authenticated) return const GoToAuth();

      // Onboarding completion now lives in Firestore (ADR-051), so every
      // path below needs this document, not just the "no local pointer
      // yet" fallback Phase 7 had. Firestore's offline persistence
      // (services/firebase/firestore_service.dart) keeps this fast on
      // repeat launches even offline — only a brand-new device/session
      // sees a real network round-trip here.
      final userAsync = ref.watch(watchUserProvider(authState.uid));
      return userAsync.when(
        loading: () => const StayOnSplash(),
        error: (_, _) => const StayOnSplash(),
        data: (result) => result.fold(
          onSuccess: (user) => _destinationForUser(ref, user),
          // A missing/unreadable profile document is treated the same as
          // "no workspace recorded yet."
          onFailure: (_) => _destinationForUser(ref, null),
        ),
      );
    },
  );
});

RouteDestination _destinationForUser(Ref ref, AppUser? user) {
  // The active-workspace *pointer* is always local-only (ADR-031/ADR-052);
  // it's set as soon as Workspace Selection is confirmed, before that
  // workspace's onboarding is necessarily complete. Fall back to
  // Firestore's `defaultWorkspace` only when this device has no local
  // pointer yet (e.g. a new device on an existing account).
  final workspace = ref.watch(activeWorkspaceProvider) ?? user?.defaultWorkspace;
  if (workspace == null) return const GoToWorkspaceSelection();

  final hasCompletedOnboarding = user?.workspaces.has(workspace) ?? false;
  return hasCompletedOnboarding ? InApp(workspace) : InOnboarding(workspace);
}

/// Bridges Riverpod state changes to go_router's `refreshListenable`,
/// per FLUTTER_ARCHITECTURE.md §4 — the standard integration pattern for
/// the two: go_router's `redirect` alone only re-runs on navigation
/// attempts, not on background state changes (e.g. sign-in completing
/// while still on Splash), so this notifies it explicitly.
class RouterRefreshNotifier extends ChangeNotifier {
  RouterRefreshNotifier(Ref ref) {
    _subscription = ref.listen<RouteDestination>(
      routeDestinationProvider,
      (_, _) => notifyListeners(),
    );
  }

  late final ProviderSubscription<RouteDestination> _subscription;

  @override
  void dispose() {
    _subscription.close();
    super.dispose();
  }
}
