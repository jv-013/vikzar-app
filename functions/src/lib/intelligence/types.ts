/**
 * RAZ — Vikzar's Football Operating System. Shared structured types for
 * the RazContext -> RazKnowledge -> RazEngine -> RazConversation -> LLM
 * -> Structured Response pipeline. Nothing here is Flutter-specific, and
 * Flutter never constructs these — they exist entirely server-side, per
 * "the frontend must never call the LLM directly, everything flows
 * through backend APIs."
 */

export type RazAudience = "player" | "coach";

/**
 * One already-summarized fact pulled from Firestore — never a raw
 * document. RazKnowledge's whole job is producing these instead of
 * handing a `DocumentSnapshot` to anything downstream.
 */
export interface RetrievedRecord {
  id: string;
  kind: "alert" | "report" | "plannedSession" | "notification" | "session";
  summary: string;
  occurredAt: Date;
  /** Present when this record concerns a specific squad member — used
   *  by Coach context to attribute alerts/reports to a player without
   *  re-deriving it downstream. */
  relatedPlayerId?: string;
  relatedPlayerName?: string;
}

// ---------------------------------------------------------------------------
// Awareness — hardware upgrades RAZ, it never activates it. Every player/
// coach is fully served at Level 0 (no hardware); connecting a Pod or an
// EMG band only ever *adds* to what RAZ can see, never gates the base
// experience. See `razHardwareContext.ts`.
// ---------------------------------------------------------------------------

/**
 * L0 is always available. L1/L2 require hardware genuinely connected and
 * streaming today (Pods, then EMG). L3 is a documented extension point
 * only — no GPS/weather/additional-wearable pipeline exists yet, and
 * this level is never reached in practice; it exists so a future
 * integration has a defined slot rather than requiring a redesign of
 * this enum.
 */
export type AwarenessLevel = 0 | 1 | 2 | 3;

export interface AwarenessSource {
  /** Machine-stable key, e.g. "player_data", "pods". */
  key: string;
  /** Human-facing label for the Awareness card, e.g. "Training History". */
  label: string;
  active: boolean;
}

export interface HardwareAwareness {
  level: AwarenessLevel;
  sources: AwarenessSource[];
}

export interface PlayerContext {
  uid: string;
  displayName: string;
  trainingStatus: string | null;
  position: string | null;
  hasCoach: boolean;
  /** No device-pairing pipeline exists yet (`lib/features/devices/` is
   *  empty client-side too) — always false today, honestly, not a
   *  fabricated reading. */
  podConnected: boolean;
  nextSession: { title: string; scheduledAt: Date; location?: string } | null;
  recentAlerts: RetrievedRecord[];
  recentReports: RetrievedRecord[];
  recentSessions: RetrievedRecord[];
  recentNotifications: RetrievedRecord[];
  unreadNotificationCount: number;
  /** Structured facts RAZ has retained about this player from past
   *  interactions/data — see `razMemory.ts`. Always present (possibly
   *  empty), never re-derived from an LLM's own context window. */
  memories: RazMemoryEntry[];
  awareness: HardwareAwareness;
}

export interface SquadMemberSummary {
  uid: string;
  displayName: string;
  trainingStatus: string | null;
}

export interface CoachContext {
  uid: string;
  displayName: string;
  teamId: string | null;
  teamName: string | null;
  squad: SquadMemberSummary[];
  squadByStatus: Record<string, number>;
  todaysSessions: { title: string; scheduledAt: Date }[];
  recentAlerts: RetrievedRecord[];
  playersWithUnacknowledgedAlerts: { uid: string; displayName: string }[];
  unreadNotificationCount: number;
  memories: RazMemoryEntry[];
  awareness: HardwareAwareness;
}

/**
 * What actually informed the response — computed deterministically from
 * how much real data existed, never self-reported by the LLM. Asking a
 * model to grade its own confidence is exactly the kind of
 * fabricated-sounding-certainty this layer exists to avoid.
 */
export type RazConfidence = "high" | "moderate" | "low";

export interface RazHighlight {
  label: string;
  value: string;
}

/**
 * A distinct block of a Daily Brief ("Performance summary / Recovery
 * advice / Today's focus" for a player; "Team brief / Players needing
 * attention / Upcoming sessions / Recent alerts" for a coach). Empty for
 * a plain conversational `razAsk` reply, which has no natural sections
 * — `text` alone covers that case.
 */
export interface RazSection {
  label: string;
  body: string;
}

/** The Structured Response the pipeline hands back to Flutter. */
export interface RazResponse {
  text: string;
  sections: RazSection[];
  highlights: RazHighlight[];
  confidence: RazConfidence;
  /** Which real records this drew on, e.g. "alert:abc123" — lets a
   *  future UI deep-link "why" without the LLM inventing citations. */
  traceRefs: string[];
  /** What informed this specific response — powers the Awareness card.
   *  Always the awareness the reasoning that produced this response
   *  actually used, never a separately-fetched "current" value that
   *  could drift from it. */
  awareness: HardwareAwareness;
}

// ---------------------------------------------------------------------------
// Structured football reasoning. Derived by `razEngine.ts`, a pure
// function of `PlayerContext`/`CoachContext` with no LLM call involved.
// This is "the reasoning output" — the single source of truth —
// `razConversation.ts` turns one of these into prose for whichever
// surface asked (chat, Daily Brief, notifications, and later coach
// summaries/a smartwatch complication); it never invents a fact this
// object doesn't already contain.
// ---------------------------------------------------------------------------

export interface ConfidenceScore {
  level: RazConfidence;
  /** Why — e.g. "3 recent alerts, 1 upcoming session" — always a plain
   *  description of what was actually counted, never a statistical claim. */
  basis: string;
}

export interface SessionInsight {
  /** Player: their next planned session. Coach: today's scheduled sessions. */
  upcoming: { title: string; scheduledAt: Date; location?: string }[];
}

export interface PerformanceInsight {
  /** Player: their own training status. Coach: squad availability breakdown. */
  trainingStatus: string | null;
  squadByStatus: Record<string, number> | null;
  recentSessionSummaries: RetrievedRecord[];
}

/**
 * Deliberately honest about a real schema gap: no ETL/ML pipeline
 * writes a persisted recovery-trend value anywhere in this app yet (see
 * `razDailyBrief.ts`'s doc comment). `available: false` is the correct
 * value today, not a placeholder to fill in later — `razEngine.ts` never
 * invents a recovery score to make this field look more complete than
 * the data actually is.
 */
export interface RecoveryInsight {
  available: boolean;
  detail?: string;
}

export interface RiskExplanation {
  hasElevatedRisk: boolean;
  contributingAlerts: RetrievedRecord[];
  /** Coach only — which specific squad members the risk concerns. */
  affectedPlayers: { uid: string; displayName: string }[];
}

export type RecommendationCategory = "continue" | "monitor" | "rest" | "consult_staff";

/**
 * Computed by `razRecommendations.ts` from `hasElevatedRisk`/alert
 * severity/memory, never authored by the LLM — the safety rule (never
 * diagnose, never prescribe treatment) is enforced structurally this
 * way: the LLM only ever narrates a recommendation this list already
 * contains, in one of these four safe categories, and can't introduce a
 * fifth one on its own. `evidence` names exactly which signals produced
 * this recommendation — never shown verbatim to the user, but always
 * available for support/debugging and for RAZ's own internal confidence
 * accounting.
 */
export interface TrainingRecommendation {
  category: RecommendationCategory;
  action: string;
  reason: string;
  evidence: string[];
}

export interface FootballReasoning {
  audience: RazAudience;
  generatedAt: Date;
  sessionInsight: SessionInsight;
  performanceInsight: PerformanceInsight;
  recoveryInsight: RecoveryInsight;
  riskExplanation: RiskExplanation;
  recommendations: TrainingRecommendation[];
  confidence: ConfidenceScore;
  traceRefs: string[];
  awareness: HardwareAwareness;
}

// ---------------------------------------------------------------------------
// RazMemory — persistent, structured memory. Never sourced from an LLM's
// own context window; always written by Vikzar's own data layer so it
// survives app restarts, new conversations, and new devices. See
// `razMemory.ts`.
// ---------------------------------------------------------------------------

export type RazMemorySource =
  | "session"
  | "daily_brief"
  | "wellness"
  | "injury_history"
  | "note"
  | "alert"
  | "conversation"
  | "coach_comment"
  | "calendar"
  | "profile";

export interface RazMemoryEntry {
  id: string;
  uid: string;
  /** e.g. "left_knee_discomfort", "sprint_load_trend" — a stable topic
   *  key so repeated mentions of the same thing accumulate under one
   *  memory rather than creating unbounded near-duplicates. */
  topic: string;
  source: RazMemorySource;
  /** Plain-language fact, e.g. "Mentioned left knee tightness." — never
   *  a diagnosis, always a record of what was observed or said. */
  fact: string;
  firstNotedAt: Date;
  lastNotedAt: Date;
  /** How many distinct times this topic has been noted — lets RAZ say
   *  "you've mentioned this several times" honestly, from a count, not
   *  a guess. */
  mentionCount: number;
  relatedRecordIds: string[];
}
