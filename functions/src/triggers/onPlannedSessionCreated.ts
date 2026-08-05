import { onDocumentCreated } from "firebase-functions/v2/firestore";
import * as logger from "firebase-functions/logger";
import { db } from "../lib/admin";
import { writeNotifications, NotificationInput } from "../lib/notifications";
import { withEventIdempotency } from "../lib/idempotency";

/**
 * Phase 13 §5 — reacts to `plannedSessions/{plannedSessionId}` creation
 * (via `createPlannedSession`) and notifies every active player on the
 * team — the "Players Updated" step in the Coach → Callable → Backend
 * Validation → Firestore → Cloud Functions → Players Updated diagram.
 * Mirrors `onAlertCreated`/`onReportCreated`'s established
 * trigger-reacts-to-write pattern rather than having the callable itself
 * perform the fan-out.
 */
export const onPlannedSessionCreated = onDocumentCreated(
  "plannedSessions/{plannedSessionId}",
  async (event) => {
    const plannedSession = event.data?.data();
    if (!plannedSession) return;

    // Same double-notify risk on redelivery as `onAlertCreated.ts` — see
    // its identical comment.
    await withEventIdempotency(event.id, async () => {
      const plannedSessionId = event.params.plannedSessionId;
      const teamId = plannedSession["teamId"] as string;
      const title = plannedSession["title"] as string;

      const membersSnap = await db()
        .collection("teams")
        .doc(teamId)
        .collection("members")
        .where("status", "==", "active")
        .get();
      if (membersSnap.empty) return;

      const notifications: NotificationInput[] = membersSnap.docs.map((doc) => ({
        uid: doc.id,
        type: "session_scheduled",
        title: "New session scheduled",
        body: `"${title}" has been scheduled for your team.`,
        relatedPlannedSessionId: plannedSessionId,
      }));

      await writeNotifications(notifications);
      logger.info("on_planned_session_created_notified", {
        plannedSessionId,
        teamId,
        recipientCount: notifications.length,
      });
    });
  }
);
