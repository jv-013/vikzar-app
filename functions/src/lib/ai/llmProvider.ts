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
}
