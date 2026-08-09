/**
 * RAZ's provider seam — the LLM explains predictions; it never makes
 * them. Anything implementing this interface can be swapped in without
 * touching a caller: `lib/intelligence/razConversation.ts` builds
 * messages, `aiService.ts` picks the provider, `callable/razAsk.ts`/
 * `callable/razDailyBrief.ts` never know which one — "future model
 * changes should never require Flutter changes" (nor, by the same seam,
 * most backend changes either).
 */
export interface LlmMessage {
  role: "system" | "user";
  content: string;
}

export interface LlmProvider {
  generateText(messages: LlmMessage[]): Promise<string>;

  /**
   * Same contract as {@link generateText}, yielded incrementally as the
   * model produces it — each chunk is the *next slice* of text, not a
   * cumulative snapshot. Callers concatenate chunks themselves. Exists
   * so `razAsk` can start speaking/rendering an answer before the full
   * response has finished generating; `generateText` remains for
   * callers (Daily Brief) that only ever need the complete text anyway.
   *
   * [signal], when given, is forwarded to the underlying provider so a
   * client disconnect (Firebase's own `CallableResponse.signal`) stops
   * this function's own work promptly instead of continuing to pull and
   * discard chunks for a caller that's already gone. Best-effort only —
   * see `GeminiProvider`'s doc comment on what it does and doesn't stop.
   */
  generateTextStream(messages: LlmMessage[], signal?: AbortSignal): AsyncGenerator<string>;
}
