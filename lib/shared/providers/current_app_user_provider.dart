import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_user.dart';
import '../models/workspace_type.dart';
import '../repositories/user_repository_impl.dart';
import 'current_uid_provider.dart';

/// The authenticated account's `users/{uid}` document, or `null` when
/// signed out, still loading, or the read failed — every consumer here
/// (Profile Badge, Profile Sheet, Workspace Switch Sheet, Player/Coach
/// Home) already has its own honest empty/loading state for "no data yet,"
/// so collapsing loading/failure/absent into one `null` is a deliberate
/// simplification, not information loss any of them act on differently.
///
/// **Added Phase 8B** (DECISIONS.md ADR-051) to replace the local
/// `onboardingCompletionProvider` those widgets read from through Phase 7.
final currentAppUserProvider = Provider<AppUser?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return null;

  final userAsync = ref.watch(watchUserProvider(uid));
  return userAsync.when(
    data: (result) => result.fold(
      onSuccess: (user) => user,
      onFailure: (_) => null,
    ),
    loading: () => null,
    error: (_, _) => null,
  );
});

/// Every workspace the authenticated account currently holds, per
/// Firestore's `workspaces` map — the same signal
/// `routing/route_guards.dart` uses to decide `InApp` vs `InOnboarding`,
/// now shared with the profile UI that needs to know "is this account
/// single- or dual-workspace" (DECISIONS.md ADR-047).
final heldWorkspacesProvider = Provider<List<WorkspaceType>>((ref) {
  return ref.watch(currentAppUserProvider)?.workspaces.held ?? const [];
});
