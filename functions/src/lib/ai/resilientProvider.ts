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

  /**
   * A stream can't be silently retried once any chunk has reached the
   * caller — re-running the call would re-speak/re-render already-
   * delivered text. So resilience here only covers what happens
   * *before* the first chunk: bounded wait, one retry, same as
   * {@link generateText}. Once streaming genuinely starts, errors
   * propagate directly to the caller instead of retrying mid-stream.
   *
   * [signal] is forwarded to each attempt's underlying provider call
   * (see `GeminiProvider`) and also checked directly between attempts —
   * an already-aborted caller (client disconnected while attempt 1's
   * first-chunk timeout was pending) must not spend a second attempt on
   * a Gemini call nobody will ever read.
   */
  async *generateTextStream(messages: LlmMessage[], signal?: AbortSignal): AsyncGenerator<string> {
    let lastError: unknown;
    for (let attempt = 1; attempt <= MAX_ATTEMPTS; attempt++) {
      if (signal?.aborted) {
        logger.info("llm_stream_aborted_before_attempt", { provider: this.providerName, attempt });
        return;
      }
      const startedAt = Date.now();
      const generator = this.inner.generateTextStream(messages, signal);
      let first: IteratorResult<string>;
      try {
        first = await this.withFirstChunkTimeout(generator.next());
      } catch (error) {
        lastError = error;
        // An abort surfacing as a "failure" isn't a transient error to
        // retry — it's the caller telling us to stop. `generator.return()`
        // signals the abandoned generator (and, through it, `for await`
        // in `GeminiProvider`) to release its underlying stream promptly
        // rather than leaving it to resolve/reject on its own later.
        await generator.return(undefined);
        if (signal?.aborted) {
          logger.info("llm_stream_aborted", { provider: this.providerName, attempt });
          return;
        }
        logger.warn("llm_stream_first_chunk_failed", {
          provider: this.providerName,
          attempt,
          durationMs: Date.now() - startedAt,
          error: error instanceof Error ? error.message : String(error),
        });
        continue;
      }

      logger.info("llm_stream_started", {
        provider: this.providerName,
        attempt,
        durationMs: Date.now() - startedAt,
      });
      if (!first.done) yield first.value;
      // From here on, propagate directly — see doc comment above.
      while (true) {
        if (signal?.aborted) {
          await generator.return(undefined);
          return;
        }
        const next = await generator.next();
        if (next.done) break;
        yield next.value;
      }
      return;
    }
    logger.error("llm_stream_exhausted_retries", {
      provider: this.providerName,
      attempts: MAX_ATTEMPTS,
    });
    throw lastError instanceof Error
      ? lastError
      : new Error(`${this.providerName} failed to start streaming after ${MAX_ATTEMPTS} attempts.`);
  }

  private withFirstChunkTimeout(
    promise: Promise<IteratorResult<string>>
  ): Promise<IteratorResult<string>> {
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        reject(new Error(`${this.providerName} timed out after ${TIMEOUT_MS}ms waiting for first chunk.`));
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
