import { deriveRecommendations } from "./razRecommendations";
import {
  CoachContext,
  FootballReasoning,
  PlayerContext,
  RazAudience,
  RetrievedRecord,
} from "./types";

/**
 * RazEngine — the reasoning engine. A pure function of context: no LLM
 * call, no Firestore read, no network access, fully deterministic and
 * unit-testable. This is the actual analytical step — deciding what's
 * true, what's risky, and what to recommend — separated from
 * `razConversation.ts`'s job of phrasing it. "The LLM is not the
 * intelligence; the LLM is only one renderer" means this file, not the
 * model, is where Vikzar's football reasoning actually lives.
 */

const SEVERE_ALERT_KEYWORDS = ["critical", "warning"];

function isSevere(record: RetrievedRecord): boolean {
  return SEVERE_ALERT_KEYWORDS.some((keyword) => record.summary.toLowerCase().startsWith(keyword));
}

function traceRefsFor(records: RetrievedRecord[]): string[] {
  return records.map((r) => `${r.kind}:${r.id}`);
}

export function deriveFootballReasoning(
  context: PlayerContext | CoachContext,
  audience: RazAudience
): FootballReasoning {
  return audience === "player"
    ? derivePlayerReasoning(context as PlayerContext)
    : deriveCoachReasoning(context as CoachContext);
}

function derivePlayerReasoning(context: PlayerContext): FootballReasoning {
  const severeAlerts = context.recentAlerts.filter(isSevere);
  const hasElevatedRisk = severeAlerts.length > 0;
  const allRecords = [
    ...context.recentAlerts,
    ...context.recentReports,
    ...context.recentSessions,
    ...context.recentNotifications,
  ];

  // Awareness improves confidence's *ceiling*, not its floor — more
  // connected hardware means more signal available, but a quiet Pod
  // feed with nothing anomalous in it is still exactly as
  // record-driven as any other source; confidence itself always comes
  // from how much real data was actually counted, per this function's
  // own doc comment.
  const recordConfidence = allRecords.length === 0 ? 0 : allRecords.length < 3 ? 1 : 2;
  const awarenessBonus = context.awareness.level > 0 ? 1 : 0;
  const confidenceIndex = Math.min(2, recordConfidence + (recordConfidence > 0 ? awarenessBonus : 0));

  return {
    audience: "player",
    generatedAt: new Date(),
    sessionInsight: {
      upcoming: context.nextSession ? [context.nextSession] : [],
    },
    performanceInsight: {
      trainingStatus: context.trainingStatus,
      squadByStatus: null,
      recentSessionSummaries: context.recentSessions,
    },
    // No recovery-trend pipeline exists yet — see types.ts's doc comment
    // on RecoveryInsight. Honest, not a placeholder.
    recoveryInsight: { available: false, detail: "No recovery pipeline connected yet." },
    riskExplanation: {
      hasElevatedRisk,
      contributingAlerts: hasElevatedRisk ? severeAlerts : context.recentAlerts,
      affectedPlayers: [],
    },
    recommendations: deriveRecommendations({
      hasElevatedRisk,
      alertCount: context.recentAlerts.length,
      memories: context.memories,
    }),
    confidence: {
      level: (["low", "moderate", "high"] as const)[confidenceIndex]!,
      basis: `${allRecords.length} recent record${allRecords.length === 1 ? "" : "s"} available` +
        (context.awareness.level > 0 ? `, hardware awareness at level ${context.awareness.level}.` : "."),
    },
    traceRefs: traceRefsFor(allRecords),
    awareness: context.awareness,
  };
}

function deriveCoachReasoning(context: CoachContext): FootballReasoning {
  const severeAlerts = context.recentAlerts.filter(isSevere);
  const hasElevatedRisk = severeAlerts.length > 0 || context.playersWithUnacknowledgedAlerts.length > 0;

  return {
    audience: "coach",
    generatedAt: new Date(),
    sessionInsight: {
      upcoming: context.todaysSessions,
    },
    performanceInsight: {
      trainingStatus: null,
      squadByStatus: context.squadByStatus,
      recentSessionSummaries: [],
    },
    recoveryInsight: { available: false, detail: "No recovery pipeline connected yet." },
    riskExplanation: {
      hasElevatedRisk,
      contributingAlerts: severeAlerts,
      affectedPlayers: context.playersWithUnacknowledgedAlerts,
    },
    recommendations: deriveRecommendations({
      hasElevatedRisk,
      alertCount: context.recentAlerts.length,
      memories: context.memories,
    }),
    confidence: {
      level: context.recentAlerts.length === 0 ? "low" : context.recentAlerts.length < 3 ? "moderate" : "high",
      basis: `${context.recentAlerts.length} recent alert${context.recentAlerts.length === 1 ? "" : "s"}, ` +
        `${context.squad.length} squad member${context.squad.length === 1 ? "" : "s"}.`,
    },
    traceRefs: traceRefsFor(context.recentAlerts),
    awareness: context.awareness,
  };
}
