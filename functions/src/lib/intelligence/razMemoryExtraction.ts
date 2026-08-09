/**
 * RazMemoryExtraction — the minimum safe write path into `razMemory.ts`.
 * Deliberately deterministic (keyword matching), not a second LLM call:
 * an extra model call on every `razAsk` would add latency, cost, and a
 * new failure mode to a path that's supposed to be getting *faster*
 * this phase, and a wrong extraction would write something to a
 * player's permanent record with no human in the loop. Keyword matching
 * against what the athlete literally typed/said is conservative by
 * construction — it can miss things, but it can't invent them.
 *
 * Scope, on purpose: body-related mentions only (the category the
 * product actually needs memory for today — "you've mentioned your
 * knee several times"). Broaden this deliberately later; don't let it
 * grow into a general-purpose entity extractor by accident.
 */

const BODY_PART_TOPICS: [pattern: RegExp, topic: string][] = [
  [/\bleft\s+knee\b/i, "left_knee"],
  [/\bright\s+knee\b/i, "right_knee"],
  [/\bknee(s)?\b/i, "knee"],
  [/\bleft\s+ankle\b/i, "left_ankle"],
  [/\bright\s+ankle\b/i, "right_ankle"],
  [/\bankle(s)?\b/i, "ankle"],
  [/\bleft\s+hamstring\b/i, "left_hamstring"],
  [/\bright\s+hamstring\b/i, "right_hamstring"],
  [/\bhamstring(s)?\b/i, "hamstring"],
  [/\bgroin\b/i, "groin"],
  [/\bcalf\b|\bcalves\b/i, "calf"],
  [/\bhip(s)?\b/i, "hip"],
  [/\bback\b/i, "back"],
  [/\bshoulder(s)?\b/i, "shoulder"],
  [/\bquad(s)?\b|\bquadricep(s)?\b/i, "quad"],
];

const CONCERN_SIGNAL =
  /\b(hurt|hurts|hurting|pain|sore|soreness|tight|tightness|ache|aches|aching|stiff|stiffness|swollen|swelling|niggle|discomfort)\b/i;

export interface MemoryCandidate {
  topic: string;
  fact: string;
}

const MAX_FACT_LENGTH = 200;

/**
 * Returns a candidate only when the message names a body part *and*
 * pairs it with a genuine concern word — "my knee" alone (e.g. "I hit
 * my knee on the ball" in casual conversation) isn't enough on its own,
 * matching the body-part list is common enough in normal football talk
 * that pairing with a concern signal keeps this from over-triggering.
 */
export function extractMemoryCandidate(question: string): MemoryCandidate | null {
  if (!CONCERN_SIGNAL.test(question)) return null;

  for (const [pattern, topic] of BODY_PART_TOPICS) {
    if (pattern.test(question)) {
      const trimmed = question.trim();
      const fact =
        `Mentioned: "${trimmed.length > MAX_FACT_LENGTH ? trimmed.slice(0, MAX_FACT_LENGTH) + "…" : trimmed}"`;
      return { topic: `${topic}_discomfort`, fact };
    }
  }
  return null;
}
