import { Timestamp } from "firebase-admin/firestore";
import { db } from "./admin";

/** How long a processed-event marker is kept around before it's stale. */
const MARKER_TTL_MS = 7 * 24 * 60 * 60 * 1000;

/**
 * Cloud Firestore triggers are at-least-once, not exactly-once, delivery.
 * Most of this codebase's triggers are naturally idempotent by
 * construction (e.g. `fanOutLiveMonitoring`'s `.set()` on a fixed-id
 * doc), but a few have side effects that genuinely double up on
 * redelivery — `onSessionCompleted`'s `FieldValue.increment()` on
 * `careerStats`, and the notification-creating triggers' fresh-auto-ID
 * `writeNotifications()` call. This guards exactly those.
 *
 * Transactionally checks-and-sets `_processedEvents/{eventId}` (Cloud-
 * Function-only per `firestore.rules`, same pattern as `_rateLimits`)
 * *before* running `fn` — the standard idempotency-key shape. Honest
 * tradeoff, stated rather than hidden: if `fn` itself throws partway
 * through, the event is already marked processed and won't be retried
 * on a later redelivery of the *same* event. Acceptable here because
 * none of the triggers this wraps are configured with `retry: true` —
 * Firestore's own at-least-once redelivery (not a function-thrown-error
 * retry) is the only redelivery case this exists to guard against.
 *
 * No cleanup job exists yet for `_processedEvents` — each marker carries
 * `expiresAt` for a future scheduled-cleanup pass, deliberately not
 * built this phase. Building a new recurring Cloud Function for a
 * collection that isn't a real storage problem at current event volume
 * would be exactly the kind of unrequested infrastructure this
 * codebase's "only implement what's genuinely needed today" convention
 * argues against (see e.g. RazNotificationEngine's undone proactive-
 * notification extension points).
 */
export async function withEventIdempotency(
  eventId: string,
  fn: () => Promise<void>
): Promise<void> {
  const ref = db().collection("_processedEvents").doc(eventId);

  const alreadyProcessed = await db().runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (snap.exists) return true;
    const now = Timestamp.now();
    tx.set(ref, {
      processedAt: now,
      expiresAt: Timestamp.fromMillis(now.toMillis() + MARKER_TTL_MS),
    });
    return false;
  });

  if (alreadyProcessed) return;
  await fn();
}
