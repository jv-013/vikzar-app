import { onCall } from "firebase-functions/v2/https";
import { Timestamp } from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";
import { db } from "../lib/admin";
import { requireCoachOfTeam } from "../lib/coachAuth";
import { generateInviteCode } from "../lib/inviteCode";
import { enforceRateLimit } from "../lib/rateLimit";
import { parseCreateTeamInvitePayload } from "../contracts/types";

/**
 * Phase 15 — "Invite Player" on the Coach Dashboard/Profile. Returns the
 * team's current active invite code, generating one if none exists
 * (covers teams created before this function existed). `regenerate:
 * true` deactivates the previous code and issues a fresh one — the old
 * code stops working immediately, matching "Manage Team"'s expectation
 * that a coach can revoke a code that's leaked or been shared too
 * widely.
 */
export const createTeamInvite = onCall(async (request) => {
  const payload = parseCreateTeamInvitePayload(request.data);
  const coachUid = await requireCoachOfTeam(request, payload.teamId);
  await enforceRateLimit(coachUid, "createTeamInvite", { maxCalls: 5, windowSeconds: 60 });

  const invitesRef = db().collection("teamInvites");
  const now = Timestamp.now();

  if (!payload.regenerate) {
    const existing = await invitesRef
      .where("teamId", "==", payload.teamId)
      .where("active", "==", true)
      .limit(1)
      .get();
    if (!existing.empty) {
      logger.info("create_team_invite_reused_existing", { teamId: payload.teamId });
      return { inviteCode: existing.docs[0]!.id };
    }
  }

  const code = generateInviteCode();
  await db().runTransaction(async (tx) => {
    if (payload.regenerate) {
      const previous = await tx.get(
        invitesRef.where("teamId", "==", payload.teamId).where("active", "==", true)
      );
      for (const doc of previous.docs) {
        tx.update(doc.ref, { active: false, deactivatedAt: now });
      }
    }
    tx.set(invitesRef.doc(code), {
      code,
      teamId: payload.teamId,
      active: true,
      createdBy: coachUid,
      createdAt: now,
    });
  });

  logger.info("create_team_invite_succeeded", { teamId: payload.teamId, regenerate: payload.regenerate ?? false });
  return { inviteCode: code };
});
