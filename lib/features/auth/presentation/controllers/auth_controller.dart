import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/auth_repository_impl.dart';

/// Drives the Sign In / Create Account screen's single "Continue" action.
/// `AsyncNotifier` because this is async, mutable, user-triggered state —
/// per FLUTTER_ARCHITECTURE.md §5's provider-type guidance.
class AuthController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {
    // Idle by default; `submit` drives loading/data/error transitions.
  }

  Future<void> submit({required String email, required String password}) async {
    state = const AsyncLoading();
    final repository = ref.read(authRepositoryProvider);
    final result = await repository.signInOrCreateAccount(
      email: email,
      password: password,
    );
    state = result.fold(
      onSuccess: (_) => const AsyncData(null),
      onFailure: (failure) => AsyncError(failure, StackTrace.current),
    );
  }
}

final authControllerProvider = AsyncNotifierProvider<AuthController, void>(
  AuthController.new,
);
