import { onCall, HttpsError } from "firebase-functions/v2/https";
import { Timestamp } from "firebase-admin/firestore";
import { db } from "../lib/admin";
import { requireIngestionPrincipal, requireTeamInScope } from "../lib/ingestionAuth";
import { parseIngestLiveTickPayload } from "../contracts/types";

/**
 * BACKEND_SPECIFICATION.md §17/§21.4 — upserts the single, fixed-ID
 * `sessions/{sessionId}/live/current` document, overwritten roughly once
 * per second while the session is live (§1.9). Called approximately once
 * per second for the session's duration; `fanOutLiveMonitoring`
 * (triggers/fanOutLiveMonitoring.ts) reacts to this write to maintain the
 * coach-facing `teams/{teamId}/liveMonitoring/{playerId}` projection.
 *
 * §19's ordering guarantee is `sequenceNumber`, not write order — this
 * function does not reject an out-of-order tick (the laptop's own
 * offline-buffering can deliver ticks late after a reconnect); it simply
 * writes what it's given. Only a strictly-decreasing `sequenceNumber`
 * relative to the currently-stored value is rejected, since Firestore
 * has no way to reorder an already-overwritten document — this makes the
 * function idempotent against out-of-order delivery within a session,
 * rather than silently corrupting the "latest" projection with stale data.
 */
export const ingestLiveTick = onCall(async (request) => {
  const claims = requireIngestionPrincipal(request);
  const payload = parseIngestLiveTickPayload(request.data);
  requireTeamInScope(claims, payload.teamId ?? null);

  const sessionRef = db().collection("sessions").doc(payload.sessionId);
  const liveRef = sessionRef.collection("live").doc("current");

  await db().runTransaction(async (tx) => {
    const [sessionSnap, liveSnap] = await Promise.all([tx.get(sessionRef), tx.get(liveRef)]);
    if (!sessionSnap.exists) {
      throw new HttpsError(
        "failed-precondition",
        `sessions/${payload.sessionId} does not exist — call startSession first.`
      );
    }
    if (sessionSnap.data()?.["status"] !== "live") {
      throw new HttpsError(
        "failed-precondition",
        `sessions/${payload.sessionId} is not live.`
      );
    }
    const currentSequence = liveSnap.exists
      ? (liveSnap.data()?.["sequenceNumber"] as number | undefined)
      : undefined;
    if (currentSequence != null && payload.sequenceNumber <= currentSequence) {
      // A tick that has already been superseded — write-idempotent no-op,
      // not an error: the laptop's offline buffer may redeliver.
      return;
    }

    tx.set(liveRef, {
      sessionId: payload.sessionId,
      playerId: payload.playerId,
      ...(payload.teamId != null ? { teamId: payload.teamId } : {}),
      sequenceNumber: payload.sequenceNumber,
      tickTimestamp: Timestamp.fromDate(payload.tickTimestamp),
      serverReceivedAt: Timestamp.now(),
      connectionStatus: payload.connectionStatus,
      metrics: payload.metrics,
      ...(payload.deviceBattery != null ? { deviceBattery: payload.deviceBattery } : {}),
    });
  });

  return { sessionId: payload.sessionId, sequenceNumber: payload.sequenceNumber };
});
