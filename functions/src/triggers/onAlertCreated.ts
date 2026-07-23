import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { coachUidsForTeam, writeNotifications, NotificationInput } from "../lib/notifications";

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

  const alertId = event.params.alertId;
  const playerId = alert["playerId"] as string;
  const teamId = alert["teamId"] as string | undefined;
  const severity = alert["severity"] as string;
  const type = alert["type"] as string;
  const message = alert["message"] as string;

  const recipients = new Map<string, NotificationInput>();
  const notification: Omit<NotificationInput, "uid"> = {
    type: "alert",
    title: severity === "critical" ? "Critical alert" : "Alert",
    body: message,
    relatedAlertId: alertId,
  };

  const bySeverity = severity === "critical" || severity === "warning";
  const byType = type === "device_disconnected";

  if (bySeverity) {
    recipients.set(playerId, { uid: playerId, ...notification });
  }

  // Read once, not once per matching rule — both rules resolve the same
  // team's coaches, and a team's coach list doesn't change between the
  // two checks within a single invocation.
  if ((bySeverity || byType) && teamId != null) {
    for (const uid of await coachUidsForTeam(teamId)) {
      recipients.set(uid, { uid, ...notification });
    }
  }

  await writeNotifications(Array.from(recipients.values()));
});
