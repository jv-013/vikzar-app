import type { GoogleGenAI as GoogleGenAIClient } from "@google/genai";
import { LlmMessage, LlmProvider } from "./llmProvider";

/**
 * RAZ's initial provider — Gemini. The API key comes
 * from a Secret Manager-backed secret (see `aiService.ts`'s
 * `GEMINI_API_KEY`), never a hardcoded string, and is only ever read at
 * call time, never logged.
 *
 * `@google/genai` ships ESM-only (`"type": "module"`), while these
 * functions compile to CommonJS. A static `import` here would compile to
 * a top-level `require("@google/genai")` that runs the moment Firebase
 * loads this module to discover the backend spec — before any handler
 * runs — and synchronously `require()`-ing an ESM package is unreliable
 * (observed hanging for 8+ seconds locally), which is what produced
 * "Cannot determine backend specification. Timeout after 10000." at
 * deploy. Loading it via a real dynamic `import()`, deferred until a
 * call actually happens, uses Node's proper async ESM loader instead and
 * keeps module load itself instant.
 */
export class GeminiProvider implements LlmProvider {
  constructor(
    private readonly apiKey: string,
    private readonly model: string = "gemini-flash-latest"
  ) {}

  async generateText(messages: LlmMessage[]): Promise<string> {
    const { GoogleGenAI }: { GoogleGenAI: typeof GoogleGenAIClient } = await import(
      "@google/genai"
    );
    const client = new GoogleGenAI({ apiKey: this.apiKey });
    const systemInstruction = messages
      .filter((m) => m.role === "system")
      .map((m) => m.content)
      .join("\n\n");
    const userContent = messages
      .filter((m) => m.role === "user")
      .map((m) => m.content)
      .join("\n\n");

    const response = await client.models.generateContent({
      model: this.model,
      contents: userContent,
      config: systemInstruction.length > 0 ? { systemInstruction } : undefined,
    });

    const text = response.text;
    if (typeof text !== "string" || text.trim().length === 0) {
      throw new Error("Gemini returned an empty response.");
    }
    return text.trim();
  }
}
