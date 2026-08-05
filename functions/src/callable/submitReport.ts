import { onCall } from "firebase-functions/v2/https";
import { Timestamp } from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";
import { db } from "../lib/admin";
import { requireIngestionPrincipal, resolveSessionScope } from "../lib/ingestionAuth";
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
 *
 * Phase 13 §7 fix: `teamId` is now derived from the referenced session's
 * stored document, not trusted from the payload — same fix and same
 * reasoning as `ingestLiveTick`.
 */
export const submitReport = onCall(async (request) => {
  const claims = requireIngestionPrincipal(request);
  const payload = parseSubmitReportPayload(request.data);

  const { sessionTeamId } = await resolveSessionScope(claims, payload.sessionId, payload.teamId);

  const ref = db().collection("reports").doc();
  await ref.set({
    reportId: ref.id,
    type: "session_report",
    playerId: payload.playerId,
    ...(sessionTeamId != null ? { teamId: sessionTeamId } : {}),
    ...(claims.orgId != null ? { orgId: claims.orgId } : {}),
    sessionId: payload.sessionId,
    generatedAt: Timestamp.fromDate(payload.generatedAt),
    generatedBy: "laptop_ml_pipeline",
    summary: payload.summary,
    ...(payload.storagePath != null ? { storagePath: payload.storagePath } : {}),
    status: "final",
  });

  logger.info("submit_report_succeeded", { reportId: ref.id, type: "session_report" });
  return { reportId: ref.id };
});
