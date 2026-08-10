import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/result/result.dart';
import '../../../../services/local_storage/pending_email_link_store.dart';
import '../../data/repositories/auth_repository_impl.dart';

/// **Phase 17** replaces the two-step passwordless email/code flow with
/// three real Firebase Authentication providers (Google, Apple, Email
/// Link) — there is no "step" concept left; each sign-in method is a
/// single action from [AuthScreen]'s one screen.
class AuthFlowState {
  const AuthFlowState({
    this.isSubmitting = false,
    this.failure,
    this.magicLinkSent = false,
    this.pendingEmail = '',
  });

  final bool isSubmitting;
  final Failure? failure;

  /// True once [AuthController.sendMagicLink] succeeds — the screen shows
  /// a "check your email" confirmation instead of the email field.
  final bool magicLinkSent;

  /// The address the link was last sent to (or is being sent to) — shown
  /// back to the user in the confirmation copy and reused by
  /// [AuthController.resendMagicLink].
  final String pendingEmail;

  AuthFlowState copyWith({
    bool? isSubmitting,
    Failure? failure,
    bool? magicLinkSent,
    String? pendingEmail,
    bool clearFailure = false,
  }) {
    return AuthFlowState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      failure: clearFailure ? null : (failure ?? this.failure),
      magicLinkSent: magicLinkSent ?? this.magicLinkSent,
      pendingEmail: pendingEmail ?? this.pendingEmail,
    );
  }
}

class AuthController extends Notifier<AuthFlowState> {
  @override
  AuthFlowState build() {
    final pending = ref.watch(pendingEmailLinkStoreProvider).read();
    return AuthFlowState(pendingEmail: pending ?? '');
  }

  Future<void> signInWithGoogle() => _run(
    () => ref.read(authRepositoryProvider).signInWithGoogle(),
  );

  Future<void> signInWithApple() => _run(
    () => ref.read(authRepositoryProvider).signInWithApple(),
  );

  /// Step 1 of the magic-link flow: asks Firebase to email [email] a
  /// sign-in link, and remembers [email] locally so step 2
  /// ([completeSignInWithLink]) — which may run in a fresh app session
  /// after the user taps the emailed link — knows which address it's
  /// completing.
  Future<void> sendMagicLink(String email) async {
    final trimmed = email.trim();
    state = state.copyWith(pendingEmail: trimmed);
    await _run(() async {
      final result = await ref.read(authRepositoryProvider).sendSignInLinkToEmail(trimmed);
      if (result.isSuccess) {
        await ref.read(pendingEmailLinkStoreProvider).write(trimmed);
      }
      return result;
    }, onSuccess: () => state.copyWith(magicLinkSent: true));
  }

  Future<void> resendMagicLink() => sendMagicLink(state.pendingEmail);

  /// Back from the "check your email" confirmation to the entry form
  /// (e.g. a mistyped address).
  void editEmail() {
    state = state.copyWith(magicLinkSent: false, clearFailure: true);
  }

  /// Step 2: called with the URL the app was opened with (a Universal
  /// Link/App Link tap, or a deferred cold-start launch URL) once
  /// [AuthDatasource.isSignInWithEmailLink] confirms it's a Firebase
  /// sign-in link. Does nothing if there's no locally remembered pending
  /// email — e.g. the link is opened on a device that never requested it.
  Future<void> completeSignInWithLink(String link) async {
    final repository = ref.read(authRepositoryProvider);
    if (!repository.isSignInWithEmailLink(link)) return;

    final email = state.pendingEmail.isNotEmpty
        ? state.pendingEmail
        : ref.read(pendingEmailLinkStoreProvider).read();
    if (email == null || email.isEmpty) return;

    await _run(() async {
      final result = await repository.signInWithEmailLink(email: email, emailLink: link);
      if (result.isSuccess) {
        await ref.read(pendingEmailLinkStoreProvider).clear();
      }
      return result;
    });
  }

  Future<void> _run(
    Future<Result<void>> Function() action, {
    AuthFlowState Function()? onSuccess,
  }) async {
    state = state.copyWith(isSubmitting: true, clearFailure: true);
    final result = await action();
    // On overall success, `authStateProvider` picks up the new session
    // and the router (routing/route_guards.dart) moves on — this
    // controller never navigates itself.
    state = result.fold(
      onSuccess: (_) =>
          (onSuccess?.call() ?? state).copyWith(isSubmitting: false, clearFailure: true),
      onFailure: (failure) => state.copyWith(isSubmitting: false, failure: failure),
    );
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthFlowState>(
  AuthController.new,
);
