import { onCall } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import { parseRazAskPayload } from "../contracts/types";
import { GEMINI_API_KEY, routeToProvider } from "../lib/ai/aiService";
import { buildCoachContext, buildPlayerContext } from "../lib/intelligence/razContext";
import { deriveFootballReasoning } from "../lib/intelligence/razEngine";
import { buildConversationMessages } from "../lib/intelligence/razConversation";
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
 */
export const razAsk = onCall({ secrets: [GEMINI_API_KEY] }, async (request) => {
  const uid = requireSignedIn(request);
  const payload = parseRazAskPayload(request.data);
  await enforceRateLimit(uid, "razAsk", { maxCalls: 30, windowSeconds: 60 });

  const context =
    payload.audience === "player" ? await buildPlayerContext(uid) : await buildCoachContext(uid);
  const reasoning = deriveFootballReasoning(context, payload.audience);
  const messages = buildConversationMessages(reasoning, payload.question, payload.history);
  const text = await routeToProvider("gemini").generateText(messages);

  const response: RazResponse = {
    text,
    sections: [],
    highlights: [],
    confidence: reasoning.confidence.level,
    traceRefs: reasoning.traceRefs,
    awareness: reasoning.awareness,
  };
  logger.info("raz_ask_succeeded", { audience: payload.audience, confidence: reasoning.confidence.level });
  return response;
});
