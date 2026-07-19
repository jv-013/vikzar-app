import '../../core/result/result.dart';
import '../models/app_user.dart';

/// Reads the `users/{uid}` profile — shared because Authentication routing,
/// Workspace, and (later) Profile all need it, per FLUTTER_ARCHITECTURE.md
/// §2's rule for what belongs in `shared/`.
///
/// No write methods exist here yet. Per BACKEND_SPECIFICATION.md §1.5,
/// `workspaces`/`defaultWorkspace` are Cloud-Function-written, not
/// client-writable — and this phase does not implement the onboarding
/// completion step that would call such a function (see
/// `features/workspace/` for what this phase does instead: a local-only
/// pending selection, not a Firestore write).
abstract interface class UserRepository {
  /// Emits `Result.success(null)` if the account is authenticated but no
  /// `users/{uid}` document exists yet (e.g. a brand-new sign-up, before
  /// any document-creation step has run — see BACKEND_SPECIFICATION.md
  /// Open Questions on this gap, flagged during this phase).
  Stream<Result<AppUser?>> watchUser(String uid);
}
