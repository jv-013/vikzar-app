import { HttpsError } from "firebase-functions/v2/https";
import { Timestamp, FieldValue } from "firebase-admin/firestore";
import { db } from "./admin";

/**
 * Phase 13 §10 — a simple fixed-window per-principal call counter, backed
 * by `_rateLimits/{action}_{principalId}` (Cloud-Function-only per
 * firestore.rules — never client-readable or -writable). Deliberately a
 * fixed window, not a sliding one or a leaky bucket: good enough to bound
 * a runaway loop or a leaked-credential spike, not a precision traffic
 * shaper. Scoped to the two highest-frequency/highest-cost callables
 * this phase adds real end-user or field-deployed traffic to
 * (`ingestLiveTick`, `createPlannedSession`) — see DECISIONS.md for why
 * broader, general-purpose rate limiting belongs at the Firebase App
 * Check / GCP Console level, not hand-rolled here.
 */
export async function enforceRateLimit(
  principalId: string,
  action: string,
  opts: { maxCalls: number; windowSeconds: number }
): Promise<void> {
  const ref = db().collection("_rateLimits").doc(`${action}_${principalId}`);
  const windowMs = opts.windowSeconds * 1000;

  await db().runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const now = Date.now();
    const data = snap.exists ? snap.data() : undefined;
    const windowStart = (data?.["windowStart"] as Timestamp | undefined)?.toMillis();

    if (windowStart == null || now - windowStart > windowMs) {
      // First call, or the previous window has fully elapsed — reset.
      tx.set(ref, { windowStart: Timestamp.fromMillis(now), count: 1 });
      return;
    }

    const count = (data?.["count"] as number | undefined) ?? 0;
    if (count >= opts.maxCalls) {
      throw new HttpsError(
        "resource-exhausted",
        `Rate limit exceeded for "${action}": max ${opts.maxCalls} calls per ${opts.windowSeconds}s.`
      );
    }
    tx.update(ref, { count: FieldValue.increment(1) });
  });
}
