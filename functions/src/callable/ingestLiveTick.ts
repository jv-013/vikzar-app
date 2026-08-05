import { onCall, HttpsError } from "firebase-functions/v2/https";
import { Timestamp } from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";
import { db } from "../lib/admin";
import { requireIngestionPrincipal, requireTeamInScope } from "../lib/ingestionAuth";
import { enforceRateLimit } from "../lib/rateLimit";
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
 *
 * Also upserts `devices/{deviceId}` telemetry (`lastSeenAt`,
 * `lastKnownBattery`, `lastKnownRssi`, `connectivityStatus`) for every
 * device reported in this tick's `deviceBattery`/`deviceRssi` maps — §1.7
 * documents these as Cloud-Function-written, but before Phase 11 no
 * function actually wrote them, which left `deviceHeartbeatMonitor`
 * permanently unable to fire (it reads `lastSeenAt`, which was always
 * null). Fixed here, at the only call site that has this data.
 *
 * Phase 13 §7 fix: scope authorization is now derived from the *stored*
 * session document's `teamId`, not `payload.teamId` — previously the
 * caller's claimed `teamId` was trusted directly, so an ingestion
 * principal scoped to Team A that knew (or guessed) a Team-B `sessionId`
 * could omit `teamId` (bypassing the check as an "individual session")
 * or supply an in-scope value regardless of the session's real owner.
 * `completeSession` already used this correct pattern; the other two
 * laptop-callable functions did not.
 */
export const ingestLiveTick = onCall(async (request) => {
  const claims = requireIngestionPrincipal(request);
  const payload = parseIngestLiveTickPayload(request.data);
  // §10 — bounds a leaked/misbehaving principal's write rate. 20/second
  // comfortably covers several concurrent live sessions at the
  // documented ~1 tick/sec/session cadence without being a precision
  // throttle.
  await enforceRateLimit(request.auth!.uid, "ingestLiveTick", { maxCalls: 20, windowSeconds: 1 });

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

    const sessionTeamId = sessionSnap.data()?.["teamId"] as string | undefined;
    requireTeamInScope(claims, sessionTeamId ?? null);
    if (payload.teamId != null && payload.teamId !== sessionTeamId) {
      throw new HttpsError(
        "invalid-argument",
        `"teamId" does not match sessions/${payload.sessionId}'s recorded team.`
      );
    }

    const currentSequence = liveSnap.exists
      ? (liveSnap.data()?.["sequenceNumber"] as number | undefined)
      : undefined;
    if (currentSequence != null && payload.sequenceNumber <= currentSequence) {
      // A tick that has already been superseded — write-idempotent no-op,
      // not an error: the laptop's offline buffer may redeliver.
      logger.info("ingest_live_tick_stale_sequence_skipped", {
        sessionId: payload.sessionId,
        sequenceNumber: payload.sequenceNumber,
        currentSequence,
      });
      return;
    }

    tx.set(liveRef, {
      sessionId: payload.sessionId,
      playerId: payload.playerId,
      ...(sessionTeamId != null ? { teamId: sessionTeamId } : {}),
      sequenceNumber: payload.sequenceNumber,
      tickTimestamp: Timestamp.fromDate(payload.tickTimestamp),
      serverReceivedAt: Timestamp.now(),
      connectionStatus: payload.connectionStatus,
      metrics: payload.metrics,
      ...(payload.deviceBattery != null ? { deviceBattery: payload.deviceBattery } : {}),
      ...(payload.deviceRssi != null ? { deviceRssi: payload.deviceRssi } : {}),
      ...(payload.capturePhase != null ? { capturePhase: payload.capturePhase } : {}),
    });

    const deviceIds = new Set([
      ...Object.keys(payload.deviceBattery ?? {}),
      ...Object.keys(payload.deviceRssi ?? {}),
    ]);
    const now = Timestamp.now();
    for (const deviceId of deviceIds) {
      const battery = payload.deviceBattery?.[deviceId];
      const rssi = payload.deviceRssi?.[deviceId];
      tx.set(
        db().collection("devices").doc(deviceId),
        {
          lastSeenAt: now,
          ...(battery != null ? { lastKnownBattery: battery } : {}),
          ...(rssi != null ? { lastKnownRssi: rssi } : {}),
          connectivityStatus: battery != null && battery <= 20 ? "low_battery" : "online",
          updatedAt: now,
        },
        { merge: true }
      );
    }
  });

  logger.info("ingest_live_tick_succeeded", {
    sessionId: payload.sessionId,
    sequenceNumber: payload.sequenceNumber,
  });
  return { sessionId: payload.sessionId, sequenceNumber: payload.sequenceNumber };
});
