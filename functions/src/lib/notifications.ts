import { Timestamp } from "firebase-admin/firestore";
import { db } from "./admin";
import { chunkedBatchWrite } from "./firestoreBatch";

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
  /**
   * RAZ's own semantic flavor of *why* this notification is what it is
   * (`recovery`/`coach`/`session`/`hardware`/`movement` — see
   * `RazNotificationCategory` in `razNotificationEngine.ts`), distinct
   * from `type` above (the structural/routing category every
   * notification has). Only alert/report-sourced notifications carry
   * one; `session_scheduled`/`session_summary` notifications simply omit
   * it.
   */
  razCategory?: string;
}

/**
 * Writes one `users/{uid}/notifications/{notificationId}` document per
 * §1.6 — Cloud-Function-only creation. Deduplicates by `uid` before
 * calling this (callers build a `Map<uid, NotificationInput>`), since the
 * same person can qualify as a recipient for more than one reason (e.g. a
 * coach of a team that is also, separately, the alert's own player).
 *
 * Chunked via `chunkedBatchWrite` — a single `WriteBatch` throws past 500
 * operations, which a large team roster (`onPlannedSessionCreated`'s
 * fan-out, one notification per active member) could realistically
 * exceed.
 */
export async function writeNotifications(inputs: NotificationInput[]): Promise<void> {
  if (inputs.length === 0) return;
  const now = Timestamp.now();

  await chunkedBatchWrite(inputs, (batch, input) => {
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
      ...(input.razCategory != null ? { razCategory: input.razCategory } : {}),
      read: false,
      createdAt: now,
    });
  });
}

/** Resolves a team's coach uids — empty array if the team doesn't exist. */
export async function coachUidsForTeam(teamId: string): Promise<string[]> {
  const snap = await db().collection("teams").doc(teamId).get();
  if (!snap.exists) return [];
  const coachIds = snap.data()?.["coachIds"];
  return Array.isArray(coachIds) ? (coachIds as string[]) : [];
}
