import { HttpsError, CallableRequest } from "firebase-functions/v2/https";
import { db } from "./admin";

/**
 * Phase 13 §5/§7 — authorization for the first Cloud Function callable by
 * a real product end user (a Coach), not the laptop ingestion principal.
 * Per §7's explicit instruction: never trust a client-claimed `teamId` or
 * role — this derives "is the caller a coach of this team" entirely from
 * the caller's authenticated `uid` (Firebase Auth, verified by the
 * platform before this code runs) cross-checked against Firestore's own
 * `teams/{teamId}.coachIds`, the same source of truth
 * `firestore.rules`'s `isCoachOfTeam()` helper uses for the identical
 * check on the client side.
 */
export async function requireCoachOfTeam(
  request: CallableRequest<unknown>,
  teamId: string
): Promise<string> {
  const uid = request.auth?.uid;
  if (uid == null) {
    throw new HttpsError("unauthenticated", "This function requires a signed-in caller.");
  }
  const teamSnap = await db().collection("teams").doc(teamId).get();
  if (!teamSnap.exists) {
    throw new HttpsError("not-found", `teams/${teamId} does not exist.`);
  }
  const coachIds = teamSnap.data()?.["coachIds"];
  if (!Array.isArray(coachIds) || !coachIds.includes(uid)) {
    throw new HttpsError("permission-denied", `Caller is not a coach of teams/${teamId}.`);
  }
  return uid;
}
