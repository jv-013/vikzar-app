import { isRecurring } from "./razMemory";
import { RazMemoryEntry, RecommendationCategory, TrainingRecommendation } from "./types";

/**
 * RazRecommendations — every recommendation RAZ ever shows is computed
 * here from real Vikzar signals, never generated as free-form AI text
 * and never authored by the LLM. `razConversation.ts` only ever
 * *phrases* one of these; it cannot introduce a category, action, or
 * reason this file didn't already decide. `evidence` names exactly
 * which signals produced each recommendation — never shown to the user
 * verbatim, but always available internally, which is what "every
 * recommendation should internally reference evidence" means in code
 * rather than in a comment alone.
 */

interface DeriveRecommendationsInput {
  hasElevatedRisk: boolean;
  alertCount: number;
  memories: RazMemoryEntry[];
}

const CONCERN_MEMORY_SOURCES = new Set(["injury_history", "note", "wellness"]);

function recurringConcernMemories(memories: RazMemoryEntry[]): RazMemoryEntry[] {
  return memories.filter((m) => CONCERN_MEMORY_SOURCES.has(m.source) && isRecurring(m));
}

export function deriveRecommendations(input: DeriveRecommendationsInput): TrainingRecommendation[] {
  const { hasElevatedRisk, alertCount, memories } = input;
  const recurringConcerns = recurringConcernMemories(memories);

  if (hasElevatedRisk) {
    return [
      {
        category: "consult_staff",
        action: "Flag this to coaching or medical staff before the next session.",
        reason: `${alertCount} recent alert${alertCount === 1 ? "" : "s"} indicate elevated risk.`,
        evidence: ["risk_explanation.hasElevatedRisk", "risk_explanation.contributingAlerts"],
      },
      {
        category: "monitor",
        action: "Monitor closely over the next few sessions rather than pushing through it.",
        reason: "Elevated risk alone doesn't mean an injury has occurred — it means it's worth watching.",
        evidence: ["risk_explanation.hasElevatedRisk"],
      },
    ];
  }

  if (recurringConcerns.length > 0) {
    // A recurring, self-reported concern with no elevated alert-based
    // risk today — RAZ notices the pattern and suggests monitoring, but
    // never upgrades this to consult_staff on memory alone; that
    // category is reserved for genuine alert-driven risk (see above).
    const topic = recurringConcerns[0]!;
    return [
      {
        category: "monitor",
        action: `Keep an eye on ${topic.topic.replace(/_/g, " ")} — it's come up ${topic.mentionCount} times recently.`,
        reason: "A recurring note, not an alert — worth tracking rather than ignoring.",
        evidence: recurringConcerns.map((m) => `memory:${m.id}`),
      },
    ];
  }

  if (alertCount > 0) {
    return [
      {
        category: "monitor",
        action: "Keep an eye on this — nothing urgent, but worth tracking.",
        reason: `${alertCount} recent alert${alertCount === 1 ? "" : "s"} on record.`,
        evidence: ["risk_explanation.contributingAlerts"],
      },
    ];
  }

  return [
    {
      category: "continue" satisfies RecommendationCategory,
      action: "Continue as planned.",
      reason: "No elevated risk indicators in the available data.",
      evidence: ["risk_explanation.hasElevatedRisk"],
    },
  ];
}
