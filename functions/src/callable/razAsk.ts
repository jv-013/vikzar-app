import { onCall } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import { parseRazAskPayload } from "../contracts/types";
import { GEMINI_API_KEY, routeToProvider } from "../lib/ai/aiService";
import { buildCoachContext, buildPlayerContext } from "../lib/intelligence/razContext";
import { deriveFootballReasoning } from "../lib/intelligence/razEngine";
import { buildConversationMessages } from "../lib/intelligence/razConversation";
import { extractMemoryCandidate } from "../lib/intelligence/razMemoryExtraction";
import { recordMemory } from "../lib/intelligence/razMemory";
import { RazResponse } from "../lib/intelligence/types";
import { requireSignedIn } from "../lib/ingestionAuth";
import { enforceRateLimit } from "../lib/rateLimit";

/**
 * RAZ — conversational Q&A, the secondary interface to Vikzar's Football
 * Operating System (the Daily Brief is primary). RazContext -> RazEngine
 * (pure, structured — decides what's true and what's recommended) ->
 * RazConversation (phrases the reasoning as a reply to this specific
 * question) -> Model Router -> Structured Response. Flutter never calls
 * an LLM, and neither this function nor `razConversation.ts` know which
 * provider `routeToProvider()` returns — see `aiService.ts`.
 *
 * Unlike Daily Brief, conversational answers aren't cached: the
 * *reasoning* behind an answer is stable for a given context (and is
 * itself cheap, pure, local computation — deriving it twice costs
 * nothing worth caching), but the *question* varies every call, so the
 * expensive step (the LLM call) has to run per question regardless.
 *
 * Streaming — the response text is sent as it's generated via
 * `response.sendChunk`, per Firebase's streaming-callable protocol.
 * `sendChunk` is always safe to call even for a non-streaming caller
 * (it no-ops per the SDK's own contract), so this one handler serves
 * both a streaming Flutter client and any older/non-streaming caller
 * identically — the final `return`ed `RazResponse` (with the complete
 * `text`) is still delivered either way.
 */
export const razAsk = onCall({ secrets: [GEMINI_API_KEY] }, async (request, response) => {
  const uid = requireSignedIn(request);
  const payload = parseRazAskPayload(request.data);
  await enforceRateLimit(uid, "razAsk", { maxCalls: 30, windowSeconds: 60 });

  const context =
    payload.audience === "player" ? await buildPlayerContext(uid) : await buildCoachContext(uid);
  const reasoning = deriveFootballReasoning(context, payload.audience);
  const messages = buildConversationMessages(reasoning, payload.question, payload.history, payload.mode);

  let text = "";
  for await (const delta of routeToProvider("gemini").generateTextStream(messages, response?.signal)) {
    text += delta;
    await response?.sendChunk(delta);
  }

  // The client disconnected mid-stream (`response.signal` fired, which
  // is also what stopped `generateTextStream` above from pulling further
  // chunks — see `resilientProvider.ts`). Nobody is listening for a
  // return value or an error here; ending quietly, without the
  // "empty response" throw below or the memory write/success log past
  // this point, keeps a normal disconnect from being logged as a
  // synthetic failure.
  if (response?.signal?.aborted) {
    logger.info("raz_ask_client_disconnected", { audience: payload.audience });
    return {
      text: "",
      sections: [],
      highlights: [],
      confidence: reasoning.confidence.level,
      traceRefs: reasoning.traceRefs,
      awareness: reasoning.awareness,
    } satisfies RazResponse;
  }

  text = text.trim();
  if (text.length === 0) {
    throw new Error("Gemini returned an empty streamed response.");
  }

  // Best-effort — a memory-write failure must never fail the actual
  // answer the athlete is waiting on. Runs on the athlete's own words,
  // never the model's answer, per `razMemoryExtraction.ts`'s scope.
  const candidate = extractMemoryCandidate(payload.question);
  if (candidate) {
    try {
      await recordMemory({
        uid,
        topic: candidate.topic,
        source: "conversation",
        fact: candidate.fact,
      });
    } catch (error) {
      logger.warn("raz_ask_memory_write_failed", {
        error: error instanceof Error ? error.message : String(error),
      });
    }
  }

  const razResponse: RazResponse = {
    text,
    sections: [],
    highlights: [],
    confidence: reasoning.confidence.level,
    traceRefs: reasoning.traceRefs,
    awareness: reasoning.awareness,
  };
  logger.info("raz_ask_succeeded", { audience: payload.audience, confidence: reasoning.confidence.level });
  return razResponse;
});
