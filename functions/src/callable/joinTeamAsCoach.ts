import { onCall, HttpsError } from "firebase-functions/v2/https";
import { FieldValue, Timestamp } from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";
import { db } from "../lib/admin";
import { requireSignedIn } from "../lib/ingestionAuth";
import { enforceRateLimit } from "../lib/rateLimit";
import { parseJoinTeamAsCoachPayload } from "../contracts/types";

/**
 * Phase 15 — Coach onboarding's "Join an existing team" mode, moved
 * server-side. Keeps the exact same UX (a coach types the team's id,
 * shared out-of-band by whoever manages that team) — this only replaces
 * the previous direct client write of `teams/{teamId}.coachIds` (which
 * let anyone who ever learned a teamId self-add as a co-coach with no
 * server-side check at all) with an authorized, validated Callable.
 */
export const joinTeamAsCoach = onCall(async (request) => {
  const uid = requireSignedIn(request);
  const payload = parseJoinTeamAsCoachPayload(request.data);
  await enforceRateLimit(uid, "joinTeamAsCoach", { maxCalls: 5, windowSeconds: 60 });

  const teamRef = db().collection("teams").doc(payload.teamId);
  const teamSnap = await teamRef.get();
  if (!teamSnap.exists) {
    throw new HttpsError("not-found", `teams/${payload.teamId} does not exist.`);
  }

  await teamRef.update({
    coachIds: FieldValue.arrayUnion(uid),
    updatedAt: Timestamp.now(),
  });

  logger.info("join_team_as_coach_succeeded", { teamId: payload.teamId, uid });
  return { teamId: payload.teamId };
});
