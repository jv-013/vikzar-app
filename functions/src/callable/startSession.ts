import { onCall, HttpsError } from "firebase-functions/v2/https";
import { Timestamp } from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";
import { db } from "../lib/admin";
import { requireIngestionPrincipal, requireOrgInScope, requireTeamInScope } from "../lib/ingestionAuth";
import { parseStartSessionPayload } from "../contracts/types";

/**
 * BACKEND_SPECIFICATION.md §17/§21.3 — creates `sessions/{sessionId}` with
 * `status: "live"`. Cloud-Function-only write, per §1.8 ("Never
 * client-written"). Fails with `already-exists` if the caller reuses a
 * `sessionId` — §21.1 requires the laptop to generate a fresh UUID v4 per
 * session; a collision means a client bug, not a valid retry (a retry of
 * `startSession` itself would be redundant since the first call already
 * succeeded, and the laptop's own offline-buffering strategy is scoped to
 * `ingestLiveTick`, per §19).
 */
export const startSession = onCall(async (request) => {
  const claims = requireIngestionPrincipal(request);
  const payload = parseStartSessionPayload(request.data);
  requireTeamInScope(claims, payload.teamId ?? null);
  requireOrgInScope(claims, payload.orgId ?? null);

  const ref = db().collection("sessions").doc(payload.sessionId);
  const existing = await ref.get();
  if (existing.exists) {
    throw new HttpsError(
      "already-exists",
      `sessions/${payload.sessionId} already exists.`
    );
  }

  const now = Timestamp.now();
  await ref.set({
    sessionId: payload.sessionId,
    playerId: payload.playerId,
    ...(payload.teamId != null ? { teamId: payload.teamId } : {}),
    ...(payload.orgId != null ? { orgId: payload.orgId } : {}),
    type: payload.type,
    deviceIds: payload.deviceIds,
    status: "live",
    startedAt: Timestamp.fromDate(payload.startedAt),
    generatedBy: "laptop_ingestion_pipeline",
    createdAt: now,
    updatedAt: now,
  });

  logger.info("start_session_succeeded", { sessionId: payload.sessionId, playerId: payload.playerId });
  return { sessionId: payload.sessionId };
});
