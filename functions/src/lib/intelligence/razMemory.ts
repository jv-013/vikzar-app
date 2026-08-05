import { Timestamp } from "firebase-admin/firestore";
import { db } from "../admin";
import { RazMemoryEntry, RazMemorySource } from "./types";

/**
 * RazMemory — persistent, structured memory. Firestore-backed
 * (`users/{uid}/razMemories/{topic}`), never sourced from an LLM's own
 * context window, so it survives app restarts, new conversations, and
 * new devices exactly the way any other Vikzar data does. Cloud-
 * Function-only in both directions, same pattern as `razDailyBriefs` —
 * Flutter never reads this collection directly; it only ever sees
 * memory's effect through a `FootballReasoning`/`RazResponse` that used
 * it.
 *
 * One document per `topic`, not one per mention: a player mentioning
 * "left knee tightness" three times over three weeks should accumulate
 * into a single memory with `mentionCount: 3`, not three near-duplicate
 * rows — that's what lets RAZ say "you've mentioned this several times"
 * as a fact it counted, not an impression it invented.
 */

const MAX_RELATED_RECORD_IDS = 10;
const DEFAULT_MEMORY_LIMIT = 20;

function collectionRef(uid: string) {
  return db().collection("users").doc(uid).collection("razMemories");
}

interface RecordMemoryInput {
  uid: string;
  topic: string;
  source: RazMemorySource;
  fact: string;
  relatedRecordId?: string;
}

/**
 * Upserts a memory entry for `topic`. If this topic has never been
 * noted before, creates it with `mentionCount: 1`. If it has, updates
 * `fact` to the latest phrasing, bumps `lastNotedAt`, and increments
 * `mentionCount` — the topic's *history* (first noted, how many times)
 * is preserved even as the specific wording of `fact` gets refreshed.
 */
export async function recordMemory(input: RecordMemoryInput): Promise<void> {
  const ref = collectionRef(input.uid).doc(input.topic);
  await db().runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const now = Timestamp.now();

    if (!snap.exists) {
      const entry: Omit<RazMemoryEntry, "id" | "firstNotedAt" | "lastNotedAt"> & {
        firstNotedAt: Timestamp;
        lastNotedAt: Timestamp;
      } = {
        uid: input.uid,
        topic: input.topic,
        source: input.source,
        fact: input.fact,
        firstNotedAt: now,
        lastNotedAt: now,
        mentionCount: 1,
        relatedRecordIds: input.relatedRecordId ? [input.relatedRecordId] : [],
      };
      tx.set(ref, entry);
      return;
    }

    const data = snap.data() ?? {};
    const existingRelated = (data["relatedRecordIds"] as string[] | undefined) ?? [];
    const relatedRecordIds = input.relatedRecordId
      ? Array.from(new Set([...existingRelated, input.relatedRecordId])).slice(
          -MAX_RELATED_RECORD_IDS
        )
      : existingRelated;

    tx.update(ref, {
      source: input.source,
      fact: input.fact,
      lastNotedAt: now,
      mentionCount: ((data["mentionCount"] as number | undefined) ?? 0) + 1,
      relatedRecordIds,
    });
  });
}

/**
 * The player/coach's most recently-active memories, most recent first —
 * what `razContext.ts` folds into `PlayerContext.memories`/
 * `CoachContext.memories` for every reasoning pass. Capped, not
 * exhaustive: RAZ's job is to notice a recurring pattern, not to recite
 * a full history back verbatim.
 */
export async function getMemories(
  uid: string,
  limit = DEFAULT_MEMORY_LIMIT
): Promise<RazMemoryEntry[]> {
  const snap = await collectionRef(uid).orderBy("lastNotedAt", "desc").limit(limit).get();
  return snap.docs.map((doc) => {
    const data = doc.data();
    return {
      id: doc.id,
      uid: data["uid"] as string,
      topic: data["topic"] as string,
      source: data["source"] as RazMemorySource,
      fact: data["fact"] as string,
      firstNotedAt: (data["firstNotedAt"] as Timestamp).toDate(),
      lastNotedAt: (data["lastNotedAt"] as Timestamp).toDate(),
      mentionCount: (data["mentionCount"] as number | undefined) ?? 1,
      relatedRecordIds: (data["relatedRecordIds"] as string[] | undefined) ?? [],
    };
  });
}

/**
 * A memory is "recurring" once RAZ has genuinely counted it more than
 * once — the concrete threshold behind "I've noticed you've mentioned
 * your left knee several times recently," never phrased from a guess.
 */
export function isRecurring(memory: RazMemoryEntry): boolean {
  return memory.mentionCount >= 2;
}
