import { onDocumentUpdated } from "firebase-functions/v2/firestore";
import { Timestamp, FieldValue } from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";
import { db } from "../lib/admin";
import { coachUidsForTeam, writeNotifications, NotificationInput } from "../lib/notifications";
import { withEventIdempotency } from "../lib/idempotency";

const TERMINAL_STATUSES = new Set(["completed", "completed_with_gaps", "aborted"]);

/**
 * BACKEND_SPECIFICATION.md §17 — reacts to `sessions/{sessionId}`'s status
 * transition into a terminal state. Three responsibilities, per §17's own
 * row: (1) update `users/{uid}.careerStats` — pure arithmetic aggregation
 * of already-computed session totals, never new inference, per §0's
 * constraint; (2) remove the now-stale `teams/{teamId}/liveMonitoring/{playerId}`
 * entry; (3) dispatch the session-summary notification (§18).
 */
export const onSessionCompleted = onDocumentUpdated("sessions/{sessionId}", async (event) => {
  const before = event.data?.before.data();
  const after = event.data?.after.data();
  if (!before || !after) return;

  const wasTerminal = TERMINAL_STATUSES.has(before["status"] as string);
  const isTerminal = TERMINAL_STATUSES.has(after["status"] as string);
  if (wasTerminal || !isTerminal) return; // only fire on the transition itself

  // `careerStats`'s FieldValue.increment() below would double-count on a
  // Firestore at-least-once redelivery of this same event — guarded here.
  await withEventIdempotency(event.id, async () => {
    const sessionId = event.params.sessionId;
    const playerId = after["playerId"] as string;
    const teamId = after["teamId"] as string | undefined;
    const summaryMetrics = after["summaryMetrics"] as Record<string, unknown> | undefined;

    const tasks: Promise<unknown>[] = [updateCareerStats(playerId, after)];

    if (teamId != null) {
      tasks.push(
        db().collection("teams").doc(teamId).collection("liveMonitoring").doc(playerId).delete()
      );
    }

    tasks.push(dispatchSessionSummaryNotification({ sessionId, playerId, teamId, summaryMetrics }));

    await Promise.all(tasks);
    logger.info("on_session_completed_processed", { sessionId, playerId });
  });
});

async function updateCareerStats(playerId: string, session: Record<string, unknown>): Promise<void> {
  const summaryMetrics = session["summaryMetrics"] as Record<string, unknown> | undefined;
  const totalImpacts = (summaryMetrics?.["totalImpacts"] as number | undefined) ?? 0;
  const endedAt = session["endedAt"] as Timestamp | undefined;

  const thirtyDaysAgo = Timestamp.fromMillis(Date.now() - 30 * 24 * 60 * 60 * 1000);
  // Defensive cap, not a real-world limit: this query re-scans the
  // player's own last-30-days terminal sessions on every single
  // completion, so its cost is O(k) on a player's k-th completion in
  // the window — bounded in practice by realistic training frequency
  // (nobody trains 60+ times in 30 days), but a runaway/buggy ingestion
  // client generating many sessions could otherwise scale this
  // unboundedly. 60 comfortably covers 2x/day for 30 days.
  const recentSessions = await db()
    .collection("sessions")
    .where("playerId", "==", playerId)
    .where("status", "in", Array.from(TERMINAL_STATUSES))
    .where("endedAt", ">=", thirtyDaysAgo)
    .limit(60)
    .get();
  const riskScores = recentSessions.docs
    .map((doc) => (doc.data()["summaryMetrics"] as Record<string, unknown> | undefined)?.["overallRiskScore"])
    .filter((value): value is number => typeof value === "number");
  const averageRiskScore30d =
    riskScores.length > 0 ? riskScores.reduce((sum, v) => sum + v, 0) / riskScores.length : null;

  await db()
    .collection("users")
    .doc(playerId)
    .update({
      "careerStats.totalSessions": FieldValue.increment(1),
      "careerStats.totalImpacts": FieldValue.increment(totalImpacts),
      ...(endedAt != null ? { "careerStats.lastSessionAt": endedAt } : {}),
      "careerStats.averageRiskScore30d": averageRiskScore30d,
    });
}

async function dispatchSessionSummaryNotification(args: {
  sessionId: string;
  playerId: string;
  teamId?: string;
  summaryMetrics?: Record<string, unknown>;
}): Promise<void> {
  const recipients = new Map<string, NotificationInput>();
  recipients.set(args.playerId, {
    uid: args.playerId,
    type: "session_summary",
    title: "Session complete",
    body: "Your session summary is ready.",
    relatedSessionId: args.sessionId,
  });

  const riskLevel = args.summaryMetrics?.["riskLevel"] as string | undefined;
  if (args.teamId != null && (riskLevel === "high" || riskLevel === "critical")) {
    const coachUids = await coachUidsForTeam(args.teamId);
    for (const uid of coachUids) {
      recipients.set(uid, {
        uid,
        type: "session_summary",
        title: "Session complete — elevated risk",
        body: "A player's session ended with an elevated risk level.",
        relatedSessionId: args.sessionId,
      });
    }
  }

  await writeNotifications(Array.from(recipients.values()));
}
