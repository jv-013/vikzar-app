import { onCall } from "firebase-functions/v2/https";
import { Timestamp } from "firebase-admin/firestore";
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

  const ref = db().collection("plannedSessions").doc();
  const now = Timestamp.now();
  await ref.set({
    plannedSessionId: ref.id,
    teamId: payload.teamId,
    title: payload.title,
    type: payload.type,
    scheduledAt: Timestamp.fromDate(payload.scheduledAt),
    ...(payload.notes != null ? { notes: payload.notes } : {}),
    status: "scheduled",
    createdBy: coachUid,
    createdAt: now,
    updatedAt: now,
  });

  return { plannedSessionId: ref.id };
});
