import { Timestamp } from "firebase-admin/firestore";
import { db } from "../admin";
import { RazResponse } from "./types";

/**
 * Replaces the original date-keyed Daily Brief cache. Keyed by a hash of
 * the structured context that actually produced the response, not by
 * calendar date: if nothing about a player's real data changed since
 * yesterday, the cached brief is still exactly correct today and the
 * LLM is never called again for it. If something *does* change mid-day
 * (a new alert fires), the hash changes immediately, so the very next
 * request already regenerates without waiting for a new calendar day —
 * this is more correct than "once per day," not just cheaper.
 *
 * `REASONING_VERSION` is the versioning hook: bump it whenever
 * `razEngine.ts`/`razConversation.ts` change in a way that should
 * invalidate every existing cache entry. No data migration needed —
 * it's folded into the document id, so old entries simply stop being
 * looked up and are garbage-collected the next time
 * {@link invalidateCachedReasoning} runs for that user.
 *
 * Cloud-Function-only in both directions — `firestore.rules` denies all
 * client access to `razDailyBriefs`, matching `_rateLimits`. Flutter
 * always gets a brief through `razDailyBrief`'s return value, never by
 * reading this collection directly.
 */
export const REASONING_VERSION = 1;

/** Even with an unchanged context hash, a brief older than this regenerates — "daily" stays meaningfully daily. */
const MAX_AGE_MS = 24 * 60 * 60 * 1000;

function collectionRef(uid: string) {
  return db().collection("users").doc(uid).collection("razDailyBriefs");
}

function docId(audience: string, contextHash: string): string {
  return `${audience}_v${REASONING_VERSION}_${contextHash}`;
}

export async function getCachedReasoning(
  uid: string,
  audience: string,
  contextHash: string
): Promise<RazResponse | null> {
  const snap = await collectionRef(uid).doc(docId(audience, contextHash)).get();
  const data = snap.data();
  if (!data) return null;

  const generatedAt = (data["generatedAt"] as Timestamp | undefined)?.toMillis();
  if (generatedAt == null || Date.now() - generatedAt > MAX_AGE_MS) return null;

  return (data["response"] as RazResponse | undefined) ?? null;
}

export async function setCachedReasoning(
  uid: string,
  audience: string,
  contextHash: string,
  response: RazResponse
): Promise<void> {
  await collectionRef(uid)
    .doc(docId(audience, contextHash))
    .set({
      response,
      contextHash,
      reasoningVersion: REASONING_VERSION,
      generatedAt: Timestamp.now(),
    });
}

/**
 * Garbage-collects every cached entry for this user — a stale entry is
 * already harmless (its hash simply won't match the next request's
 * context and it'll never be read again), but without this,
 * `razDailyBriefs` would grow one document per context change forever.
 * Called from `onAlertCreated`/`onReportCreated` when something real
 * just changed for this player (and, via `teamId`, that team's
 * coaches). Best-effort: a failure here never blocks the write that
 * triggered it.
 */
export async function invalidateCachedReasoning(uid: string): Promise<void> {
  const snap = await collectionRef(uid).get();
  if (snap.empty) return;
  const batch = db().batch();
  for (const doc of snap.docs) batch.delete(doc.ref);
  await batch.commit();
}
