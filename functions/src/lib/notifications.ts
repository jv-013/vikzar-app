import { Timestamp } from "firebase-admin/firestore";
import { db } from "./admin";

/**
 * BACKEND_SPECIFICATION.md §1.6 `type` enum. `session_scheduled` is
 * additive (Phase 13 §5) — a coach's `createPlannedSession` call notifies
 * the team's players.
 */
export type NotificationType =
  | "alert"
  | "report_ready"
  | "session_summary"
  | "team_invite"
  | "session_scheduled"
  | "system";

export interface NotificationInput {
  uid: string;
  type: NotificationType;
  title: string;
  body: string;
  relatedAlertId?: string;
  relatedReportId?: string;
  relatedSessionId?: string;
  relatedPlannedSessionId?: string;
}

/** Firestore's own hard limit on operations per batch. */
const MAX_BATCH_SIZE = 500;

/**
 * Writes one `users/{uid}/notifications/{notificationId}` document per
 * §1.6 — Cloud-Function-only creation. Deduplicates by `uid` before
 * calling this (callers build a `Map<uid, NotificationInput>`), since the
 * same person can qualify as a recipient for more than one reason (e.g. a
 * coach of a team that is also, separately, the alert's own player).
 *
 * Chunks into multiple batches of at most `MAX_BATCH_SIZE` — a single
 * `WriteBatch` throws past 500 operations, which a large team roster
 * (`onPlannedSessionCreated`'s fan-out, one notification per active
 * member) could realistically exceed. Chunks commit sequentially, not in
 * parallel, to stay well within per-second write-rate limits on any one
 * shard for teams with unusually large rosters.
 */
export async function writeNotifications(inputs: NotificationInput[]): Promise<void> {
  if (inputs.length === 0) return;
  const now = Timestamp.now();

  for (let start = 0; start < inputs.length; start += MAX_BATCH_SIZE) {
    const chunk = inputs.slice(start, start + MAX_BATCH_SIZE);
    const batch = db().batch();
    for (const input of chunk) {
      const ref = db().collection("users").doc(input.uid).collection("notifications").doc();
      batch.set(ref, {
        notificationId: ref.id,
        type: input.type,
        title: input.title,
        body: input.body,
        ...(input.relatedAlertId != null ? { relatedAlertId: input.relatedAlertId } : {}),
        ...(input.relatedReportId != null ? { relatedReportId: input.relatedReportId } : {}),
        ...(input.relatedSessionId != null ? { relatedSessionId: input.relatedSessionId } : {}),
        ...(input.relatedPlannedSessionId != null
          ? { relatedPlannedSessionId: input.relatedPlannedSessionId }
          : {}),
        read: false,
        createdAt: now,
      });
    }
    await batch.commit();
  }
}

/** Resolves a team's coach uids — empty array if the team doesn't exist. */
export async function coachUidsForTeam(teamId: string): Promise<string[]> {
  const snap = await db().collection("teams").doc(teamId).get();
  if (!snap.exists) return [];
  const coachIds = snap.data()?.["coachIds"];
  return Array.isArray(coachIds) ? (coachIds as string[]) : [];
}
