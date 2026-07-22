import { onCall } from "firebase-functions/v2/https";
import { Timestamp } from "firebase-admin/firestore";
import { db } from "../lib/admin";
import { requireIngestionPrincipal, requireTeamInScope } from "../lib/ingestionAuth";
import { parseSubmitAlertPayload } from "../contracts/types";

/**
 * BACKEND_SPECIFICATION.md §17/§21.6 — creates `alerts/{alertId}`
 * (auto-generated ID; the payload never supplies one, per §21.6's own
 * example). `source` is always `"laptop_risk_engine"` here — the other
 * documented source, `"cloud_function_device_health"`, is used only by
 * `deviceHeartbeatMonitor` (scheduled/deviceHeartbeatMonitor.ts), never by
 * this laptop-called function. `onAlertCreated`
 * (triggers/onAlertCreated.ts) reacts to the resulting document creation
 * to dispatch notifications.
 */
export const submitAlert = onCall(async (request) => {
  const claims = requireIngestionPrincipal(request);
  const payload = parseSubmitAlertPayload(request.data);
  requireTeamInScope(claims, payload.teamId ?? null);

  const ref = db().collection("alerts").doc();
  await ref.set({
    alertId: ref.id,
    sessionId: payload.sessionId,
    playerId: payload.playerId,
    ...(payload.teamId != null ? { teamId: payload.teamId } : {}),
    ...(claims.orgId != null ? { orgId: claims.orgId } : {}),
    severity: payload.severity,
    type: payload.type,
    message: payload.message,
    ...(payload.metricsSnapshot != null ? { metricsSnapshot: payload.metricsSnapshot } : {}),
    source: "laptop_risk_engine",
    triggeredAt: Timestamp.fromDate(payload.triggeredAt),
    acknowledged: false,
    ...(payload.contributingFactors != null
      ? { contributingFactors: payload.contributingFactors }
      : {}),
    ...(payload.recommendations != null ? { recommendations: payload.recommendations } : {}),
    ...(payload.confidence != null ? { confidence: payload.confidence } : {}),
    ...(payload.policyVersion != null ? { policyVersion: payload.policyVersion } : {}),
    ...(payload.modelVersion != null ? { modelVersion: payload.modelVersion } : {}),
    ...(payload.assessmentId != null ? { assessmentId: payload.assessmentId } : {}),
    ...(payload.assessmentChecksum != null
      ? { assessmentChecksum: payload.assessmentChecksum }
      : {}),
    createdAt: Timestamp.now(),
  });

  return { alertId: ref.id };
});
