import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/result/result.dart';
import '../../../../shared/models/workspace_type.dart';
import '../../../../shared/providers/current_uid_provider.dart';
import '../../../../shared/repositories/user_repository_impl.dart';
import '../../../team/data/repositories/team_repository_impl.dart';
import '../../domain/models/coach_onboarding_data.dart';
import 'coach_onboarding_controller.dart';
import 'player_onboarding_controller.dart';

class OnboardingCompletionState {
  const OnboardingCompletionState({this.isSubmitting = false, this.failure});

  final bool isSubmitting;
  final Failure? failure;

  OnboardingCompletionState copyWith({
    bool? isSubmitting,
    Failure? failure,
    bool clearFailure = false,
  }) {
    return OnboardingCompletionState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }
}

/// Drives "Get Started" on `OnboardingCompleteScreen` — Phase 8B work that
/// turns the in-memory onboarding data collected by
/// [PlayerOnboardingController]/[CoachOnboardingController] into real
/// `users/{uid}` (and, for a coach, `teams/{teamId}`) writes, per
/// DECISIONS.md ADR-051.
///
/// On success, no explicit navigation happens here — same hand-off pattern
/// as the screen's previous local-flag version: `routing/route_guards.dart`
/// watches `watchUserProvider(uid)`, and the Firestore write this
/// triggers is what flips its `InOnboarding` → `InApp` decision.
///
/// Riverpod 3's non-codegen `Notifier` has no built-in `build(arg)`
/// family hook (unlike Riverpod 2.x's `FamilyNotifier`) — the workspace
/// this instance is for is instead captured as a constructor field,
/// supplied by `NotifierProvider.family`'s `NotifierT Function(ArgT arg)`
/// factory below.
class OnboardingCompletionController extends Notifier<OnboardingCompletionState> {
  OnboardingCompletionController(this.workspace);

  final WorkspaceType workspace;

  @override
  OnboardingCompletionState build() => const OnboardingCompletionState();

  Future<void> complete() async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;

    state = state.copyWith(isSubmitting: true, clearFailure: true);

    final email = ref.read(currentUserEmailProvider) ?? '';

    final result = switch (workspace) {
      WorkspaceType.player => await _completePlayer(uid, email),
      WorkspaceType.coach => await _completeCoach(uid, email),
    };

    state = result.fold(
      onSuccess: (_) =>
          state.copyWith(isSubmitting: false, clearFailure: true),
      onFailure: (failure) =>
          state.copyWith(isSubmitting: false, failure: failure),
    );
  }

  Future<Result<void>> _completePlayer(String uid, String email) {
    final data = ref.read(playerOnboardingControllerProvider);
    return ref.read(userRepositoryProvider).completePlayerOnboarding(
      uid: uid,
      email: email,
      displayName: data.profile.name.trim(),
      profile: data.toPlayerProfile(),
    );
  }

  Future<Result<void>> _completeCoach(String uid, String email) async {
    final data = ref.read(coachOnboardingControllerProvider);
    final teamRepository = ref.read(teamRepositoryProvider);

    final String teamId;
    switch (data.team.mode) {
      case TeamSetupMode.create:
        switch (await teamRepository.createTeam(name: data.team.teamName.trim())) {
          case Success<({String teamId, String inviteCode})>(value: final created):
            teamId = created.teamId;
          case ResultFailure<({String teamId, String inviteCode})>(failure: final failure):
            return Result.failure(failure);
        }
      case TeamSetupMode.join:
        final joinId = data.team.inviteCode.trim();
        final joined = await teamRepository.joinTeamAsCoach(teamId: joinId);
        if (joined.isFailure) return joined;
        teamId = joinId;
      case null:
        // Unreachable in practice: `CreateJoinTeamScreen` only allows
        // "Continue" once `TeamSetupData.isComplete` (a mode is chosen),
        // which is what routes here at all.
        return const Result.failure(
          UnknownFailure(message: 'missing-team-setup'),
        );
    }

    return ref.read(userRepositoryProvider).completeCoachOnboarding(
      uid: uid,
      email: email,
      displayName: data.profile.name.trim(),
      profile: data.toCoachProfile(),
      teamId: teamId,
    );
  }
}

final onboardingCompletionControllerProvider = NotifierProvider.family<
  OnboardingCompletionController,
  OnboardingCompletionState,
  WorkspaceType
>(OnboardingCompletionController.new);
