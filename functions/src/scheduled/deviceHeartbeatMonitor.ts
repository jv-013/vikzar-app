import { onSchedule } from "firebase-functions/v2/scheduler";
import { Timestamp } from "firebase-admin/firestore";
import { db } from "../lib/admin";

/** How long a device may go silent during a live session before it's considered disconnected. */
const HEARTBEAT_TIMEOUT_MS = 60_000;
/** Firestore's own hard limit on operations per batch — 2 writes/flagged device. */
const MAX_BATCH_OPS = 500;

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

  // Confirmed by audit: with sessions × devices read sequentially (one
  // `await` per device, one at a time), 50 concurrent live sessions ×
  // 4 devices = 200 fully sequential round trips — several seconds of
  // wall-clock time against a function that fires every 30 seconds,
  // and pure latency this function's own logic doesn't need to pay,
  // since every device read is independent. Reading `Promise.all`-style
  // instead collapses that to one round-trip's worth of latency
  // regardless of device count.
  const checks = liveSessions.docs.flatMap((sessionDoc) => {
    const session = sessionDoc.data();
    const deviceIds = (session["deviceIds"] as string[] | undefined) ?? [];
    return deviceIds.map((deviceId) => ({ sessionDoc, session, deviceId }));
  });

  const deviceSnaps = await Promise.all(
    checks.map(({ deviceId }) => db().collection("devices").doc(deviceId).get())
  );

  type PendingWrite = { ref: FirebaseFirestore.DocumentReference; data: Record<string, unknown>; merge?: boolean };
  const writes: PendingWrite[] = [];

  checks.forEach(({ sessionDoc, session, deviceId }, index) => {
    const deviceSnap = deviceSnaps[index]!;
    if (!deviceSnap.exists) return;
    const lastSeenAt = deviceSnap.data()?.["lastSeenAt"] as Timestamp | undefined;
    if (lastSeenAt == null) return; // never reported yet — not this monitor's concern
    if (now - lastSeenAt.toMillis() <= HEARTBEAT_TIMEOUT_MS) return;
    if (deviceSnap.data()?.["connectivityStatus"] === "disconnected") return; // already flagged

    writes.push({
      ref: db().collection("devices").doc(deviceId),
      data: { connectivityStatus: "disconnected", updatedAt: Timestamp.now() },
      merge: true,
    });

    const alertRef = db().collection("alerts").doc();
    writes.push({
      ref: alertRef,
      data: {
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
      },
    });
  });

  // Chunked, same reasoning as lib/notifications.ts's writeNotifications —
  // a single WriteBatch throws past 500 operations, which a mass-disconnect
  // event across enough concurrent live sessions could reach (2 writes per
  // flagged device).
  for (let start = 0; start < writes.length; start += MAX_BATCH_OPS) {
    const batch = db().batch();
    for (const write of writes.slice(start, start + MAX_BATCH_OPS)) {
      batch.set(write.ref, write.data, write.merge ? { merge: true } : {});
    }
    await batch.commit();
  }
});
