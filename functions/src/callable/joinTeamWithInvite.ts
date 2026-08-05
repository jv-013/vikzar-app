import { onCall, HttpsError } from "firebase-functions/v2/https";
import { Timestamp } from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";
import { db } from "../lib/admin";
import { requireSignedIn } from "../lib/ingestionAuth";
import { enforceRateLimit } from "../lib/rateLimit";
import { parseJoinTeamWithInvitePayload } from "../contracts/types";

/**
 * Phase 15 — the real "Join Team" redemption a player's invite-code
 * entry screen calls. Replaces the previous client-direct
 * `teams/{teamId}/members/{uid}.set()` (which trusted a client-supplied
 * teamId with no invite system behind it at all). Resolves the code via
 * `teamInvites/{code}` (Admin SDK read, not subject to
 * `firestore.rules` — that collection denies all client access, so this
 * Callable is the only path that can ever read one) and writes the
 * roster entry plus the caller's own `workspaces.player.teamId` in one
 * transaction, entirely from `request.auth.uid` — never a client-claimed
 * uid or teamId.
 */
export const joinTeamWithInvite = onCall(async (request) => {
  const uid = requireSignedIn(request);
  const payload = parseJoinTeamWithInvitePayload(request.data);
  await enforceRateLimit(uid, "joinTeamWithInvite", { maxCalls: 10, windowSeconds: 60 });

  const code = payload.inviteCode.trim().toUpperCase();
  const inviteRef = db().collection("teamInvites").doc(code);
  const userRef = db().collection("users").doc(uid);

  const teamId = await db().runTransaction(async (tx) => {
    const [inviteSnap, userSnap] = await Promise.all([tx.get(inviteRef), tx.get(userRef)]);

    if (!inviteSnap.exists || inviteSnap.data()?.["active"] !== true) {
      throw new HttpsError("not-found", "This invite code is invalid or has expired.");
    }
    const resolvedTeamId = inviteSnap.data()?.["teamId"] as string;

    const userData = userSnap.data();
    const playerWorkspace = userData?.["workspaces"]?.["player"];
    if (!userSnap.exists || playerWorkspace == null) {
      throw new HttpsError(
        "failed-precondition",
        "Finish setting up your Player profile before joining a team."
      );
    }
    if (playerWorkspace["teamId"] === resolvedTeamId) {
      // Already on this team — idempotent, not an error.
      return resolvedTeamId;
    }

    const teamRef = db().collection("teams").doc(resolvedTeamId);
    const teamSnap = await tx.get(teamRef);
    if (!teamSnap.exists) {
      throw new HttpsError("not-found", "This team no longer exists.");
    }

    const now = Timestamp.now();
    const displayName = (userData?.["displayName"] as string | undefined) ?? "";
    tx.set(teamRef.collection("members").doc(uid), {
      uid,
      displayName,
      role: "player",
      status: "active",
      joinedAt: now,
    });
    tx.update(userRef, {
      "workspaces.player": { teamId: resolvedTeamId },
      updatedAt: now,
    });

    return resolvedTeamId;
  });

  logger.info("join_team_with_invite_succeeded", { teamId, uid });
  return { teamId };
});
