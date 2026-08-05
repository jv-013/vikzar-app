import { db } from "../admin";
import { RetrievedRecord, SquadMemberSummary } from "./types";

/**
 * RazKnowledge — the retrieval layer. Every function here returns typed
 * {@link RetrievedRecord}s (or similarly-typed structured summaries),
 * never a raw `DocumentSnapshot`. Every function is a plain `(params) =>
 * Promise<T>` with no Firestore-specific type in its signature — the
 * seam that lets a future vector/semantic implementation of, say,
 * `retrieveRecentAlertsForPlayer` ("alerts similar to this one") replace
 * this Firestore-backed one without `razContext.ts` or anything above
 * it changing a single call site.
 */

function toDate(value: unknown): Date {
  if (value && typeof (value as { toDate?: () => Date }).toDate === "function") {
    return (value as { toDate: () => Date }).toDate();
  }
  return new Date();
}

const SEVERITY_LABEL: Record<string, string> = {
  critical: "Critical",
  warning: "Warning",
  info: "Info",
};

export async function retrieveRecentAlertsForPlayer(
  playerId: string,
  limit: number
): Promise<RetrievedRecord[]> {
  const snap = await db()
    .collection("alerts")
    .where("playerId", "==", playerId)
    .orderBy("triggeredAt", "desc")
    .limit(limit)
    .get();
  return snap.docs.map((doc) => {
    const data = doc.data();
    const severity = String(data["severity"] ?? "info");
    return {
      id: doc.id,
      kind: "alert" as const,
      summary: `${SEVERITY_LABEL[severity] ?? severity} alert: ${String(data["message"] ?? "")}`,
      occurredAt: toDate(data["triggeredAt"]),
    };
  });
}

export async function retrieveRecentAlertsForTeam(
  teamId: string,
  limit: number
): Promise<RetrievedRecord[]> {
  const snap = await db()
    .collection("alerts")
    .where("teamId", "==", teamId)
    .orderBy("triggeredAt", "desc")
    .limit(limit)
    .get();
  return snap.docs.map((doc) => {
    const data = doc.data();
    const severity = String(data["severity"] ?? "info");
    return {
      id: doc.id,
      kind: "alert" as const,
      summary: `${SEVERITY_LABEL[severity] ?? severity} alert: ${String(data["message"] ?? "")}`,
      occurredAt: toDate(data["triggeredAt"]),
      relatedPlayerId: data["playerId"] as string | undefined,
    };
  });
}

/** Alerts on this team not yet acknowledged by a coach, most recent first. */
export async function retrieveUnacknowledgedAlertsForTeam(
  teamId: string,
  limit: number
): Promise<RetrievedRecord[]> {
  const snap = await db()
    .collection("alerts")
    .where("teamId", "==", teamId)
    .where("acknowledged", "==", false)
    .orderBy("triggeredAt", "desc")
    .limit(limit)
    .get();
  return snap.docs.map((doc) => {
    const data = doc.data();
    return {
      id: doc.id,
      kind: "alert" as const,
      summary: String(data["message"] ?? ""),
      occurredAt: toDate(data["triggeredAt"]),
      relatedPlayerId: data["playerId"] as string | undefined,
    };
  });
}

export async function retrieveRecentReportsForPlayer(
  playerId: string,
  limit: number
): Promise<RetrievedRecord[]> {
  const snap = await db()
    .collection("reports")
    .where("playerId", "==", playerId)
    .orderBy("generatedAt", "desc")
    .limit(limit)
    .get();
  return snap.docs.map((doc) => {
    const data = doc.data();
    const summary = data["summary"] as Record<string, unknown> | undefined;
    // `summary` is intentionally unstructured at the schema level
    // (§21.7) — only ever surface recognized primitive fields from it,
    // never the raw object, per "never send raw Firestore documents
    // directly into prompts."
    const headline =
      typeof summary?.["headline"] === "string" ? (summary["headline"] as string) : null;
    return {
      id: doc.id,
      kind: "report" as const,
      summary: headline ?? "A session report was generated.",
      occurredAt: toDate(data["generatedAt"]),
    };
  });
}

export async function retrieveRecentSessionsForPlayer(
  playerId: string,
  limit: number
): Promise<RetrievedRecord[]> {
  const snap = await db()
    .collection("sessions")
    .where("playerId", "==", playerId)
    .orderBy("endedAt", "desc")
    .limit(limit)
    .get();
  return snap.docs.map((doc) => {
    const data = doc.data();
    const metrics = data["summaryMetrics"] as Record<string, unknown> | undefined;
    const riskLevel = metrics?.["riskLevel"] as string | undefined;
    return {
      id: doc.id,
      kind: "session" as const,
      summary: riskLevel
        ? `Session completed — overall risk ${riskLevel}.`
        : "Session completed.",
      occurredAt: toDate(data["endedAt"]),
    };
  });
}

export async function retrieveRecentNotifications(
  uid: string,
  limit: number
): Promise<RetrievedRecord[]> {
  const snap = await db()
    .collection("users")
    .doc(uid)
    .collection("notifications")
    .orderBy("createdAt", "desc")
    .limit(limit)
    .get();
  return snap.docs.map((doc) => {
    const data = doc.data();
    return {
      id: doc.id,
      kind: "notification" as const,
      summary: String(data["title"] ?? ""),
      occurredAt: toDate(data["createdAt"]),
    };
  });
}

/** Capped, not a true count — good enough to say "a few" vs "none" without an extra aggregation query. */
export async function countUnreadNotifications(uid: string, cap = 20): Promise<number> {
  const snap = await db()
    .collection("users")
    .doc(uid)
    .collection("notifications")
    .where("read", "==", false)
    .limit(cap)
    .get();
  return snap.size;
}

export async function retrieveNextSessionForTeam(
  teamId: string
): Promise<{ title: string; scheduledAt: Date; location?: string } | null> {
  const now = new Date();
  const snap = await db()
    .collection("plannedSessions")
    .where("teamId", "==", teamId)
    .where("scheduledAt", ">=", now)
    .orderBy("scheduledAt", "asc")
    .limit(5)
    .get();
  const next = snap.docs
    .map((doc) => doc.data())
    .find((data) => data["status"] !== "cancelled");
  if (!next) return null;
  return {
    title: String(next["title"] ?? ""),
    scheduledAt: toDate(next["scheduledAt"]),
    location: typeof next["location"] === "string" ? (next["location"] as string) : undefined,
  };
}

export async function retrieveTodaysSessionsForTeam(
  teamId: string
): Promise<{ title: string; scheduledAt: Date }[]> {
  const now = new Date();
  const startOfDay = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const endOfDay = new Date(startOfDay.getTime() + 24 * 60 * 60 * 1000);
  const snap = await db()
    .collection("plannedSessions")
    .where("teamId", "==", teamId)
    .where("scheduledAt", ">=", startOfDay)
    .where("scheduledAt", "<", endOfDay)
    .orderBy("scheduledAt", "asc")
    .get();
  return snap.docs
    .map((doc) => doc.data())
    .filter((data) => data["status"] !== "cancelled")
    .map((data) => ({ title: String(data["title"] ?? ""), scheduledAt: toDate(data["scheduledAt"]) }));
}

// A squad large enough that a single roster read stays bounded regardless
// of how large a team's `members` subcollection grows — mirrors
// `razContext.ts`'s own `MAX_ROSTER_LOOKUPS`, applied here at the query
// itself rather than only on the post-read slice, so an unusually large
// or duplicate-laden roster can't make this call's Firestore read
// unbounded before that cap ever gets a chance to apply.
const MAX_ROSTER_READ = 50;

export async function retrieveTeamRoster(teamId: string): Promise<SquadMemberSummary[]> {
  const snap = await db()
    .collection("teams")
    .doc(teamId)
    .collection("members")
    .limit(MAX_ROSTER_READ)
    .get();
  return snap.docs
    .filter((doc) => doc.data()["role"] === "player")
    .map((doc) => {
      const data = doc.data();
      return {
        uid: doc.id,
        displayName: String(data["displayName"] ?? ""),
        trainingStatus: null as string | null, // filled in by razContext.ts (requires a users/{uid} read per member)
      };
    });
}
