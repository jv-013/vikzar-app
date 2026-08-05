import { WriteBatch } from "firebase-admin/firestore";
import { db } from "./admin";

/** Firestore's own hard limit on operations per `WriteBatch`. */
const MAX_BATCH_SIZE = 500;

/**
 * Chunks `items` into batches of at most `MAX_BATCH_SIZE`, committing each
 * chunk sequentially (never in parallel, to stay well within per-second
 * write-rate limits on any one shard for an unusually large chunk count).
 * `apply` stages one item's writes onto the given batch; it does not call
 * `.commit()` itself. Two call sites (`writeNotifications`,
 * `deviceHeartbeatMonitor`) had byte-identical chunking logic under
 * different names before this was factored out.
 */
export async function chunkedBatchWrite<T>(
  items: T[],
  apply: (batch: WriteBatch, item: T) => void
): Promise<void> {
  for (let start = 0; start < items.length; start += MAX_BATCH_SIZE) {
    const chunk = items.slice(start, start + MAX_BATCH_SIZE);
    const batch = db().batch();
    for (const item of chunk) {
      apply(batch, item);
    }
    await batch.commit();
  }
}
