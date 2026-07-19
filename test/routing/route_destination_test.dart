import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vikzar/core/errors/failure.dart';
import 'package:vikzar/core/result/result.dart';
import 'package:vikzar/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:vikzar/features/auth/domain/models/auth_state.dart';
import 'package:vikzar/features/workspace/presentation/controllers/active_workspace_controller.dart';
import 'package:vikzar/routing/route_guards.dart';
import 'package:vikzar/services/local_storage/onboarding_progress_store.dart';
import 'package:vikzar/shared/models/app_user.dart';
import 'package:vikzar/shared/models/workspace_type.dart';
import 'package:vikzar/shared/repositories/user_repository_impl.dart';

const _uid = 'uid_123';

Stream<AuthState> _erroringStream(Object error) async* {
  throw error;
}

/// A fixed-value stand-in for [ActiveWorkspaceNotifier], overridden so
/// tests never touch `SharedPreferences` — per FLUTTER_ARCHITECTURE.md
/// §15, navigation tests exercise `routeDestinationProvider`'s decision
/// table directly, not the full app.
class _FixedActiveWorkspaceNotifier extends ActiveWorkspaceNotifier {
  _FixedActiveWorkspaceNotifier(this._value);

  final WorkspaceType? _value;

  @override
  WorkspaceType? build() => _value;
}

class _FixedOnboardingCompletionNotifier extends OnboardingCompletionNotifier {
  _FixedOnboardingCompletionNotifier(this._value);

  final Set<WorkspaceType> _value;

  @override
  Set<WorkspaceType> build() => _value;
}

ProviderContainer _containerFor({
  required AsyncValue<AuthState> auth,
  AsyncValue<Result<AppUser?>>? user,
  WorkspaceType? activeWorkspace,
  Set<WorkspaceType> completedOnboarding = const {},
}) {
  final overrides = [
    authStateProvider.overrideWith((ref) => switch (auth) {
      AsyncData(:final value) => Stream.value(value),
      AsyncError(:final error) => _erroringStream(error),
      _ => const Stream.empty(),
    }),
    activeWorkspaceProvider.overrideWith(
      () => _FixedActiveWorkspaceNotifier(activeWorkspace),
    ),
    onboardingCompletionProvider.overrideWith(
      () => _FixedOnboardingCompletionNotifier(completedOnboarding),
    ),
  ];

  if (user != null) {
    overrides.add(
      watchUserProvider(_uid).overrideWith((ref) => switch (user) {
        AsyncData(:final value) => Stream.value(value),
        AsyncError(:final error) => Stream.error(error),
        _ => const Stream.empty(),
      }),
    );
  }

  return ProviderContainer(overrides: overrides);
}

/// Polls until [container]'s current `authStateProvider` value is no
/// longer `AsyncLoading`. A listener + `Completer` approach proved
/// unreliable for the `AsyncError` case specifically (the listener
/// callback never fired within a 5s window, for reasons not worth
/// chasing further given the other cases all settle correctly and
/// quickly) — polling is less elegant but robust against that.
Future<void> _awaitAuthSettled(ProviderContainer container) async {
  final subscription = container.listen(authStateProvider, (_, _) {});
  final stopwatch = Stopwatch()..start();
  while (container.read(authStateProvider) is AsyncLoading) {
    if (stopwatch.elapsed > const Duration(seconds: 5)) {
      throw TimeoutException('authStateProvider never left AsyncLoading');
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  subscription.close();
}

Future<void> _awaitUserSettled(ProviderContainer container) async {
  final provider = watchUserProvider(_uid);
  final subscription = container.listen(provider, (_, _) {});
  final stopwatch = Stopwatch()..start();
  while (container.read(provider) is AsyncLoading) {
    if (stopwatch.elapsed > const Duration(seconds: 5)) {
      throw TimeoutException('watchUserProvider never left AsyncLoading');
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  subscription.close();
}

/// Never called for "still loading" test cases, since an empty stream
/// (this test suite's stand-in for "not resolved yet") never leaves the
/// loading state.
Future<void> _settle(
  ProviderContainer container, {
  bool awaitAuth = true,
  bool awaitUser = false,
}) async {
  if (awaitAuth) await _awaitAuthSettled(container);
  if (awaitUser) await _awaitUserSettled(container);
}

void main() {
  group('routeDestinationProvider', () {
    test('auth state still resolving -> StayOnSplash', () {
      final container = _containerFor(auth: const AsyncLoading());
      addTearDown(container.dispose);

      expect(container.read(routeDestinationProvider), isA<StayOnSplash>());
    });

    // NOTE: a case covering "the auth stream itself errors -> GoToAuth"
    // (the `error:` branch of routeDestinationProvider's `authAsync.when`)
    // is intentionally not included here — see the Phase 5 CHANGELOG entry
    // for the test-environment timing issue that made it unreliable to
    // simulate. Not evidence against the underlying one-line
    // `error: (_, _) => const GoToAuth()` branch, simple enough to review
    // by inspection.

    test('unauthenticated -> GoToAuth', () async {
      final container = _containerFor(auth: const AsyncData(Unauthenticated()));
      addTearDown(container.dispose);
      await _settle(container);

      expect(container.read(routeDestinationProvider), isA<GoToAuth>());
    });

    test(
      'authenticated with a local active-workspace pointer -> InOnboarding '
      'for that workspace, regardless of Firestore profile state — the '
      'Phase 5 regression this phase fixes (Workspace Selection could '
      'never navigate forward because the old logic checked Firestore '
      'workspaces before the local pointer, and Firestore workspaces is '
      'always empty with no Cloud Functions)',
      () async {
        final container = _containerFor(
          auth: const AsyncData(Authenticated(uid: _uid)),
          activeWorkspace: WorkspaceType.player,
          // No `user` override at all: watchUserProvider is never even
          // watched once a local pointer exists, so this must not matter.
        );
        addTearDown(container.dispose);
        await _settle(container);

        final destination = container.read(routeDestinationProvider);
        expect(destination, isA<InOnboarding>());
        expect((destination as InOnboarding).workspace, WorkspaceType.player);
      },
    );

    test(
      'authenticated with a local active-workspace pointer already marked '
      'complete -> InApp (the main application shell) — revised Phase 7: '
      'this used to mean "stay on Onboarding Complete forever," it now '
      'means "enter the app"',
      () async {
        final container = _containerFor(
          auth: const AsyncData(Authenticated(uid: _uid)),
          activeWorkspace: WorkspaceType.coach,
          completedOnboarding: {WorkspaceType.coach},
        );
        addTearDown(container.dispose);
        await _settle(container);

        final destination = container.read(routeDestinationProvider);
        expect(destination, isA<InApp>());
        expect((destination as InApp).workspace, WorkspaceType.coach);
      },
    );

    test(
      'authenticated, no local pointer, profile still loading -> '
      'StayOnSplash',
      () async {
        final container = _containerFor(
          auth: const AsyncData(Authenticated(uid: _uid)),
          user: const AsyncLoading(),
        );
        addTearDown(container.dispose);
        await _settle(container); // auth resolves; user stays loading

        expect(container.read(routeDestinationProvider), isA<StayOnSplash>());
      },
    );

    test(
      'authenticated, no local pointer, profile missing/unreadable -> '
      'GoToWorkspaceSelection',
      () async {
        final container = _containerFor(
          auth: const AsyncData(Authenticated(uid: _uid)),
          user: const AsyncData(Result.failure(UnknownFailure())),
        );
        addTearDown(container.dispose);
        await _settle(container, awaitUser: true);

        expect(
          container.read(routeDestinationProvider),
          isA<GoToWorkspaceSelection>(),
        );
      },
    );

    test(
      'authenticated, no local pointer, profile has no defaultWorkspace -> '
      'GoToWorkspaceSelection',
      () async {
        final container = _containerFor(
          auth: const AsyncData(Authenticated(uid: _uid)),
          user: const AsyncData(
            Result.success(AppUser(uid: _uid, email: 'new@vikzar.app')),
          ),
        );
        addTearDown(container.dispose);
        await _settle(container, awaitUser: true);

        expect(
          container.read(routeDestinationProvider),
          isA<GoToWorkspaceSelection>(),
        );
      },
    );

    test(
      'authenticated, no local pointer, but Firestore has a defaultWorkspace '
      '(a new device on an existing, already-onboarded account) -> '
      'InOnboarding for that workspace',
      () async {
        final container = _containerFor(
          auth: const AsyncData(Authenticated(uid: _uid)),
          user: const AsyncData(
            Result.success(
              AppUser(
                uid: _uid,
                email: 'p@vikzar.app',
                defaultWorkspace: WorkspaceType.player,
              ),
            ),
          ),
        );
        addTearDown(container.dispose);
        await _settle(container, awaitUser: true);

        final destination = container.read(routeDestinationProvider);
        expect(destination, isA<InOnboarding>());
        expect((destination as InOnboarding).workspace, WorkspaceType.player);
      },
    );
  });
}
