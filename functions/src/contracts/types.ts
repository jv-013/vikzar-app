import {
  requireEnum,
  requireIsoTimestamp,
  requireNumberInRange,
  requireObject,
  requireString,
  requireBoundedString,
  requireStringArray,
  requireExactShape,
  optionalNumberInRange,
  optionalObject,
  optionalString,
  optionalBoundedString,
  fail,
} from "../lib/validation";

/** Phase 13 (§8) — a free-text field with no natural bound (messages, codes, versions). */
const MAX_TEXT_LENGTH = 2000;
/** Phase 13 (§8) — a short identifier-shaped free-text field. */
const MAX_SHORT_TEXT_LENGTH = 200;

export const RISK_LEVELS = ["low", "moderate", "high", "critical"] as const;
export type RiskLevel = (typeof RISK_LEVELS)[number];

export const CONNECTION_STATUSES = ["connected", "degraded", "reconnecting"] as const;
export type ConnectionStatus = (typeof CONNECTION_STATUSES)[number];

// Device *connectivity* status — distinct from devices.status (§1.7's
// active/inactive/maintenance/lost administrative/inventory lifecycle,
// coach-set, unchanged). This is real-time telemetry, Cloud-Function-only,
// derived by ingestLiveTick/deviceHeartbeatMonitor (Phase 11 Section 3/4).
export const DEVICE_CONNECTIVITY_STATUSES = [
  "online",
  "offline",
  "low_battery",
  "charging",
  "disconnected",
  "unknown",
] as const;
export type DeviceConnectivityStatus = (typeof DEVICE_CONNECTIVITY_STATUSES)[number];

// Physical mount location — additive, coach-settable at assignment time
// (not reported live). Closes the "recommended, not implemented" gap from
// vikzar-ai/docs/research/UNIVERSAL_POD_MOUNTING.md.
export const MOUNT_LOCATIONS = ["shin_guard", "compression_sleeve", "thigh_band"] as const;
export type MountLocation = (typeof MOUNT_LOCATIONS)[number];

// Laterality — additive, coach-settable. Closes the "two Pods per player
// need distinct logical device IDs" gap from
// vikzar-ai/docs/architecture/08_PRODUCTION_BLUETOOTH_ARCHITECTURE.md.
export const DEVICE_LATERALITIES = ["left", "right"] as const;
export type DeviceLaterality = (typeof DEVICE_LATERALITIES)[number];

// Laptop-local capture phase — the finer-grained lifecycle a laptop
// operator's console moves through while a session is "live". Additive
// only: does NOT replace or extend the locked, deployed sessions.status
// enum (live/completed/completed_with_gaps/aborted), which remains the
// sole source of truth for querying/indexing/Security Rules. "preparing"
// has no session document yet (session doesn't exist until startSession),
// so it is never a Firestore value — it's a laptop-side-only concept,
// documented here for completeness.
export const SESSION_CAPTURE_PHASES = ["recording", "paused", "uploading"] as const;
export type SessionCapturePhase = (typeof SESSION_CAPTURE_PHASES)[number];

export const SESSION_TYPES = ["training", "match"] as const;
export type SessionType = (typeof SESSION_TYPES)[number];

export const SESSION_STATUSES = [
  "completed",
  "completed_with_gaps",
  "aborted",
] as const;
export type SessionStatus = (typeof SESSION_STATUSES)[number];

export const ALERT_SEVERITIES = ["info", "warning", "critical"] as const;
export type AlertSeverity = (typeof ALERT_SEVERITIES)[number];

// Phase 13 §5 — a coach-scheduled training/match slot, distinct from the
// laptop-authored `sessions/{sessionId}` (§1.8), which represents a real
// hardware capture and remains laptop-only. See
// callable/createPlannedSession.ts.
export const PLANNED_SESSION_STATUSES = ["scheduled", "cancelled", "completed"] as const;
export type PlannedSessionStatus = (typeof PLANNED_SESSION_STATUSES)[number];

export const ALERT_TYPES = [
  "high_impact",
  "risk_threshold_exceeded",
  "abnormal_fatigue_asymmetry",
  "device_disconnected",
  "low_battery",
] as const;
export type AlertType = (typeof ALERT_TYPES)[number];

// ---------------------------------------------------------------------------
// startSession — BACKEND_SPECIFICATION.md §21.3
// ---------------------------------------------------------------------------

export interface StartSessionPayload {
  sessionId: string;
  playerId: string;
  teamId?: string;
  orgId?: string;
  type: SessionType;
  deviceIds: string[];
  startedAt: Date;
}

export function parseStartSessionPayload(data: unknown): StartSessionPayload {
  requireExactShape(data, [
    "sessionId", "playerId", "teamId", "orgId", "type", "deviceIds", "startedAt",
  ]);
  return {
    sessionId: requireString(data, "sessionId"),
    playerId: requireString(data, "playerId"),
    teamId: optionalString(data, "teamId"),
    orgId: optionalString(data, "orgId"),
    type: requireEnum(data, "type", SESSION_TYPES),
    deviceIds: requireStringArray(data, "deviceIds"),
    startedAt: requireIsoTimestamp(data, "startedAt"),
  };
}

// ---------------------------------------------------------------------------
// ingestLiveTick — BACKEND_SPECIFICATION.md §21.4
//
// `confidence`/`fatigueScore`/`fatigueLevel`/`workloadRatio`/`workloadStatus`/
// `asymmetryScore`/`asymmetryStatus`/`muscleBalanceScore`/`muscleBalanceStatus`
// are additive optional fields (DECISIONS.md ADR — cross-repo contract
// alignment) capturing vikzar-ai's ACLRiskEngine sub-scores, which are
// richer than the original §8 metrics map. Additive only — every original
// required field is unchanged.
// ---------------------------------------------------------------------------

export interface LiveTickMetrics {
  currentLoad: number;
  cumulativeImpacts: number;
  riskScore: number;
  riskLevel: RiskLevel;
  emgActivation?: number;
  confidence?: number;
  fatigueScore?: number;
  fatigueLevel?: string;
  workloadRatio?: number;
  workloadStatus?: string;
  asymmetryScore?: number;
  asymmetryStatus?: string;
  muscleBalanceScore?: number;
  muscleBalanceStatus?: string;
}

export interface IngestLiveTickPayload {
  sessionId: string;
  playerId: string;
  teamId?: string;
  sequenceNumber: number;
  tickTimestamp: Date;
  connectionStatus: ConnectionStatus;
  metrics: LiveTickMetrics;
  deviceBattery?: Record<string, number>;
  // Additive (Phase 11 Section 3/4) — mirrors deviceBattery's shape
  // exactly. Optional because no current transport reports RSSI; the
  // field exists so a future one can without a contract change.
  deviceRssi?: Record<string, number>;
  // Additive (Phase 11 Section 3) — laptop-reported capture phase, only
  // meaningful while the session's own status is "live". Not required:
  // a laptop pipeline that doesn't track this finer state simply omits it.
  capturePhase?: SessionCapturePhase;
}

function parseLiveTickMetrics(data: unknown): LiveTickMetrics {
  const metrics = requireObject(data, "metrics");
  requireExactShape(metrics, [
    "currentLoad", "cumulativeImpacts", "riskScore", "riskLevel", "emgActivation",
    "confidence", "fatigueScore", "fatigueLevel", "workloadRatio", "workloadStatus",
    "asymmetryScore", "asymmetryStatus", "muscleBalanceScore", "muscleBalanceStatus",
  ]);
  return {
    currentLoad: requireNumberInRange(metrics, "currentLoad", 0, Infinity),
    cumulativeImpacts: requireNumberInRange(metrics, "cumulativeImpacts", 0, Infinity),
    // §21.4: documented 0.0-1.0.
    riskScore: requireNumberInRange(metrics, "riskScore", 0, 1),
    riskLevel: requireEnum(metrics, "riskLevel", RISK_LEVELS),
    emgActivation: optionalNumberInRange(metrics, "emgActivation", 0, Infinity),
    confidence: optionalNumberInRange(metrics, "confidence", 0, 1),
    fatigueScore: optionalNumberInRange(metrics, "fatigueScore", 0, Infinity),
    fatigueLevel: optionalBoundedString(metrics, "fatigueLevel", MAX_SHORT_TEXT_LENGTH),
    workloadRatio: optionalNumberInRange(metrics, "workloadRatio", 0, Infinity),
    workloadStatus: optionalBoundedString(metrics, "workloadStatus", MAX_SHORT_TEXT_LENGTH),
    asymmetryScore: optionalNumberInRange(metrics, "asymmetryScore", 0, Infinity),
    asymmetryStatus: optionalBoundedString(metrics, "asymmetryStatus", MAX_SHORT_TEXT_LENGTH),
    muscleBalanceScore: optionalNumberInRange(metrics, "muscleBalanceScore", 0, Infinity),
    muscleBalanceStatus: optionalBoundedString(metrics, "muscleBalanceStatus", MAX_SHORT_TEXT_LENGTH),
  };
}

function parseDeviceNumberMap(
  data: unknown,
  field: string,
  min: number,
  max: number
): Record<string, number> | undefined {
  const raw = optionalObject(data, field);
  if (!raw) return undefined;
  const parsed: Record<string, number> = {};
  for (const [deviceId, value] of Object.entries(raw)) {
    if (typeof value !== "number" || Number.isNaN(value)) {
      fail(`"${field}.${deviceId}" must be a number.`);
    }
    if ((value as number) < min || (value as number) > max) {
      fail(`"${field}.${deviceId}" must be between ${min} and ${max}. Received ${value}.`);
    }
    parsed[deviceId] = value as number;
  }
  return parsed;
}

export function parseIngestLiveTickPayload(data: unknown): IngestLiveTickPayload {
  requireExactShape(data, [
    "sessionId", "playerId", "teamId", "sequenceNumber", "tickTimestamp",
    "connectionStatus", "metrics", "deviceBattery", "deviceRssi", "capturePhase",
  ]);
  const record = data as Record<string, unknown>;
  return {
    sessionId: requireString(record, "sessionId"),
    playerId: requireString(record, "playerId"),
    teamId: optionalString(record, "teamId"),
    sequenceNumber: requireNumberInRange(record, "sequenceNumber", 0, Infinity),
    tickTimestamp: requireIsoTimestamp(record, "tickTimestamp"),
    connectionStatus: requireEnum(record, "connectionStatus", CONNECTION_STATUSES),
    metrics: parseLiveTickMetrics(record),
    deviceBattery: parseDeviceNumberMap(record, "deviceBattery", 0, 100),
    // RSSI is in dBm — a bounded but not standardized range; -120 to 0
    // comfortably covers real BLE hardware without accepting nonsense.
    deviceRssi: parseDeviceNumberMap(record, "deviceRssi", -120, 0),
    capturePhase:
      record["capturePhase"] != null
        ? requireEnum(record, "capturePhase", SESSION_CAPTURE_PHASES)
        : undefined,
  };
}

// ---------------------------------------------------------------------------
// completeSession — BACKEND_SPECIFICATION.md §21.5 / §9
// ---------------------------------------------------------------------------

export interface SummaryMetrics {
  totalImpacts: number;
  peakImpactForce: number;
  averageLoad: number;
  cumulativeLoadIndex: number;
  muscleFatigueIndex?: number;
  overallRiskScore: number;
  riskLevel: RiskLevel;
  riskFactors: string[];
}

export interface CompleteSessionPayload {
  sessionId: string;
  endedAt: Date;
  durationSeconds: number;
  status: SessionStatus;
  summaryMetrics: SummaryMetrics;
  dataCompleteness: number;
  pipelineVersion: string;
  rawDataStoragePath?: string;
}

function parseSummaryMetrics(data: unknown): SummaryMetrics {
  requireExactShape(data, [
    "totalImpacts", "peakImpactForce", "averageLoad", "cumulativeLoadIndex",
    "muscleFatigueIndex", "overallRiskScore", "riskLevel", "riskFactors",
  ]);
  const record = data as Record<string, unknown>;
  const riskFactorsRaw = record?.["riskFactors"];
  if (
    !Array.isArray(riskFactorsRaw) ||
    riskFactorsRaw.length > 50 ||
    !riskFactorsRaw.every((v) => typeof v === "string" && v.length <= MAX_SHORT_TEXT_LENGTH)
  ) {
    fail('"summaryMetrics.riskFactors" is required and must be an array of at most 50 short strings.');
  }
  return {
    totalImpacts: requireNumberInRange(data, "totalImpacts", 0, Infinity),
    peakImpactForce: requireNumberInRange(data, "peakImpactForce", 0, Infinity),
    averageLoad: requireNumberInRange(data, "averageLoad", 0, Infinity),
    cumulativeLoadIndex: requireNumberInRange(data, "cumulativeLoadIndex", 0, Infinity),
    muscleFatigueIndex: optionalNumberInRange(data, "muscleFatigueIndex", 0, Infinity),
    // §9: documented 0.0-1.0, same convention as ingestLiveTick's riskScore.
    overallRiskScore: requireNumberInRange(data, "overallRiskScore", 0, 1),
    riskLevel: requireEnum(data, "riskLevel", RISK_LEVELS),
    riskFactors: riskFactorsRaw as string[],
  };
}

export function parseCompleteSessionPayload(data: unknown): CompleteSessionPayload {
  requireExactShape(data, [
    "sessionId", "endedAt", "durationSeconds", "status", "summaryMetrics",
    "dataCompleteness", "pipelineVersion", "rawDataStoragePath",
  ]);
  return {
    sessionId: requireString(data, "sessionId"),
    endedAt: requireIsoTimestamp(data, "endedAt"),
    durationSeconds: requireNumberInRange(data, "durationSeconds", 0, Infinity),
    status: requireEnum(data, "status", SESSION_STATUSES),
    summaryMetrics: parseSummaryMetrics(requireObject(data, "summaryMetrics")),
    // §9: documented 0.0-1.0 fraction of expected ticks received.
    dataCompleteness: requireNumberInRange(data, "dataCompleteness", 0, 1),
    pipelineVersion: requireBoundedString(data, "pipelineVersion", MAX_SHORT_TEXT_LENGTH),
    rawDataStoragePath: optionalBoundedString(data, "rawDataStoragePath", MAX_TEXT_LENGTH),
  };
}

// ---------------------------------------------------------------------------
// submitAlert — BACKEND_SPECIFICATION.md §21.6
//
// `contributingFactors`/`recommendations`/`confidence`/`policyVersion`/
// `modelVersion`/`assessmentId`/`assessmentChecksum` are additive optional
// fields carrying vikzar-ai's ACLRiskEngine provenance/explanation output —
// same cross-repo alignment as ingestLiveTick above.
// ---------------------------------------------------------------------------

export interface ContributingFactor {
  component: string;
  score: number;
  weight: number;
  contribution: number;
}

export interface Recommendation {
  code: string;
  priority: string;
  message: string;
}

export interface SubmitAlertPayload {
  sessionId: string;
  playerId: string;
  teamId?: string;
  severity: AlertSeverity;
  type: AlertType;
  message: string;
  triggeredAt: Date;
  metricsSnapshot?: Record<string, unknown>;
  contributingFactors?: ContributingFactor[];
  recommendations?: Recommendation[];
  confidence?: number;
  policyVersion?: string;
  modelVersion?: string;
  assessmentId?: string;
  assessmentChecksum?: string;
}

const MAX_LIST_LENGTH = 50;

function parseContributingFactors(data: unknown): ContributingFactor[] | undefined {
  const record = data as Record<string, unknown>;
  const raw = record?.["contributingFactors"];
  if (raw == null) return undefined;
  if (!Array.isArray(raw) || raw.length > MAX_LIST_LENGTH) {
    fail(`"contributingFactors", if present, must be an array of at most ${MAX_LIST_LENGTH} entries.`);
  }
  return (raw as unknown[]).map((entry) => {
    requireExactShape(entry, ["component", "score", "weight", "contribution"]);
    return {
      // Not normalized to 0-1 — §21.6's own examples use raw scores like
      // 41 and contributions like 12.3 — so only non-negativity is a
      // safe, documented bound here (not inventing an unconfirmed range).
      component: requireBoundedString(entry, "component", MAX_SHORT_TEXT_LENGTH),
      score: requireNumberInRange(entry, "score", 0, Infinity),
      weight: requireNumberInRange(entry, "weight", 0, Infinity),
      contribution: requireNumberInRange(entry, "contribution", 0, Infinity),
    };
  });
}

function parseRecommendations(data: unknown): Recommendation[] | undefined {
  const record = data as Record<string, unknown>;
  const raw = record?.["recommendations"];
  if (raw == null) return undefined;
  if (!Array.isArray(raw) || raw.length > MAX_LIST_LENGTH) {
    fail(`"recommendations", if present, must be an array of at most ${MAX_LIST_LENGTH} entries.`);
  }
  return (raw as unknown[]).map((entry) => {
    requireExactShape(entry, ["code", "priority", "message"]);
    return {
      code: requireBoundedString(entry, "code", MAX_SHORT_TEXT_LENGTH),
      priority: requireBoundedString(entry, "priority", MAX_SHORT_TEXT_LENGTH),
      message: requireBoundedString(entry, "message", MAX_TEXT_LENGTH),
    };
  });
}

export function parseSubmitAlertPayload(data: unknown): SubmitAlertPayload {
  requireExactShape(data, [
    "sessionId", "playerId", "teamId", "severity", "type", "message", "triggeredAt",
    "metricsSnapshot", "contributingFactors", "recommendations", "confidence",
    "policyVersion", "modelVersion", "assessmentId", "assessmentChecksum",
  ]);
  return {
    sessionId: requireString(data, "sessionId"),
    playerId: requireString(data, "playerId"),
    teamId: optionalString(data, "teamId"),
    severity: requireEnum(data, "severity", ALERT_SEVERITIES),
    type: requireEnum(data, "type", ALERT_TYPES),
    message: requireBoundedString(data, "message", MAX_TEXT_LENGTH),
    triggeredAt: requireIsoTimestamp(data, "triggeredAt"),
    metricsSnapshot: optionalObject(data, "metricsSnapshot"),
    contributingFactors: parseContributingFactors(data),
    recommendations: parseRecommendations(data),
    confidence: optionalNumberInRange(data, "confidence", 0, 1),
    policyVersion: optionalBoundedString(data, "policyVersion", MAX_SHORT_TEXT_LENGTH),
    modelVersion: optionalBoundedString(data, "modelVersion", MAX_SHORT_TEXT_LENGTH),
    assessmentId: optionalBoundedString(data, "assessmentId", MAX_SHORT_TEXT_LENGTH),
    assessmentChecksum: optionalBoundedString(data, "assessmentChecksum", MAX_SHORT_TEXT_LENGTH),
  };
}

// ---------------------------------------------------------------------------
// submitReport — BACKEND_SPECIFICATION.md §21.7
// ---------------------------------------------------------------------------

export interface SubmitReportPayload {
  sessionId: string;
  playerId: string;
  teamId?: string;
  generatedAt: Date;
  summary: Record<string, unknown>;
  storagePath?: string;
}

// ---------------------------------------------------------------------------
// createPlannedSession — Phase 13 §5. Coach-callable (real Firebase Auth
// end user, authorized via lib/coachAuth.ts's Firestore lookup — NOT the
// laptop ingestion principal, and never a client-claimed role/teamId).
// ---------------------------------------------------------------------------

export interface CreatePlannedSessionPayload {
  teamId: string;
  title: string;
  type: SessionType;
  scheduledAt: Date;
  notes?: string;
}

export function parseCreatePlannedSessionPayload(data: unknown): CreatePlannedSessionPayload {
  requireExactShape(data, ["teamId", "title", "type", "scheduledAt", "notes"]);
  return {
    teamId: requireString(data, "teamId"),
    title: requireBoundedString(data, "title", MAX_SHORT_TEXT_LENGTH),
    type: requireEnum(data, "type", SESSION_TYPES),
    scheduledAt: requireIsoTimestamp(data, "scheduledAt"),
    notes: optionalBoundedString(data, "notes", MAX_TEXT_LENGTH),
  };
}

export function parseSubmitReportPayload(data: unknown): SubmitReportPayload {
  requireExactShape(data, [
    "sessionId", "playerId", "teamId", "generatedAt", "summary", "storagePath",
  ]);
  return {
    sessionId: requireString(data, "sessionId"),
    playerId: requireString(data, "playerId"),
    teamId: optionalString(data, "teamId"),
    generatedAt: requireIsoTimestamp(data, "generatedAt"),
    summary: requireObject(data, "summary"),
    storagePath: optionalBoundedString(data, "storagePath", MAX_TEXT_LENGTH),
  };
}
