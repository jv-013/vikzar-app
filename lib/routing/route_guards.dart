import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/data/repositories/auth_repository_impl.dart';
import '../features/auth/domain/models/auth_state.dart';
import '../features/workspace/presentation/controllers/active_workspace_controller.dart';
import '../shared/models/user_workspaces.dart';
import '../shared/models/workspace_type.dart';
import '../shared/repositories/user_repository_impl.dart';

/// Where the router should currently be, computed from auth state, the
/// user's Firestore profile, and the local active-workspace pointer — the
/// full decision table from FLUTTER_ARCHITECTURE.md §4, scoped to what
/// this phase actually builds (Splash, Auth, Workspace Selection, and an
/// onboarding placeholder; no Player/Coach Home).
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

final class GoToOnboardingPlaceholder extends RouteDestination {
  const GoToOnboardingPlaceholder(this.workspace);

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

      final userAsync = ref.watch(watchUserProvider(authState.uid));
      return userAsync.when(
        loading: () => const StayOnSplash(),
        error: (_, _) => const GoToWorkspaceSelection(),
        data: (result) => result.fold(
          onSuccess: (user) {
            final workspaces = user?.workspaces ?? const UserWorkspaces.empty();
            if (workspaces.isEmpty) {
              return const GoToWorkspaceSelection();
            }
            final active =
                ref.watch(activeWorkspaceProvider) ??
                user?.defaultWorkspace ??
                workspaces.held.first;
            return GoToOnboardingPlaceholder(active);
          },
          // A missing/unreadable profile document is treated the same as
          // "no workspaces yet" — see shared/repositories/user_repository.dart's
          // note on the not-yet-specified user-document-creation trigger.
          onFailure: (_) => const GoToWorkspaceSelection(),
        ),
      );
    },
  );
});

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
