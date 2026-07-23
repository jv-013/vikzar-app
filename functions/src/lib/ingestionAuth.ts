import { HttpsError, CallableRequest } from "firebase-functions/v2/https";

/**
 * BACKEND_SPECIFICATION.md §3 — the Laptop ETL/ML Pipeline authenticates as
 * a dedicated Firebase Auth account carrying custom claims
 * `{ ingestor: true, orgId, teamIds: [...] }`. Every ingestion Callable
 * function must verify `ingestor === true` and that the payload's
 * `teamId`/`orgId` falls within the token's authorized scope before
 * performing any write (§0's non-negotiable trust-boundary constraint).
 */
export interface IngestionClaims {
  ingestor: true;
  orgId: string;
  teamIds: string[];
}

/**
 * Verifies the caller is an authenticated ingestion principal. Throws
 * `HttpsError` (`unauthenticated`/`permission-denied`) otherwise — never
 * silently proceeds, per §0.
 */
export function requireIngestionPrincipal(
  request: CallableRequest<unknown>
): IngestionClaims {
  const token = request.auth?.token;
  if (!token) {
    throw new HttpsError(
      "unauthenticated",
      "This function may only be called by an authenticated ingestion principal."
    );
  }
  if (token["ingestor"] !== true) {
    throw new HttpsError(
      "permission-denied",
      "The calling principal is not an authorized ingestion principal."
    );
  }
  const orgId = token["orgId"];
  const teamIds = token["teamIds"];
  if (typeof orgId !== "string" || orgId.length === 0) {
    throw new HttpsError(
      "permission-denied",
      "Ingestion principal is missing its orgId claim."
    );
  }
  if (!Array.isArray(teamIds) || !teamIds.every((id) => typeof id === "string")) {
    throw new HttpsError(
      "permission-denied",
      "Ingestion principal is missing its teamIds claim."
    );
  }
  return { ingestor: true, orgId, teamIds };
}

/**
 * Verifies a payload's `teamId` (if present — an individual session may
 * have none) falls within the ingestion principal's authorized scope.
 * `teamId == null` (an individual, non-team session) is always in scope —
 * §6 notes an individual session belongs to no team and so cannot be
 * scope-restricted by one.
 */
export function requireTeamInScope(
  claims: IngestionClaims,
  teamId: string | null | undefined
): void {
  if (teamId == null) return;
  if (!claims.teamIds.includes(teamId)) {
    throw new HttpsError(
      "permission-denied",
      `Ingestion principal is not authorized for teamId "${teamId}".`
    );
  }
}

/**
 * Verifies a payload's `orgId` (if present) matches the ingestion
 * principal's own `orgId` claim.
 */
export function requireOrgInScope(
  claims: IngestionClaims,
  orgId: string | null | undefined
): void {
  if (orgId == null) return;
  if (claims.orgId !== orgId) {
    throw new HttpsError(
      "permission-denied",
      `Ingestion principal is not authorized for orgId "${orgId}".`
    );
  }
}
