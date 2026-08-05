import { onCall, HttpsError } from "firebase-functions/v2/https";
import { Timestamp } from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";
import { db } from "../lib/admin";
import { requireAdminPrincipal } from "../lib/adminAuth";
import { requireExactShape, requireString } from "../lib/validation";

/**
 * Phase 13 §3 — the backend half of "Become a Coach". Grants
 * `workspaces.coach` on the requesting user's `users/{uid}` document —
 * the only path that can, since `firestore.rules` denies any client
 * write to `workspaces` beyond the fields already listed in its
 * allowlist being self-written, and a *new* workspace grant specifically
 * must never be something the requester can self-approve. Does **not**
 * change `defaultWorkspace` — approval adds a workspace, per ADR-031's
 * "one account, multiple workspaces" model; it never silently switches
 * which one opens by default. No admin UI exists yet — see
 * lib/adminAuth.ts for what provisioning the calling principal requires.
 */
export const approveCoachRequest = onCall(async (request) => {
  requireAdminPrincipal(request);
  requireExactShape(request.data, ["requestId"]);
  const requestId = requireString(request.data, "requestId");
  logger.info("approve_coach_request_started", { requestId });

  const requestRef = db().collection("coachRequests").doc(requestId);

  await db().runTransaction(async (tx) => {
    const requestSnap = await tx.get(requestRef);
    if (!requestSnap.exists) {
      throw new HttpsError("not-found", `coachRequests/${requestId} does not exist.`);
    }
    const requestData = requestSnap.data()!;
    if (requestData["status"] !== "pending") {
      throw new HttpsError(
        "failed-precondition",
        `coachRequests/${requestId} is not pending (already "${requestData["status"]}").`
      );
    }
    const uid = requestData["uid"] as string;
    const userRef = db().collection("users").doc(uid);
    const userSnap = await tx.get(userRef);
    if (!userSnap.exists) {
      throw new HttpsError("not-found", `users/${uid} does not exist.`);
    }

    const now = Timestamp.now();
    tx.update(userRef, {
      "workspaces.coach": { teamIds: [] },
      updatedAt: now,
    });
    tx.update(requestRef, {
      status: "approved",
      approvedAt: now,
    });
  });

  logger.info("approve_coach_request_succeeded", { requestId });
  return { requestId };
});
