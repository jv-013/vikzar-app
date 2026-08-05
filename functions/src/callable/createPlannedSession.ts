import { onCall, HttpsError } from "firebase-functions/v2/https";
import { Timestamp } from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";
import { db } from "../lib/admin";
import { requireCoachOfTeam } from "../lib/coachAuth";
import { enforceRateLimit } from "../lib/rateLimit";
import { parseCreatePlannedSessionPayload } from "../contracts/types";

/**
 * Phase 13 §5 — the Coach "Create Session" UI never writes to Firestore
 * directly; it calls this Callable, which validates and authorizes
 * server-side before writing `plannedSessions/{plannedSessionId}`. This
 * is a *scheduled* session (a calendar entry a coach creates ahead of
 * time) — distinct from `sessions/{sessionId}` (§1.8), which represents
 * a real hardware capture and remains exclusively laptop-authored via
 * `startSession`. Conflating the two would corrupt `sessions`'
 * `pipelineVersion`/`generatedBy` invariants, which only make sense for
 * an actual capture.
 *
 * `onPlannedSessionCreated` (triggers/onPlannedSessionCreated.ts) reacts
 * to the resulting document creation to notify the team's players.
 */
export const createPlannedSession = onCall(async (request) => {
  const payload = parseCreatePlannedSessionPayload(request.data);
  const coachUid = await requireCoachOfTeam(request, payload.teamId);
  await enforceRateLimit(coachUid, "createPlannedSession", { maxCalls: 10, windowSeconds: 60 });

  // Phase 15 — a client-supplied playerIds list is only ever a hint of
  // intent; each id must actually be on this team's roster before it's
  // trusted, the same "backend derives everything" rule every other
  // field on this payload already follows.
  if (payload.playerIds != null && payload.playerIds.length > 0) {
    const memberSnaps = await Promise.all(
      payload.playerIds.map((playerId) =>
        db().collection("teams").doc(payload.teamId).collection("members").doc(playerId).get()
      )
    );
    const invalid = memberSnaps.filter((snap) => !snap.exists).map((snap) => snap.id);
    if (invalid.length > 0) {
      throw new HttpsError(
        "invalid-argument",
        `playerIds contains ids not on teams/${payload.teamId}'s roster: ${invalid.join(", ")}.`
      );
    }
  }

  const ref = db().collection("plannedSessions").doc();
  const now = Timestamp.now();
  await ref.set({
    plannedSessionId: ref.id,
    teamId: payload.teamId,
    title: payload.title,
    type: payload.type,
    scheduledAt: Timestamp.fromDate(payload.scheduledAt),
    ...(payload.notes != null ? { notes: payload.notes } : {}),
    ...(payload.durationMinutes != null ? { durationMinutes: payload.durationMinutes } : {}),
    ...(payload.location != null ? { location: payload.location } : {}),
    ...(payload.playerIds != null ? { playerIds: payload.playerIds } : {}),
    status: "scheduled",
    createdBy: coachUid,
    createdAt: now,
    updatedAt: now,
  });

  logger.info("create_planned_session_succeeded", { plannedSessionId: ref.id, teamId: payload.teamId });
  return { plannedSessionId: ref.id };
});
