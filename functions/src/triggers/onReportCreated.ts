import { onDocumentCreated } from "firebase-functions/v2/firestore";
import * as logger from "firebase-functions/logger";
import { coachUidsForTeam, NotificationInput, writeNotifications } from "../lib/notifications";
import { invalidateCachedReasoning } from "../lib/intelligence/razCache";
import { razReportNotification } from "../lib/intelligence/razNotificationEngine";
import { withEventIdempotency } from "../lib/idempotency";

/**
 * BACKEND_SPECIFICATION.md §17/§18 — reacts to `reports/{reportId}`
 * creation. Per §18's table: `session_report`/`player_profile_report` →
 * the player and coaches of `teamId`; `weekly_summary` → coaches of
 * `teamId` only (a rollup report has no single owning player).
 *
 * Also garbage-collects every recipient's cached RAZ reasoning: their
 * context just genuinely changed, so the old cache entry (keyed by the
 * *previous* context hash) is now dead weight, never to be looked up
 * again. Not required for correctness — the next `razAsk`/
 * `razDailyBrief` call already computes a fresh hash and misses the
 * stale entry on its own — purely cleanup.
 */
export const onReportCreated = onDocumentCreated("reports/{reportId}", async (event) => {
  const report = event.data?.data();
  if (!report) return;

  // Same double-notify risk on redelivery as `onAlertCreated.ts` — see
  // its identical comment.
  await withEventIdempotency(event.id, async () => {
    const reportId = event.params.reportId;
    const type = report["type"] as string;
    const playerId = report["playerId"] as string | undefined;
    const teamId = report["teamId"] as string | undefined;

    const recipients = new Map<string, NotificationInput>();
    const notificationFor = (uid: string): NotificationInput =>
      razReportNotification({ uid, reportId, reportType: type });

    if (type !== "weekly_summary" && playerId != null) {
      recipients.set(playerId, notificationFor(playerId));
    }
    if (teamId != null) {
      for (const uid of await coachUidsForTeam(teamId)) {
        recipients.set(uid, notificationFor(uid));
      }
    }

    await writeNotifications(Array.from(recipients.values()));
    await Promise.all(
      Array.from(recipients.keys()).map((uid) =>
        invalidateCachedReasoning(uid).catch(() => undefined)
      )
    );
    logger.info("on_report_created_notified", { reportId, recipientCount: recipients.size });
  });
});
