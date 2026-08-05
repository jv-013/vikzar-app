import { onCall } from "firebase-functions/v2/https";
import { Timestamp } from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";
import { db } from "../lib/admin";
import { generateInviteCode } from "../lib/inviteCode";
import { requireSignedIn } from "../lib/ingestionAuth";
import { enforceRateLimit } from "../lib/rateLimit";
import { parseCreateTeamPayload } from "../contracts/types";

/**
 * Phase 15 — the Coach onboarding "Create a new team" action, moved
 * server-side. Previously the Flutter client wrote `teams/{teamId}`
 * directly with itself as sole coach (ADR-051's MVP self-service model);
 * this keeps the same one-step UX but derives the coach's identity from
 * `request.auth.uid` rather than trusting a client-supplied coachId, and
 * generates the team's first invite code in the same write so "Invite
 * Player" has something real to show immediately.
 */
export const createTeam = onCall(async (request) => {
  const uid = requireSignedIn(request);
  const payload = parseCreateTeamPayload(request.data);
  // §10 — a human creates a team rarely; bounds an accidental double-tap
  // or a scripted/compromised account spamming team creation.
  await enforceRateLimit(uid, "createTeam", { maxCalls: 5, windowSeconds: 60 });

  const teamRef = db().collection("teams").doc();
  const inviteCode = generateInviteCode();
  const inviteRef = db().collection("teamInvites").doc(inviteCode);
  const now = Timestamp.now();

  await db().runTransaction(async (tx) => {
    tx.set(teamRef, {
      teamId: teamRef.id,
      name: payload.name,
      ...(payload.ageGroup != null ? { ageGroup: payload.ageGroup } : {}),
      coachIds: [uid],
      status: "active",
      createdAt: now,
      updatedAt: now,
    });
    tx.set(inviteRef, {
      code: inviteCode,
      teamId: teamRef.id,
      active: true,
      createdBy: uid,
      createdAt: now,
    });
  });

  logger.info("create_team_succeeded", { teamId: teamRef.id, uid });
  return { teamId: teamRef.id, inviteCode };
});
