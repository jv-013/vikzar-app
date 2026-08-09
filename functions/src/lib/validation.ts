import { HttpsError } from "firebase-functions/v2/https";

/** Throws a `HttpsError("invalid-argument", ...)` naming the missing/bad field. */
export function fail(message: string): never {
  throw new HttpsError("invalid-argument", message);
}

export function requireString(data: unknown, field: string): string {
  const record = data as Record<string, unknown>;
  const value = record?.[field];
  if (typeof value !== "string" || value.length === 0) {
    fail(`"${field}" is required and must be a non-empty string.`);
  }
  return value as string;
}

export function optionalString(data: unknown, field: string): string | undefined {
  const record = data as Record<string, unknown>;
  const value = record?.[field];
  if (value == null) return undefined;
  if (typeof value !== "string" || value.length === 0) {
    fail(`"${field}", if present, must be a non-empty string.`);
  }
  return value as string;
}

export function requireNumber(data: unknown, field: string): number {
  const record = data as Record<string, unknown>;
  const value = record?.[field];
  if (typeof value !== "number" || Number.isNaN(value)) {
    fail(`"${field}" is required and must be a number.`);
  }
  return value as number;
}

export function optionalNumber(data: unknown, field: string): number | undefined {
  const record = data as Record<string, unknown>;
  const value = record?.[field];
  if (value == null) return undefined;
  if (typeof value !== "number" || Number.isNaN(value)) {
    fail(`"${field}", if present, must be a number.`);
  }
  return value as number;
}

/** Phase 13 — bounds a number to an inclusive [min, max] range, e.g. a documented 0.0-1.0 score. */
export function requireNumberInRange(
  data: unknown,
  field: string,
  min: number,
  max: number
): number {
  const value = requireNumber(data, field);
  if (value < min || value > max) {
    fail(`"${field}" must be between ${min} and ${max}. Received ${value}.`);
  }
  return value;
}

/** Phase 13 — same as {@link requireNumberInRange}, but the field itself is optional. */
export function optionalNumberInRange(
  data: unknown,
  field: string,
  min: number,
  max: number
): number | undefined {
  const value = optionalNumber(data, field);
  if (value == null) return undefined;
  if (value < min || value > max) {
    fail(`"${field}", if present, must be between ${min} and ${max}. Received ${value}.`);
  }
  return value;
}

/** Phase 13 — caps a required string's length (free-text fields have no natural bound otherwise). */
export function requireBoundedString(data: unknown, field: string, maxLength: number): string {
  const value = requireString(data, field);
  if (value.length > maxLength) {
    fail(`"${field}" must be at most ${maxLength} characters. Received ${value.length}.`);
  }
  return value;
}

/** Phase 13 — same as {@link requireBoundedString}, but the field itself is optional. */
export function optionalBoundedString(
  data: unknown,
  field: string,
  maxLength: number
): string | undefined {
  const value = optionalString(data, field);
  if (value == null) return undefined;
  if (value.length > maxLength) {
    fail(`"${field}", if present, must be at most ${maxLength} characters. Received ${value.length}.`);
  }
  return value;
}

/**
 * Phase 13 (§8, "reject unknown fields") — rejects any top-level key on
 * `data` not in `allowedKeys`. Every `parse*Payload` function calls this
 * first, before plucking individual fields, so a client can't smuggle
 * extra top-level data into a payload the way the field-by-field pluck
 * alone would silently allow.
 */
export function requireExactShape(data: unknown, allowedKeys: readonly string[]): void {
  if (typeof data !== "object" || data === null || Array.isArray(data)) {
    fail("Payload must be an object.");
  }
  const unknownKeys = Object.keys(data as Record<string, unknown>).filter(
    (key) => !allowedKeys.includes(key)
  );
  if (unknownKeys.length > 0) {
    fail(`Unknown field(s): ${unknownKeys.join(", ")}.`);
  }
}

export function requireEnum<T extends string>(
  data: unknown,
  field: string,
  allowed: readonly T[]
): T {
  const value = requireString(data, field);
  if (!allowed.includes(value as T)) {
    fail(`"${field}" must be one of: ${allowed.join(", ")}. Received "${value}".`);
  }
  return value as T;
}

export function optionalEnum<T extends string>(
  data: unknown,
  field: string,
  allowed: readonly T[]
): T | undefined {
  const value = optionalString(data, field);
  if (value == null) return undefined;
  if (!allowed.includes(value as T)) {
    fail(`"${field}", if present, must be one of: ${allowed.join(", ")}. Received "${value}".`);
  }
  return value as T;
}

export function requireStringArray(data: unknown, field: string): string[] {
  const record = data as Record<string, unknown>;
  const value = record?.[field];
  if (!Array.isArray(value) || value.length === 0 || !value.every((v) => typeof v === "string")) {
    fail(`"${field}" is required and must be a non-empty array of strings.`);
  }
  return value as string[];
}

/** Parses an ISO 8601 timestamp string (§21.2, "laptop-reported timestamps") into a Date. */
export function requireIsoTimestamp(data: unknown, field: string): Date {
  const raw = requireString(data, field);
  const parsed = new Date(raw);
  if (Number.isNaN(parsed.getTime())) {
    fail(`"${field}" must be a valid ISO 8601 timestamp string. Received "${raw}".`);
  }
  return parsed;
}

export function requireObject(data: unknown, field: string): Record<string, unknown> {
  const record = data as Record<string, unknown>;
  const value = record?.[field];
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    fail(`"${field}" is required and must be an object.`);
  }
  return value as Record<string, unknown>;
}

export function optionalObject(
  data: unknown,
  field: string
): Record<string, unknown> | undefined {
  const record = data as Record<string, unknown>;
  const value = record?.[field];
  if (value == null) return undefined;
  if (typeof value !== "object" || Array.isArray(value)) {
    fail(`"${field}", if present, must be an object.`);
  }
  return value as Record<string, unknown>;
}
