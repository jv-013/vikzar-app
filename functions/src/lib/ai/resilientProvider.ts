import * as logger from "firebase-functions/logger";
import { LlmMessage, LlmProvider } from "./llmProvider";

const TIMEOUT_MS = 20_000;
const MAX_ATTEMPTS = 2;

/**
 * Wraps any {@link LlmProvider} with the resilience behavior every
 * provider needs identically — a bounded timeout, one retry on
 * transient failure, and structured logging — per Phase 17 §8. Applied
 * once, inside {@link routeToProvider}, so a future Claude/OpenAI/local
 * provider gets this for free rather than reimplementing it per
 * provider or per Callable.
 */
class ResilientLlmProvider implements LlmProvider {
  constructor(
    private readonly inner: LlmProvider,
    private readonly providerName: string
  ) {}

  async generateText(messages: LlmMessage[]): Promise<string> {
    let lastError: unknown;
    for (let attempt = 1; attempt <= MAX_ATTEMPTS; attempt++) {
      const startedAt = Date.now();
      try {
        const text = await this.withTimeout(this.inner.generateText(messages));
        logger.info("llm_call_succeeded", {
          provider: this.providerName,
          attempt,
          durationMs: Date.now() - startedAt,
        });
        return text;
      } catch (error) {
        lastError = error;
        logger.warn("llm_call_failed", {
          provider: this.providerName,
          attempt,
          durationMs: Date.now() - startedAt,
          error: error instanceof Error ? error.message : String(error),
        });
      }
    }
    logger.error("llm_call_exhausted_retries", {
      provider: this.providerName,
      attempts: MAX_ATTEMPTS,
    });
    throw lastError instanceof Error
      ? lastError
      : new Error(`${this.providerName} failed after ${MAX_ATTEMPTS} attempts.`);
  }

  private withTimeout(promise: Promise<string>): Promise<string> {
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        reject(new Error(`${this.providerName} timed out after ${TIMEOUT_MS}ms.`));
      }, TIMEOUT_MS);
      promise.then(
        (value) => {
          clearTimeout(timer);
          resolve(value);
        },
        (error) => {
          clearTimeout(timer);
          reject(error);
        }
      );
    });
  }
}

export function withResilience(provider: LlmProvider, providerName: string): LlmProvider {
  return new ResilientLlmProvider(provider, providerName);
}
