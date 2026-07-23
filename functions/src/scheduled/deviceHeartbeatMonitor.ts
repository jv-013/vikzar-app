import { onSchedule } from "firebase-functions/v2/scheduler";
import { Timestamp } from "firebase-admin/firestore";
import { db } from "../lib/admin";

/** How long a device may go silent during a live session before it's considered disconnected. */
const HEARTBEAT_TIMEOUT_MS = 60_000;

/**
 * BACKEND_SPECIFICATION.md §17 — "Checks `devices.lastSeenAt` for devices
 * referenced by any currently-`live` session; raises a
 * `device_disconnected` alert via the same path as `submitAlert` if a
 * device has gone silent past a defined timeout. Timeout-checking only,
 * not signal analysis." Runs as this trusted Cloud Function itself
 * (`source: "cloud_function_device_health"`, per §1.10) rather than going
 * through the `submitAlert` Callable, since there is no laptop-side
 * ingestion principal call for this — the check originates in Firebase.
 */
export const deviceHeartbeatMonitor = onSchedule("every 30 seconds", async () => {
  const liveSessions = await db().collection("sessions").where("status", "==", "live").get();
  if (liveSessions.empty) return;

  const now = Date.now();
  const alertBatch = db().batch();
  let alertsRaised = 0;

  for (const sessionDoc of liveSessions.docs) {
    const session = sessionDoc.data();
    const deviceIds = (session["deviceIds"] as string[] | undefined) ?? [];
    if (deviceIds.length === 0) continue;

    for (const deviceId of deviceIds) {
      const deviceRef = db().collection("devices").doc(deviceId);
      const deviceSnap = await deviceRef.get();
      if (!deviceSnap.exists) continue;
      const lastSeenAt = deviceSnap.data()?.["lastSeenAt"] as Timestamp | undefined;
      if (lastSeenAt == null) continue; // never reported yet — not this monitor's concern
      if (now - lastSeenAt.toMillis() <= HEARTBEAT_TIMEOUT_MS) continue;
      if (deviceSnap.data()?.["connectivityStatus"] === "disconnected") continue; // already flagged

      alertBatch.set(
        deviceRef,
        { connectivityStatus: "disconnected", updatedAt: Timestamp.now() },
        { merge: true }
      );

      const alertRef = db().collection("alerts").doc();
      alertBatch.set(alertRef, {
        alertId: alertRef.id,
        sessionId: sessionDoc.id,
        playerId: session["playerId"],
        ...(session["teamId"] != null ? { teamId: session["teamId"] } : {}),
        ...(session["orgId"] != null ? { orgId: session["orgId"] } : {}),
        severity: "warning",
        type: "device_disconnected",
        message: `Device ${deviceId} has not reported in over ${Math.round(
          HEARTBEAT_TIMEOUT_MS / 1000
        )} seconds.`,
        metricsSnapshot: { deviceId, lastSeenAt },
        source: "cloud_function_device_health",
        triggeredAt: Timestamp.now(),
        acknowledged: false,
        createdAt: Timestamp.now(),
      });
      alertsRaised += 1;
    }
  }

  if (alertsRaised > 0) await alertBatch.commit();
});
