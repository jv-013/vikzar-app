import { createHash } from "node:crypto";

/**
 * Canonical, order-independent JSON hashing — Phase 17 §5. Two
 * structurally identical contexts (same fields and values, keys in any
 * order) always hash identically; anything that actually changed
 * produces a different hash. "Only call the model when context
 * genuinely changes" is built directly on this.
 */
function canonicalize(value: unknown): unknown {
  if (Array.isArray(value)) return value.map(canonicalize);
  if (value instanceof Date) return value.toISOString();
  if (value !== null && typeof value === "object") {
    const sorted: Record<string, unknown> = {};
    for (const key of Object.keys(value as Record<string, unknown>).sort()) {
      sorted[key] = canonicalize((value as Record<string, unknown>)[key]);
    }
    return sorted;
  }
  return value;
}

export function hashContext(context: unknown): string {
  const canonical = JSON.stringify(canonicalize(context));
  return createHash("sha256").update(canonical).digest("hex");
}
