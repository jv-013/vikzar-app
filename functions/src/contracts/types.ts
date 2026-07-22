import {
  requireEnum,
  requireIsoTimestamp,
  requireNumber,
  requireObject,
  requireString,
  requireStringArray,
  optionalNumber,
  optionalObject,
  optionalString,
  fail,
} from "../lib/validation";

export const RISK_LEVELS = ["low", "moderate", "high", "critical"] as const;
export type RiskLevel = (typeof RISK_LEVELS)[number];

export const CONNECTION_STATUSES = ["connected", "degraded", "reconnecting"] as const;
export type ConnectionStatus = (typeof CONNECTION_STATUSES)[number];

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
}

function parseLiveTickMetrics(data: unknown): LiveTickMetrics {
  const metrics = requireObject(data, "metrics");
  return {
    currentLoad: requireNumber(metrics, "currentLoad"),
    cumulativeImpacts: requireNumber(metrics, "cumulativeImpacts"),
    riskScore: requireNumber(metrics, "riskScore"),
    riskLevel: requireEnum(metrics, "riskLevel", RISK_LEVELS),
    emgActivation: optionalNumber(metrics, "emgActivation"),
    confidence: optionalNumber(metrics, "confidence"),
    fatigueScore: optionalNumber(metrics, "fatigueScore"),
    fatigueLevel: optionalString(metrics, "fatigueLevel"),
    workloadRatio: optionalNumber(metrics, "workloadRatio"),
    workloadStatus: optionalString(metrics, "workloadStatus"),
    asymmetryScore: optionalNumber(metrics, "asymmetryScore"),
    asymmetryStatus: optionalString(metrics, "asymmetryStatus"),
    muscleBalanceScore: optionalNumber(metrics, "muscleBalanceScore"),
    muscleBalanceStatus: optionalString(metrics, "muscleBalanceStatus"),
  };
}

export function parseIngestLiveTickPayload(data: unknown): IngestLiveTickPayload {
  const record = data as Record<string, unknown>;
  const deviceBatteryRaw = optionalObject(data, "deviceBattery");
  let deviceBattery: Record<string, number> | undefined;
  if (deviceBatteryRaw) {
    deviceBattery = {};
    for (const [deviceId, value] of Object.entries(deviceBatteryRaw)) {
      if (typeof value !== "number") {
        fail(`"deviceBattery.${deviceId}" must be a number.`);
      }
      deviceBattery[deviceId] = value as number;
    }
  }
  return {
    sessionId: requireString(record, "sessionId"),
    playerId: requireString(record, "playerId"),
    teamId: optionalString(record, "teamId"),
    sequenceNumber: requireNumber(record, "sequenceNumber"),
    tickTimestamp: requireIsoTimestamp(record, "tickTimestamp"),
    connectionStatus: requireEnum(record, "connectionStatus", CONNECTION_STATUSES),
    metrics: parseLiveTickMetrics(record),
    deviceBattery,
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
  const record = data as Record<string, unknown>;
  const riskFactorsRaw = record?.["riskFactors"];
  if (!Array.isArray(riskFactorsRaw) || !riskFactorsRaw.every((v) => typeof v === "string")) {
    fail('"summaryMetrics.riskFactors" is required and must be an array of strings.');
  }
  return {
    totalImpacts: requireNumber(data, "totalImpacts"),
    peakImpactForce: requireNumber(data, "peakImpactForce"),
    averageLoad: requireNumber(data, "averageLoad"),
    cumulativeLoadIndex: requireNumber(data, "cumulativeLoadIndex"),
    muscleFatigueIndex: optionalNumber(data, "muscleFatigueIndex"),
    overallRiskScore: requireNumber(data, "overallRiskScore"),
    riskLevel: requireEnum(data, "riskLevel", RISK_LEVELS),
    riskFactors: riskFactorsRaw as string[],
  };
}

export function parseCompleteSessionPayload(data: unknown): CompleteSessionPayload {
  return {
    sessionId: requireString(data, "sessionId"),
    endedAt: requireIsoTimestamp(data, "endedAt"),
    durationSeconds: requireNumber(data, "durationSeconds"),
    status: requireEnum(data, "status", SESSION_STATUSES),
    summaryMetrics: parseSummaryMetrics(requireObject(data, "summaryMetrics")),
    dataCompleteness: requireNumber(data, "dataCompleteness"),
    pipelineVersion: requireString(data, "pipelineVersion"),
    rawDataStoragePath: optionalString(data, "rawDataStoragePath"),
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

function parseContributingFactors(data: unknown): ContributingFactor[] | undefined {
  const record = data as Record<string, unknown>;
  const raw = record?.["contributingFactors"];
  if (raw == null) return undefined;
  if (!Array.isArray(raw)) fail('"contributingFactors", if present, must be an array.');
  return (raw as unknown[]).map((entry) => ({
    component: requireString(entry, "component"),
    score: requireNumber(entry, "score"),
    weight: requireNumber(entry, "weight"),
    contribution: requireNumber(entry, "contribution"),
  }));
}

function parseRecommendations(data: unknown): Recommendation[] | undefined {
  const record = data as Record<string, unknown>;
  const raw = record?.["recommendations"];
  if (raw == null) return undefined;
  if (!Array.isArray(raw)) fail('"recommendations", if present, must be an array.');
  return (raw as unknown[]).map((entry) => ({
    code: requireString(entry, "code"),
    priority: requireString(entry, "priority"),
    message: requireString(entry, "message"),
  }));
}

export function parseSubmitAlertPayload(data: unknown): SubmitAlertPayload {
  return {
    sessionId: requireString(data, "sessionId"),
    playerId: requireString(data, "playerId"),
    teamId: optionalString(data, "teamId"),
    severity: requireEnum(data, "severity", ALERT_SEVERITIES),
    type: requireEnum(data, "type", ALERT_TYPES),
    message: requireString(data, "message"),
    triggeredAt: requireIsoTimestamp(data, "triggeredAt"),
    metricsSnapshot: optionalObject(data, "metricsSnapshot"),
    contributingFactors: parseContributingFactors(data),
    recommendations: parseRecommendations(data),
    confidence: optionalNumber(data, "confidence"),
    policyVersion: optionalString(data, "policyVersion"),
    modelVersion: optionalString(data, "modelVersion"),
    assessmentId: optionalString(data, "assessmentId"),
    assessmentChecksum: optionalString(data, "assessmentChecksum"),
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

export function parseSubmitReportPayload(data: unknown): SubmitReportPayload {
  return {
    sessionId: requireString(data, "sessionId"),
    playerId: requireString(data, "playerId"),
    teamId: optionalString(data, "teamId"),
    generatedAt: requireIsoTimestamp(data, "generatedAt"),
    summary: requireObject(data, "summary"),
    storagePath: optionalString(data, "storagePath"),
  };
}
