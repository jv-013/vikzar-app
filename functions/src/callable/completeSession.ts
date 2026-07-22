import { onCall, HttpsError } from "firebase-functions/v2/https";
import { Timestamp } from "firebase-admin/firestore";
import { db } from "../lib/admin";
import { requireIngestionPrincipal, requireTeamInScope } from "../lib/ingestionAuth";
import { parseCompleteSessionPayload } from "../contracts/types";

/**
 * BACKEND_SPECIFICATION.md §17/§21.5 — finalizes `sessions/{sessionId}`
 * with `summaryMetrics`, `status`, `endedAt`, `durationSeconds`,
 * `dataCompleteness`, `pipelineVersion`, and (if present)
 * `rawDataStoragePath`. Called once, at session end. `onSessionCompleted`
 * (triggers/onSessionCompleted.ts) reacts to the resulting status
 * transition.
 */
export const completeSession = onCall(async (request) => {
  const claims = requireIngestionPrincipal(request);
  const payload = parseCompleteSessionPayload(request.data);

  const ref = db().collection("sessions").doc(payload.sessionId);
  const snap = await ref.get();
  if (!snap.exists) {
    throw new HttpsError(
      "failed-precondition",
      `sessions/${payload.sessionId} does not exist — call startSession first.`
    );
  }
  const existing = snap.data()!;
  requireTeamInScope(claims, (existing["teamId"] as string | undefined) ?? null);
  if (existing["status"] !== "live") {
    throw new HttpsError(
      "failed-precondition",
      `sessions/${payload.sessionId} is not live (already "${existing["status"]}").`
    );
  }

  await ref.update({
    status: payload.status,
    endedAt: Timestamp.fromDate(payload.endedAt),
    durationSeconds: payload.durationSeconds,
    summaryMetrics: payload.summaryMetrics,
    dataCompleteness: payload.dataCompleteness,
    pipelineVersion: payload.pipelineVersion,
    ...(payload.rawDataStoragePath != null
      ? { rawDataStoragePath: payload.rawDataStoragePath }
      : {}),
    updatedAt: Timestamp.now(),
  });

  return { sessionId: payload.sessionId, status: payload.status };
});
