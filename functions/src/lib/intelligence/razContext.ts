import { db } from "../admin";
import { deriveAwareness } from "./razHardwareContext";
import { getMemories } from "./razMemory";
import {
  countUnreadNotifications,
  retrieveNextSessionForTeam,
  retrieveRecentAlertsForPlayer,
  retrieveRecentAlertsForTeam,
  retrieveRecentNotifications,
  retrieveRecentReportsForPlayer,
  retrieveRecentSessionsForPlayer,
  retrieveTeamRoster,
  retrieveTodaysSessionsForTeam,
  retrieveUnacknowledgedAlertsForTeam,
} from "./razKnowledge";
import { CoachContext, PlayerContext, SquadMemberSummary } from "./types";

/** A squad large enough that RAZ stays useful without reading every member's profile one-by-one forever. */
const MAX_ROSTER_LOOKUPS = 50;

/**
 * RazContext — gathers everything relevant for one RAZ call *before* any
 * reasoning happens: profile, schedule, retrieval-layer records,
 * persistent memory, and hardware awareness, calling into RazKnowledge
 * for each retrieval category rather than reading raw Firestore
 * documents itself. This is the one function `razAsk`/`razDailyBrief`
 * call to know "what's true right now" — neither callable reads
 * Firestore directly.
 */
export async function buildPlayerContext(uid: string): Promise<PlayerContext> {
  const userSnap = await db().collection("users").doc(uid).get();
  const user = userSnap.data() ?? {};
  const playerProfile = (user["playerProfile"] as Record<string, unknown> | undefined) ?? {};
  const teamId =
    ((user["workspaces"] as Record<string, unknown> | undefined)?.["player"] as
      | Record<string, unknown>
      | undefined)?.["teamId"] as string | undefined;

  const [
    nextSession,
    recentAlerts,
    recentReports,
    recentSessions,
    recentNotifications,
    unreadCount,
    memories,
  ] = await Promise.all([
    teamId ? retrieveNextSessionForTeam(teamId) : Promise.resolve(null),
    retrieveRecentAlertsForPlayer(uid, 5),
    retrieveRecentReportsForPlayer(uid, 5),
    retrieveRecentSessionsForPlayer(uid, 5),
    retrieveRecentNotifications(uid, 5),
    countUnreadNotifications(uid),
    getMemories(uid),
  ]);

  // No device-pairing pipeline exists yet — see PlayerContext's own doc
  // comment in types.ts. Honestly false, not a placeholder.
  const podConnected = false;

  return {
    uid,
    displayName: String(user["displayName"] ?? ""),
    trainingStatus: (playerProfile["trainingStatus"] as string | undefined) ?? null,
    position: (playerProfile["position"] as string | undefined) ?? null,
    hasCoach: teamId != null,
    podConnected,
    nextSession,
    recentAlerts,
    recentReports,
    recentSessions,
    recentNotifications,
    unreadNotificationCount: unreadCount,
    memories,
    awareness: deriveAwareness({ audience: "player", podConnected }),
  };
}

export async function buildCoachContext(uid: string): Promise<CoachContext> {
  const userSnap = await db().collection("users").doc(uid).get();
  const user = userSnap.data() ?? {};
  const teamIds =
    (((user["workspaces"] as Record<string, unknown> | undefined)?.["coach"] as
      | Record<string, unknown>
      | undefined)?.["teamIds"] as string[] | undefined) ?? [];
  const teamId = teamIds[0] ?? null;
  const displayName = String(user["displayName"] ?? "");

  if (teamId == null) {
    return {
      uid,
      displayName,
      teamId: null,
      teamName: null,
      squad: [],
      squadByStatus: {},
      todaysSessions: [],
      recentAlerts: [],
      playersWithUnacknowledgedAlerts: [],
      unreadNotificationCount: await countUnreadNotifications(uid),
      memories: await getMemories(uid),
      awareness: deriveAwareness({ audience: "coach", podConnected: false }),
    };
  }

  const [teamSnap, roster, todaysSessions, recentAlerts, unacknowledged, unreadCount, memories] =
    await Promise.all([
      db().collection("teams").doc(teamId).get(),
      retrieveTeamRoster(teamId),
      retrieveTodaysSessionsForTeam(teamId),
      retrieveRecentAlertsForTeam(teamId, 10),
      retrieveUnacknowledgedAlertsForTeam(teamId, 20),
      countUnreadNotifications(uid),
      getMemories(uid),
    ]);

  const squad = await fillTrainingStatuses(roster);
  const squadByStatus: Record<string, number> = {};
  for (const member of squad) {
    const key = member.trainingStatus ?? "not_set";
    squadByStatus[key] = (squadByStatus[key] ?? 0) + 1;
  }

  const byPlayer = new Map(squad.map((m) => [m.uid, m.displayName]));
  const playersWithUnacknowledgedAlerts = Array.from(
    new Set(unacknowledged.map((a) => a.relatedPlayerId).filter((id): id is string => id != null))
  ).map((playerId) => ({ uid: playerId, displayName: byPlayer.get(playerId) ?? "Unknown player" }));

  return {
    uid,
    displayName,
    teamId,
    teamName: (teamSnap.data()?.["name"] as string | undefined) ?? null,
    squad,
    squadByStatus,
    todaysSessions,
    recentAlerts,
    playersWithUnacknowledgedAlerts,
    unreadNotificationCount: unreadCount,
    memories,
    // A coach has no single "Pod" of their own — team-level hardware
    // awareness (e.g. "how many of the squad's Pods are connected") is a
    // real future extension, not something to fake a boolean for today.
    awareness: deriveAwareness({ audience: "coach", podConnected: false }),
  };
}

/**
 * `retrieveTeamRoster` can't fill in each member's real `trainingStatus`
 * itself without importing user-profile concerns into RazKnowledge's
 * team/roster boundary — done here instead, the same per-member
 * `users/{uid}` join the Flutter `teamRosterEntriesProvider` already
 * does client-side, capped so an unusually large squad doesn't fan out
 * unboundedly.
 */
async function fillTrainingStatuses(roster: SquadMemberSummary[]): Promise<SquadMemberSummary[]> {
  const capped = roster.slice(0, MAX_ROSTER_LOOKUPS);
  const snaps = await Promise.all(capped.map((m) => db().collection("users").doc(m.uid).get()));
  return capped.map((member, i) => {
    const profile = snaps[i]?.data()?.["playerProfile"] as Record<string, unknown> | undefined;
    return { ...member, trainingStatus: (profile?.["trainingStatus"] as string | undefined) ?? null };
  });
}
