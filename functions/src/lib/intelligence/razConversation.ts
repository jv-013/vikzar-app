import { LlmMessage } from "../ai/llmProvider";
import { RAZ_SYSTEM_INSTRUCTION } from "./persona";
import { FootballReasoning, RetrievedRecord } from "./types";

/**
 * RazConversation — the render step. Takes a `FootballReasoning`
 * (already decided, already safe — see `razEngine.ts`) and turns it
 * into LLM messages. This file's only job is phrasing: it never decides
 * *what* to say, only helps say it naturally. Every surface (chat,
 * Daily Brief, and later notifications/coach summaries) starts from the
 * exact same `FootballReasoning` — this is "every presentation layer
 * simply renders it differently" in code.
 */

function formatDate(date: Date): string {
  return date.toLocaleString("en-US", {
    weekday: "short",
    month: "short",
    day: "numeric",
    hour: "numeric",
    minute: "2-digit",
  });
}

function recordLines(label: string, records: RetrievedRecord[]): string {
  if (records.length === 0) return `${label}: none.`;
  return `${label}:\n` + records.map((r) => `- ${r.summary} (${formatDate(r.occurredAt)})`).join("\n");
}

/** Serializes the *reasoning*, not the raw context, into the block the LLM sees. */
function reasoningBlock(reasoning: FootballReasoning): string {
  const activeAwareness = reasoning.awareness.sources
    .filter((s) => s.active)
    .map((s) => s.label)
    .join(", ");

  const lines = [
    reasoning.sessionInsight.upcoming.length > 0
      ? `Upcoming:\n${reasoning.sessionInsight.upcoming
          .map((s) => `- "${s.title}" at ${formatDate(s.scheduledAt)}${s.location ? ` (${s.location})` : ""}`)
          .join("\n")}`
      : "Upcoming: nothing scheduled.",
    reasoning.performanceInsight.trainingStatus != null
      ? `Training status: ${reasoning.performanceInsight.trainingStatus}`
      : "",
    reasoning.performanceInsight.squadByStatus != null
      ? `Squad by status:\n${Object.entries(reasoning.performanceInsight.squadByStatus)
          .map(([status, count]) => `  - ${status}: ${count}`)
          .join("\n")}`
      : "",
    recordLines("Recent completed sessions", reasoning.performanceInsight.recentSessionSummaries),
    reasoning.recoveryInsight.available
      ? `Recovery: ${reasoning.recoveryInsight.detail ?? "available"}`
      : `Recovery data: not yet available (${reasoning.recoveryInsight.detail ?? "no pipeline connected"}).`,
    reasoning.riskExplanation.hasElevatedRisk
      ? `Risk: ELEVATED. ${recordLines("Contributing alerts", reasoning.riskExplanation.contributingAlerts)}`
      : `Risk: no elevated indicators. ${recordLines("Alerts on record", reasoning.riskExplanation.contributingAlerts)}`,
    reasoning.riskExplanation.affectedPlayers.length > 0
      ? `Players this concerns:\n${reasoning.riskExplanation.affectedPlayers
          .map((p) => `- ${p.displayName}`)
          .join("\n")}`
      : "",
    `Recommended actions:\n${reasoning.recommendations.map((r) => `- [${r.category}] ${r.action} (${r.reason})`).join("\n")}`,
    `Current awareness: level ${reasoning.awareness.level} (${activeAwareness || "no active sources"}).`,
  ];
  return lines.filter((line) => line.length > 0).join("\n");
}

export interface ConversationTurn {
  question: string;
  answer: string;
}

const MAX_HISTORY_TURNS = 6;

export function buildConversationMessages(
  reasoning: FootballReasoning,
  question: string,
  history: ConversationTurn[]
): LlmMessage[] {
  const audience = reasoning.audience;
  const historyBlock = history
    .slice(-MAX_HISTORY_TURNS)
    .map(
      (turn) =>
        `${audience === "player" ? "Player" : "Coach"} asked: "${turn.question}"\nYou answered: "${turn.answer}"`
    )
    .join("\n\n");

  return [
    { role: "system", content: RAZ_SYSTEM_INSTRUCTION },
    {
      role: "user",
      content:
        `Current football reasoning for this ${audience}:\n${reasoningBlock(reasoning)}` +
        (historyBlock ? `\n\nEarlier in this conversation:\n${historyBlock}` : "") +
        `\n\nThe ${audience} asks: "${question}"\n\n` +
        `Answer using only the reasoning above. If it doesn't cover what they asked, say so directly.`,
    },
  ];
}

/**
 * The Daily Brief renders as distinct sections, not one paragraph.
 * `PLAYER_SECTION_LABELS`/`COACH_SECTION_LABELS` are the exact tags the
 * model is asked to use and the exact tags
 * {@link parseDailyBriefSections} looks for — kept next to each other
 * on purpose, since the prompt format and the parser are one contract,
 * not two things that happen to agree.
 */
const PLAYER_SECTION_LABELS: [tag: string, display: string][] = [
  ["PERFORMANCE", "Performance"],
  ["RECOVERY", "Recovery"],
  ["FOCUS", "Today's Focus"],
];
const COACH_SECTION_LABELS: [tag: string, display: string][] = [
  ["TEAM", "Team Brief"],
  ["ATTENTION", "Needs Attention"],
  ["SESSIONS", "Upcoming Sessions"],
  ["ALERTS", "Recent Alerts"],
];

function sectionLabelsFor(audience: "player" | "coach"): [tag: string, display: string][] {
  return audience === "player" ? PLAYER_SECTION_LABELS : COACH_SECTION_LABELS;
}

export function buildDailyBriefMessages(reasoning: FootballReasoning): LlmMessage[] {
  const audience = reasoning.audience;
  const labels = sectionLabelsFor(audience);
  const format = labels.map(([tag]) => `${tag}: <1-2 short sentences>`).join("\n");
  const instruction =
    audience === "player"
      ? "Write this player's morning brief in exactly this format, one line per tag, nothing before or " +
        `after it:\n${format}\n\nPERFORMANCE covers how they're set up for today. RECOVERY covers the ` +
        "recovery note if available, or says plainly that there's nothing to report yet if not. FOCUS " +
        "covers today's focus, drawn from the recommended actions. If a section is genuinely uneventful, " +
        "say so calmly there rather than inventing urgency."
      : "Write this coach's morning brief in exactly this format, one line per tag, nothing before or " +
        `after it:\n${format}\n\nTEAM covers squad availability. ATTENTION covers anything or anyone ` +
        "needing it (elevated risk, specific players) or says there's nothing right now. SESSIONS covers " +
        "today's schedule. ALERTS covers what's on record. If a section is genuinely uneventful, say so " +
        "calmly there rather than inventing urgency.";

  return [
    { role: "system", content: RAZ_SYSTEM_INSTRUCTION },
    {
      role: "user",
      content: `Current football reasoning for this ${audience}:\n${reasoningBlock(reasoning)}\n\n${instruction}`,
    },
  ];
}

/**
 * Parses the labeled-line format {@link buildDailyBriefMessages} asked
 * for back into distinct sections. Never throws on malformed output —
 * an LLM not perfectly following a format is expected, not exceptional
 * — falls back to one unlabeled section holding the raw text so the
 * brief never renders empty.
 */
export function parseDailyBriefSections(
  raw: string,
  audience: "player" | "coach"
): { label: string; body: string }[] {
  const labels = sectionLabelsFor(audience);
  const tagPattern = new RegExp(`^(${labels.map(([tag]) => tag).join("|")}):\\s*(.*)$`);
  const displayFor = (tag: string) => labels.find(([t]) => t === tag)?.[1] ?? tag;

  const sections: { label: string; body: string }[] = [];
  let currentTag: string | null = null;
  let currentLines: string[] = [];
  const flush = () => {
    if (currentTag == null) return;
    const body = currentLines.join(" ").trim();
    if (body.length > 0) sections.push({ label: displayFor(currentTag), body });
  };

  for (const line of raw.split("\n")) {
    const match = line.trim().match(tagPattern);
    if (match) {
      flush();
      currentTag = match[1]!;
      currentLines = [match[2] ?? ""];
    } else if (currentTag != null && line.trim().length > 0) {
      currentLines.push(line.trim());
    }
  }
  flush();

  if (sections.length === 0 && raw.trim().length > 0) {
    return [{ label: audience === "player" ? "Today" : "Team Brief", body: raw.trim() }];
  }
  return sections;
}
