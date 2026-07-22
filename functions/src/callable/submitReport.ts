import { onCall } from "firebase-functions/v2/https";
import { Timestamp } from "firebase-admin/firestore";
import { db } from "../lib/admin";
import { requireIngestionPrincipal, requireTeamInScope } from "../lib/ingestionAuth";
import { parseSubmitReportPayload } from "../contracts/types";

/**
 * BACKEND_SPECIFICATION.md §17/§21.7 — creates `reports/{reportId}` with
 * `type: "session_report"` (auto-generated ID, per §21.7's example, which
 * never supplies one). Called once, alongside `completeSession`, for the
 * session's full report. `status: "final"` — this function is only ever
 * called with a session's complete summary, never a partial/draft one;
 * `"draft"` (§1.11) is reserved for a future report-generation path this
 * function does not implement. `onReportCreated`
 * (triggers/onReportCreated.ts) reacts to the resulting document creation.
 */
export const submitReport = onCall(async (request) => {
  const claims = requireIngestionPrincipal(request);
  const payload = parseSubmitReportPayload(request.data);
  requireTeamInScope(claims, payload.teamId ?? null);

  const ref = db().collection("reports").doc();
  await ref.set({
    reportId: ref.id,
    type: "session_report",
    playerId: payload.playerId,
    ...(payload.teamId != null ? { teamId: payload.teamId } : {}),
    ...(claims.orgId != null ? { orgId: claims.orgId } : {}),
    sessionId: payload.sessionId,
    generatedAt: Timestamp.fromDate(payload.generatedAt),
    generatedBy: "laptop_ml_pipeline",
    summary: payload.summary,
    ...(payload.storagePath != null ? { storagePath: payload.storagePath } : {}),
    status: "final",
  });

  return { reportId: ref.id };
});
