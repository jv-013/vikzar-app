import { onDocumentCreated } from "firebase-functions/v2/firestore";
import * as logger from "firebase-functions/logger";
import { coachUidsForTeam, NotificationInput, writeNotifications } from "../lib/notifications";
import { invalidateCachedReasoning } from "../lib/intelligence/razCache";
import { razAlertNotification } from "../lib/intelligence/razNotificationEngine";
import { withEventIdempotency } from "../lib/idempotency";

/**
 * BACKEND_SPECIFICATION.md §17/§18 — reacts to `alerts/{alertId}`
 * creation. Combines two documented recipient rules from §18's table
 * (deduplicated by uid — a coach is never notified twice for the same
 * alert even if they qualify under both rules):
 *
 * - `severity` is `"critical"` or `"warning"` → the player, and every
 *   coach of `teamId`.
 * - `type` is `"device_disconnected"` → coaches of `teamId` (whether or
 *   not severity also qualifies them above).
 *
 * Notification copy is phrased by `razNotificationEngine.ts` — RAZ's
 * calm, specific voice, not a generic "Alert" title — while the
 * recipient-selection rules above (who gets notified, decided by
 * BACKEND_SPECIFICATION.md, not by RAZ) are unchanged.
 *
 * **Known gap, not silently papered over**: §18 also documents a
 * `type: "low_battery"` rule notifying "the device's `ownerId`" — but
 * `alerts/{alertId}` (§1.10) has no `deviceId` field to resolve an owner
 * from, so that specific row cannot be implemented as written. A
 * low-battery alert still reaches the player/coaches via the severity
 * rule above whenever its severity is warning/critical; it will not
 * reach a *different* device owner than the alert's own `playerId`. This
 * is a genuine schema gap to raise with the project owner, not a bug in
 * this function — see DECISIONS.md for the recorded ADR.
 */
export const onAlertCreated = onDocumentCreated("alerts/{alertId}", async (event) => {
  const alert = event.data?.data();
  if (!alert) return;

  // `writeNotifications` allocates a fresh auto-ID doc per call — a
  // Firestore at-least-once redelivery of this same event would
  // otherwise create a duplicate notification. Guarded here.
  await withEventIdempotency(event.id, async () => {
    const alertId = event.params.alertId;
    const playerId = alert["playerId"] as string;
    const teamId = alert["teamId"] as string | undefined;
    const severity = alert["severity"] as string;
    const type = alert["type"] as string;
    const message = alert["message"] as string;

    const recipients = new Map<string, NotificationInput>();
    const notificationFor = (uid: string): NotificationInput =>
      razAlertNotification({ uid, alertId, severity, type, message });

    const bySeverity = severity === "critical" || severity === "warning";
    const byType = type === "device_disconnected";

    if (bySeverity) {
      recipients.set(playerId, notificationFor(playerId));
    }

    // Read once, not once per matching rule — both rules resolve the same
    // team's coaches, and a team's coach list doesn't change between the
    // two checks within a single invocation.
    if ((bySeverity || byType) && teamId != null) {
      for (const uid of await coachUidsForTeam(teamId)) {
        recipients.set(uid, notificationFor(uid));
      }
    }

    await writeNotifications(Array.from(recipients.values()));
    // Garbage-collect every recipient's cached RAZ reasoning; their
    // context just genuinely changed. See `onReportCreated.ts`'s
    // identical comment for why this is cleanup, not a correctness
    // requirement.
    await Promise.all(
      Array.from(recipients.keys()).map((uid) =>
        invalidateCachedReasoning(uid).catch(() => undefined)
      )
    );
    logger.info("on_alert_created_notified", { alertId, recipientCount: recipients.size });
  });
});
