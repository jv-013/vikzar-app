import { defineSecret } from "firebase-functions/params";
import { LlmProvider } from "./llmProvider";
import { GeminiProvider } from "./geminiProvider";
import { withResilience } from "./resilientProvider";

/**
 * Secret Manager-backed — never a hardcoded string, never committed.
 * Locally resolved from `functions/.secret.local` (gitignored) by the
 * Firebase emulator; in production it must be set once via
 * `firebase functions:secrets:set GEMINI_API_KEY` (requires the project
 * owner's authenticated Firebase CLI).
 */
export const GEMINI_API_KEY = defineSecret("GEMINI_API_KEY");

/**
 * The Model Router — Phase 17 §3. Every provider Vikzar could ever use
 * (Gemini today; Claude, OpenAI, a local model, or a future provider
 * later) satisfies the same {@link LlmProvider} interface — one
 * `generateText(messages)` method, nothing provider-specific leaking
 * upward. `razConversation.ts` and every Callable that renders a
 * `FootballReasoning` call {@link routeToProvider}, never `new
 * GeminiProvider(...)` directly, so adding a provider later is a new
 * `case` in this switch — not a change to the Reasoning Engine, the
 * render step, any Callable, or anything in Flutter (which never knew
 * a provider existed in the first place).
 *
 * Only `"gemini"` is registered today, on purpose: Vikzar has exactly
 * one real, working LLM integration. Wiring a `ClaudeProvider`/
 * `OpenAiProvider` class here that doesn't call a real API would be the
 * kind of provider-specific placeholder this phase explicitly rules
 * out — this router's job is to make adding a real one later purely
 * additive, not to pretend one already exists.
 */
export type ModelProviderId = "gemini" | "claude" | "openai" | "local";

export function routeToProvider(preferred: ModelProviderId = "gemini"): LlmProvider {
  switch (preferred) {
    case "gemini":
      return withResilience(new GeminiProvider(GEMINI_API_KEY.value()), "gemini");
    case "claude":
    case "openai":
    case "local":
      throw new Error(
        `No provider registered for "${preferred}" yet — only "gemini" is available today. ` +
          `Add a class implementing LlmProvider (see geminiProvider.ts for the pattern) and a new ` +
          `case in routeToProvider() to register one; nothing above this file needs to change.`
      );
  }
}

/**
 * @deprecated Use {@link routeToProvider} — kept as a thin alias so this
 * isn't a breaking rename for any caller still written against the
 * Phase 16 name. New code should call `routeToProvider()` directly.
 */
export function getLlmProvider(): LlmProvider {
  return routeToProvider("gemini");
}
