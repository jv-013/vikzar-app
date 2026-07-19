import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/data/repositories/auth_repository_impl.dart';
import '../features/auth/domain/models/auth_state.dart';
import '../features/workspace/presentation/controllers/active_workspace_controller.dart';
import '../services/local_storage/onboarding_progress_store.dart';
import '../shared/models/workspace_type.dart';
import '../shared/repositories/user_repository_impl.dart';

/// Where the router should currently be, computed from auth state, the
/// local active-workspace pointer, and the local onboarding-completion
/// record — with the user's Firestore profile consulted only as a
/// fallback for a *new device* on an *existing* account.
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

/// Authenticated, workspace chosen, and this device has already completed
/// that workspace's onboarding (`OnboardingProgressStore`, per
/// [DECISIONS.md ADR-046]) — the main application shell (Home, Timeline,
/// Settings, Notifications, everything under `/{workspace}/**`). Revised
/// at Phase 7: this used to mean "stay on the Onboarding Complete screen
/// forever"; it now means "the app shell."
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

      final activeWorkspace = ref.watch(activeWorkspaceProvider);
      if (activeWorkspace != null) {
        return _destinationFor(ref, activeWorkspace);
      }

      // No local pointer yet on this device. Fall back to Firestore's
      // defaultWorkspace, which only exists if this account already
      // completed onboarding on a *different* device in some prior
      // session — today that can't actually happen (no Cloud Function
      // writes it yet, per DECISIONS.md ADR-041), but the check costs
      // nothing and keeps this logic correct once one exists.
      final userAsync = ref.watch(watchUserProvider(authState.uid));
      return userAsync.when(
        loading: () => const StayOnSplash(),
        error: (_, _) => const GoToWorkspaceSelection(),
        data: (result) => result.fold(
          onSuccess: (user) {
            final fallback = user?.defaultWorkspace;
            if (fallback == null) return const GoToWorkspaceSelection();
            return _destinationFor(ref, fallback);
          },
          // A missing/unreadable profile document is treated the same as
          // "no workspace recorded yet."
          onFailure: (_) => const GoToWorkspaceSelection(),
        ),
      );
    },
  );
});

RouteDestination _destinationFor(Ref ref, WorkspaceType workspace) {
  final completed = ref.watch(onboardingCompletionProvider).contains(workspace);
  return completed ? InApp(workspace) : InOnboarding(workspace);
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
