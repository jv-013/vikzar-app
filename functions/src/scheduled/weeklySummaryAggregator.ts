import { onSchedule } from "firebase-functions/v2/scheduler";
import { Timestamp } from "firebase-admin/firestore";
import { db } from "../lib/admin";

const TERMINAL_STATUSES = ["completed", "completed_with_gaps", "aborted"];

/**
 * BACKEND_SPECIFICATION.md §17 — "Aggregates existing
 * `sessions.summaryMetrics` for the prior period into `reports` documents
 * of type `weekly_summary`. Arithmetic aggregation of already-computed
 * values only." One report per player who completed at least one session
 * in the prior 7 days — `reports.playerId` is a required field (§1.11)
 * with no documented per-type exception, so a weekly summary is scoped
 * per player (with `teamId` denormalized, driving §18's "coaches of
 * teamId" notification), not one combined per-team document.
 */
export const weeklySummaryAggregator = onSchedule(
  { schedule: "every monday 06:00", timeZone: "UTC" },
  async () => {
    const periodEnd = Timestamp.now();
    const periodStart = Timestamp.fromMillis(periodEnd.toMillis() - 7 * 24 * 60 * 60 * 1000);

    const sessions = await db()
      .collection("sessions")
      .where("status", "in", TERMINAL_STATUSES)
      .where("endedAt", ">=", periodStart)
      .where("endedAt", "<", periodEnd)
      .get();
    if (sessions.empty) return;

    const byPlayer = new Map<string, { teamId?: string; orgId?: string; sessions: FirebaseFirestore.DocumentData[] }>();
    for (const doc of sessions.docs) {
      const session = doc.data();
      const playerId = session["playerId"] as string;
      const entry = byPlayer.get(playerId) ?? {
        teamId: session["teamId"] as string | undefined,
        orgId: session["orgId"] as string | undefined,
        sessions: [],
      };
      entry.sessions.push(session);
      byPlayer.set(playerId, entry);
    }

    const batch = db().batch();
    for (const [playerId, entry] of byPlayer) {
      const summaryMetricsList = entry.sessions
        .map((s) => s["summaryMetrics"] as Record<string, unknown> | undefined)
        .filter((m): m is Record<string, unknown> => m != null);
      const totalImpacts = sum(summaryMetricsList.map((m) => m["totalImpacts"] as number));
      const averageRiskScore = average(
        summaryMetricsList.map((m) => m["overallRiskScore"] as number)
      );
      const highestRiskLevel = worstRiskLevel(
        summaryMetricsList.map((m) => m["riskLevel"] as string)
      );

      const ref = db().collection("reports").doc();
      batch.set(ref, {
        reportId: ref.id,
        type: "weekly_summary",
        playerId,
        ...(entry.teamId != null ? { teamId: entry.teamId } : {}),
        ...(entry.orgId != null ? { orgId: entry.orgId } : {}),
        periodStart,
        periodEnd,
        generatedAt: Timestamp.now(),
        generatedBy: "cloud_function_aggregation",
        summary: {
          sessionCount: entry.sessions.length,
          totalImpacts,
          averageRiskScore,
          riskLevel: highestRiskLevel,
        },
        status: "final",
      });
    }
    await batch.commit();
  }
);

function sum(values: number[]): number {
  return values.reduce((total, value) => total + value, 0);
}

function average(values: number[]): number | null {
  return values.length > 0 ? sum(values) / values.length : null;
}

const RISK_ORDER = ["low", "moderate", "high", "critical"];

function worstRiskLevel(levels: string[]): string | null {
  let worstIndex = -1;
  for (const level of levels) {
    const index = RISK_ORDER.indexOf(level);
    if (index > worstIndex) worstIndex = index;
  }
  return worstIndex >= 0 ? RISK_ORDER[worstIndex]! : null;
}
