import { HttpsError, CallableRequest } from "firebase-functions/v2/https";

/**
 * Phase 13 §3 — the backend half of Become-a-Coach approval
 * (`approveCoachRequest`). Mirrors `ingestionAuth.ts`'s `ingestor: true`
 * custom-claim pattern: a dedicated Firebase Auth principal carrying
 * `{ admin: true }`, never a product-facing Player/Coach account and
 * never a client-supplied value. Provisioning this claim (via the
 * Admin SDK's `setCustomUserClaims`, run by the project owner against a
 * specific trusted uid) is operational tooling outside this codebase's
 * scope — the same category of action as the ingestion principal's own
 * provisioning (BACKEND_SPECIFICATION.md §3) and as prior "requires
 * project owner" items (DECISIONS.md ADR-050). No admin UI exists in
 * this codebase; this function makes the approval *outcome* real and
 * Cloud-Function-authoritative, without needing one built this phase.
 */
export function requireAdminPrincipal(request: CallableRequest<unknown>): string {
  const uid = request.auth?.uid;
  const token = request.auth?.token;
  if (uid == null || token == null) {
    throw new HttpsError("unauthenticated", "This function requires a signed-in caller.");
  }
  if (token["admin"] !== true) {
    throw new HttpsError(
      "permission-denied",
      "The calling principal is not an authorized admin."
    );
  }
  return uid;
}
