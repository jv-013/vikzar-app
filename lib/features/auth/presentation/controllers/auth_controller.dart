import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failure.dart';
import '../../data/repositories/auth_repository_impl.dart';

enum AuthStep { email, otp }

/// Drives the two-step passwordless Sign In / Create Account flow
/// (DESIGN_SPECIFICATION.md §19.1, revised Phase 6). A plain [Notifier],
/// not [AsyncNotifier]: the screen needs to track *which step* it's on
/// simultaneously with loading/error state, which an [AsyncNotifier]'s
/// three-state model doesn't cleanly express across two steps.
class AuthFlowState {
  const AuthFlowState({
    this.step = AuthStep.email,
    this.email = '',
    this.isSubmitting = false,
    this.failure,
  });

  final AuthStep step;
  final String email;
  final bool isSubmitting;
  final Failure? failure;

  AuthFlowState copyWith({
    AuthStep? step,
    String? email,
    bool? isSubmitting,
    Failure? failure,
    bool clearFailure = false,
  }) {
    return AuthFlowState(
      step: step ?? this.step,
      email: email ?? this.email,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }
}

class AuthController extends Notifier<AuthFlowState> {
  @override
  AuthFlowState build() => const AuthFlowState();

  Future<void> submitEmail(String email) async {
    state = state.copyWith(isSubmitting: true, clearFailure: true);
    final repository = ref.read(authRepositoryProvider);
    final result = await repository.sendOtp(email: email);
    state = result.fold(
      onSuccess: (_) => state.copyWith(
        step: AuthStep.otp,
        email: email,
        isSubmitting: false,
        clearFailure: true,
      ),
      onFailure: (failure) =>
          state.copyWith(isSubmitting: false, failure: failure),
    );
  }

  Future<void> submitOtp(String code) async {
    state = state.copyWith(isSubmitting: true, clearFailure: true);
    final repository = ref.read(authRepositoryProvider);
    final result = await repository.verifyOtp(email: state.email, code: code);
    state = result.fold(
      // On success, `authStateProvider` picks up the new session and the
      // router (routing/route_guards.dart) moves on — this screen never
      // navigates itself.
      onSuccess: (_) => state.copyWith(isSubmitting: false, clearFailure: true),
      onFailure: (failure) =>
          state.copyWith(isSubmitting: false, failure: failure),
    );
  }

  Future<void> resendOtp() => submitEmail(state.email);

  /// Back from the code step to the email step (e.g. a mistyped address).
  void editEmail() {
    state = state.copyWith(step: AuthStep.email, clearFailure: true);
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthFlowState>(
  AuthController.new,
);
