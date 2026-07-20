import '../../../../core/result/result.dart';
import '../models/coach_request.dart';

/// `coachRequests/{requestId}` — BACKEND_SPECIFICATION.md §1.12. Creation
/// only; there is no admin-approval flow in this codebase (DECISIONS.md
/// ADR-049/ADR-051) — submitting a request never grants the workspace.
abstract interface class CoachRequestRepository {
  Future<Result<void>> submit(CoachRequest request);
}
