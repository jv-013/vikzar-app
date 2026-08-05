import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { Timestamp } from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";
import { db } from "../lib/admin";

/**
 * BACKEND_SPECIFICATION.md §17/§1.4 — reacts to every write of
 * `sessions/{sessionId}/live/current` (roughly once per second while a
 * session is live) and upserts the corresponding denormalized
 * `teams/{teamId}/liveMonitoring/{playerId}` document, so Live Team
 * Monitoring can listen to one shallow collection instead of opening one
 * listener per live session. A no-op for individual (non-team) sessions,
 * since `teamId` is absent — there is no coach-facing surface to fan out
 * to.
 */
export const fanOutLiveMonitoring = onDocumentWritten(
  "sessions/{sessionId}/live/current",
  async (event) => {
    const after = event.data?.after;
    if (!after?.exists) return; // deleted, nothing to fan out

    const tick = after.data()!;
    const teamId = tick["teamId"] as string | undefined;
    if (teamId == null) return;

    const playerId = tick["playerId"] as string;
    const sessionId = event.params.sessionId;

    const userSnap = await db().collection("users").doc(playerId).get();
    const displayName = (userSnap.data()?.["displayName"] as string | undefined) ?? "";

    const metrics = tick["metrics"] as Record<string, unknown>;
    await db()
      .collection("teams")
      .doc(teamId)
      .collection("liveMonitoring")
      .doc(playerId)
      .set({
        playerId,
        sessionId,
        displayName,
        connectionStatus: tick["connectionStatus"],
        lastTickAt: tick["tickTimestamp"],
        currentRiskScore: metrics["riskScore"],
        currentRiskLevel: metrics["riskLevel"],
        currentLoad: metrics["currentLoad"],
        cumulativeImpacts: metrics["cumulativeImpacts"],
        ...(tick["deviceBattery"] != null ? { deviceBattery: tick["deviceBattery"] } : {}),
        updatedAt: Timestamp.now(),
      });
    logger.info("fan_out_live_monitoring_succeeded", { teamId, playerId, sessionId });
  }
);
