import { HttpsError } from "firebase-functions/v2/https";
import {
  parseStartSessionPayload,
  parseIngestLiveTickPayload,
  parseCompleteSessionPayload,
  parseSubmitAlertPayload,
  parseSubmitReportPayload,
  parseCreatePlannedSessionPayload,
  parseRazAskPayload,
  parseRazDailyBriefPayload,
} from "../../src/contracts/types";

// Example payloads mirror BACKEND_SPECIFICATION.md §21's own JSON examples exactly.

describe("parseStartSessionPayload", () => {
  const valid = {
    sessionId: "a3f1c9de-4b2e-4f11-9c7a-1d6e2f0b8a44",
    playerId: "hU3kP9mZ2LQvT8xR1nY6wA0bC7dE",
    teamId: "team_riverside_u18",
    orgId: "org_riverside_fc",
    type: "training",
    deviceIds: ["SP-7F3A21C9", "EB-4B1109F2"],
    startedAt: "2026-07-19T14:30:00.000Z",
  };

  it("parses the exact §21.3 example payload", () => {
    const result = parseStartSessionPayload(valid);
    expect(result.sessionId).toBe(valid.sessionId);
    expect(result.deviceIds).toEqual(valid.deviceIds);
    expect(result.startedAt.toISOString()).toBe("2026-07-19T14:30:00.000Z");
  });

  it("allows omitting teamId/orgId for an individual session", () => {
    const { teamId, orgId, ...individual } = valid;
    void teamId;
    void orgId;
    const result = parseStartSessionPayload(individual);
    expect(result.teamId).toBeUndefined();
    expect(result.orgId).toBeUndefined();
  });

  it("rejects an invalid type", () => {
    expect(() => parseStartSessionPayload({ ...valid, type: "scrimmage" })).toThrow(HttpsError);
  });

  it("rejects an empty deviceIds array", () => {
    expect(() => parseStartSessionPayload({ ...valid, deviceIds: [] })).toThrow(HttpsError);
  });

  it("rejects an unknown top-level field (Phase 13 §8)", () => {
    expect(() => parseStartSessionPayload({ ...valid, evilField: "x" })).toThrow(HttpsError);
  });

  it("rejects a missing sessionId", () => {
    const { sessionId, ...rest } = valid;
    void sessionId;
    expect(() => parseStartSessionPayload(rest)).toThrow(HttpsError);
  });
});

describe("parseIngestLiveTickPayload", () => {
  const valid = {
    sessionId: "a3f1c9de-4b2e-4f11-9c7a-1d6e2f0b8a44",
    playerId: "hU3kP9mZ2LQvT8xR1nY6wA0bC7dE",
    teamId: "team_riverside_u18",
    sequenceNumber: 412,
    tickTimestamp: "2026-07-19T14:36:52.108Z",
    connectionStatus: "connected",
    metrics: {
      currentLoad: 47.2,
      cumulativeImpacts: 63,
      riskScore: 0.18,
      riskLevel: "low",
      emgActivation: 34.6,
    },
    deviceBattery: { "SP-7F3A21C9": 81, "EB-4B1109F2": 74 },
  };

  it("parses the exact §21.4 example payload", () => {
    const result = parseIngestLiveTickPayload(valid);
    expect(result.sequenceNumber).toBe(412);
    expect(result.metrics.riskLevel).toBe("low");
    expect(result.deviceBattery).toEqual(valid.deviceBattery);
  });

  it("allows omitting optional metrics fields", () => {
    const { emgActivation, ...requiredMetrics } = valid.metrics;
    void emgActivation;
    const result = parseIngestLiveTickPayload({ ...valid, metrics: requiredMetrics });
    expect(result.metrics.emgActivation).toBeUndefined();
  });

  it("accepts the additive risk-engine sub-score fields", () => {
    const result = parseIngestLiveTickPayload({
      ...valid,
      metrics: {
        ...valid.metrics,
        confidence: 0.82,
        fatigueScore: 41.0,
        fatigueLevel: "moderate",
        workloadRatio: 1.2,
        workloadStatus: "elevated",
        asymmetryScore: 12.5,
        asymmetryStatus: "normal",
        muscleBalanceScore: 88.0,
        muscleBalanceStatus: "balanced",
      },
    });
    expect(result.metrics.confidence).toBe(0.82);
    expect(result.metrics.fatigueLevel).toBe("moderate");
    expect(result.metrics.muscleBalanceStatus).toBe("balanced");
  });

  it("rejects a missing required metrics field", () => {
    const { riskScore, ...rest } = valid.metrics;
    void riskScore;
    expect(() => parseIngestLiveTickPayload({ ...valid, metrics: rest })).toThrow(HttpsError);
  });

  it("rejects an invalid connectionStatus", () => {
    expect(() =>
      parseIngestLiveTickPayload({ ...valid, connectionStatus: "connecting" })
    ).toThrow(HttpsError);
  });

  it("rejects a non-numeric deviceBattery value", () => {
    expect(() =>
      parseIngestLiveTickPayload({ ...valid, deviceBattery: { "SP-1": "full" } })
    ).toThrow(HttpsError);
  });

  it("accepts the additive deviceRssi and capturePhase fields", () => {
    const result = parseIngestLiveTickPayload({
      ...valid,
      deviceRssi: { "SP-7F3A21C9": -58 },
      capturePhase: "recording",
    });
    expect(result.deviceRssi).toEqual({ "SP-7F3A21C9": -58 });
    expect(result.capturePhase).toBe("recording");
  });

  it("omits deviceRssi and capturePhase when absent", () => {
    const result = parseIngestLiveTickPayload(valid);
    expect(result.deviceRssi).toBeUndefined();
    expect(result.capturePhase).toBeUndefined();
  });

  it("rejects a non-numeric deviceRssi value", () => {
    expect(() =>
      parseIngestLiveTickPayload({ ...valid, deviceRssi: { "SP-1": "strong" } })
    ).toThrow(HttpsError);
  });

  it("rejects an invalid capturePhase", () => {
    expect(() =>
      parseIngestLiveTickPayload({ ...valid, capturePhase: "preparing" })
    ).toThrow(HttpsError);
  });

  it("rejects an unknown top-level field (Phase 13 §8)", () => {
    expect(() => parseIngestLiveTickPayload({ ...valid, evilField: "x" })).toThrow(HttpsError);
  });

  it("rejects a riskScore outside 0-1 (Phase 13 §8)", () => {
    expect(() =>
      parseIngestLiveTickPayload({ ...valid, metrics: { ...valid.metrics, riskScore: 1.5 } })
    ).toThrow(HttpsError);
    expect(() =>
      parseIngestLiveTickPayload({ ...valid, metrics: { ...valid.metrics, riskScore: -0.1 } })
    ).toThrow(HttpsError);
  });

  it("rejects a negative currentLoad (Phase 13 §8)", () => {
    expect(() =>
      parseIngestLiveTickPayload({ ...valid, metrics: { ...valid.metrics, currentLoad: -1 } })
    ).toThrow(HttpsError);
  });

  it("rejects a deviceBattery value outside 0-100 (Phase 13 §8)", () => {
    expect(() =>
      parseIngestLiveTickPayload({ ...valid, deviceBattery: { "SP-1": 101 } })
    ).toThrow(HttpsError);
    expect(() =>
      parseIngestLiveTickPayload({ ...valid, deviceBattery: { "SP-1": -1 } })
    ).toThrow(HttpsError);
  });

  it("rejects a deviceRssi value outside -120..0 dBm (Phase 13 §8)", () => {
    expect(() =>
      parseIngestLiveTickPayload({ ...valid, deviceRssi: { "SP-1": 5 } })
    ).toThrow(HttpsError);
  });
});

describe("parseCompleteSessionPayload", () => {
  const valid = {
    sessionId: "a3f1c9de-4b2e-4f11-9c7a-1d6e2f0b8a44",
    endedAt: "2026-07-19T16:02:11.900Z",
    durationSeconds: 5531,
    status: "completed",
    dataCompleteness: 0.997,
    pipelineVersion: "etl-2.3.1+ml-1.7.0+risk-1.2.0",
    rawDataStoragePath: "organizations/org_riverside_fc/.../capture.bin",
    summaryMetrics: {
      totalImpacts: 288,
      peakImpactForce: 62.4,
      averageLoad: 41.9,
      cumulativeLoadIndex: 2317.6,
      muscleFatigueIndex: 58.3,
      overallRiskScore: 0.24,
      riskLevel: "low",
      riskFactors: [],
    },
  };

  it("parses the exact §21.5 example payload", () => {
    const result = parseCompleteSessionPayload(valid);
    expect(result.status).toBe("completed");
    expect(result.summaryMetrics.totalImpacts).toBe(288);
    expect(result.summaryMetrics.riskFactors).toEqual([]);
  });

  it("allows omitting muscleFatigueIndex (no EMG band worn)", () => {
    const { muscleFatigueIndex, ...rest } = valid.summaryMetrics;
    void muscleFatigueIndex;
    const result = parseCompleteSessionPayload({ ...valid, summaryMetrics: rest });
    expect(result.summaryMetrics.muscleFatigueIndex).toBeUndefined();
  });

  it("rejects an invalid status", () => {
    expect(() => parseCompleteSessionPayload({ ...valid, status: "live" })).toThrow(HttpsError);
  });

  it("rejects a non-array riskFactors", () => {
    expect(() =>
      parseCompleteSessionPayload({
        ...valid,
        summaryMetrics: { ...valid.summaryMetrics, riskFactors: "none" },
      })
    ).toThrow(HttpsError);
  });

  it("rejects a dataCompleteness outside 0-1 (Phase 13 §8)", () => {
    expect(() => parseCompleteSessionPayload({ ...valid, dataCompleteness: 1.5 })).toThrow(
      HttpsError
    );
  });

  it("rejects an overallRiskScore outside 0-1 (Phase 13 §8)", () => {
    expect(() =>
      parseCompleteSessionPayload({
        ...valid,
        summaryMetrics: { ...valid.summaryMetrics, overallRiskScore: 2 },
      })
    ).toThrow(HttpsError);
  });

  it("rejects an unknown top-level field (Phase 13 §8)", () => {
    expect(() => parseCompleteSessionPayload({ ...valid, evilField: "x" })).toThrow(HttpsError);
  });
});

describe("parseSubmitAlertPayload", () => {
  const valid = {
    sessionId: "a3f1c9de-4b2e-4f11-9c7a-1d6e2f0b8a44",
    playerId: "hU3kP9mZ2LQvT8xR1nY6wA0bC7dE",
    teamId: "team_riverside_u18",
    severity: "warning",
    type: "high_impact",
    message: "A high-magnitude impact was recorded.",
    triggeredAt: "2026-07-19T15:12:44.331Z",
    metricsSnapshot: { impactForce: 58.9, riskScoreAtEvent: 0.41 },
  };

  it("parses the exact §21.6 example payload", () => {
    const result = parseSubmitAlertPayload(valid);
    expect(result.severity).toBe("warning");
    expect(result.metricsSnapshot).toEqual(valid.metricsSnapshot);
  });

  it("accepts the additive risk-engine provenance fields", () => {
    const result = parseSubmitAlertPayload({
      ...valid,
      contributingFactors: [{ component: "fatigue", score: 41, weight: 0.3, contribution: 12.3 }],
      recommendations: [{ code: "rest", priority: "high", message: "Consider a rest day." }],
      confidence: 0.75,
      policyVersion: "risk-policy-1.0.0",
      modelVersion: "production.deterministic_mlp_regressor-2026.07.19",
      assessmentId: "assess_1",
      assessmentChecksum: "abc123",
    });
    expect(result.contributingFactors).toHaveLength(1);
    expect(result.recommendations?.[0]?.code).toBe("rest");
    expect(result.confidence).toBe(0.75);
  });

  it("rejects an invalid severity", () => {
    expect(() => parseSubmitAlertPayload({ ...valid, severity: "danger" })).toThrow(HttpsError);
  });

  it("rejects an invalid type", () => {
    expect(() => parseSubmitAlertPayload({ ...valid, type: "unknown_event" })).toThrow(HttpsError);
  });

  it("rejects a malformed contributingFactors entry", () => {
    expect(() =>
      parseSubmitAlertPayload({ ...valid, contributingFactors: [{ component: "fatigue" }] })
    ).toThrow(HttpsError);
  });
});

describe("parseSubmitReportPayload", () => {
  const valid = {
    sessionId: "a3f1c9de-4b2e-4f11-9c7a-1d6e2f0b8a44",
    playerId: "hU3kP9mZ2LQvT8xR1nY6wA0bC7dE",
    teamId: "team_riverside_u18",
    generatedAt: "2026-07-19T16:03:05.000Z",
    summary: {
      overallRiskScore: 0.24,
      riskLevel: "low",
      totalImpacts: 288,
      notableFindings: [],
    },
  };

  it("parses the exact §21.7 example payload", () => {
    const result = parseSubmitReportPayload(valid);
    expect(result.summary["overallRiskScore"]).toBe(0.24);
  });

  it("rejects a missing summary", () => {
    const { summary, ...rest } = valid;
    void summary;
    expect(() => parseSubmitReportPayload(rest)).toThrow(HttpsError);
  });
});

describe("parseCreatePlannedSessionPayload", () => {
  const valid = {
    teamId: "team_riverside_u18",
    title: "Tuesday Training",
    type: "training",
    scheduledAt: "2026-07-28T16:00:00.000Z",
  };

  it("parses a valid payload", () => {
    const result = parseCreatePlannedSessionPayload(valid);
    expect(result.teamId).toBe(valid.teamId);
    expect(result.title).toBe(valid.title);
    expect(result.type).toBe("training");
    expect(result.scheduledAt.toISOString()).toBe(valid.scheduledAt);
    expect(result.notes).toBeUndefined();
  });

  it("accepts an optional notes field", () => {
    const result = parseCreatePlannedSessionPayload({ ...valid, notes: "Bring cones." });
    expect(result.notes).toBe("Bring cones.");
  });

  it("rejects an invalid type", () => {
    expect(() => parseCreatePlannedSessionPayload({ ...valid, type: "scrimmage" })).toThrow(
      HttpsError
    );
  });

  it("rejects a missing teamId", () => {
    const { teamId, ...rest } = valid;
    void teamId;
    expect(() => parseCreatePlannedSessionPayload(rest)).toThrow(HttpsError);
  });

  it("rejects an unknown top-level field (Phase 13 §8)", () => {
    expect(() => parseCreatePlannedSessionPayload({ ...valid, evilField: "x" })).toThrow(
      HttpsError
    );
  });
});

// RAZ, Vikzar's Football Operating System.

describe("parseRazAskPayload", () => {
  const valid = { audience: "player", question: "How did I train today?", history: [] };

  it("parses a minimal valid payload with no history", () => {
    const result = parseRazAskPayload({ audience: "player", question: "How did I train today?" });
    expect(result.audience).toBe("player");
    expect(result.question).toBe("How did I train today?");
    expect(result.history).toEqual([]);
  });

  it("parses history turns", () => {
    const result = parseRazAskPayload({
      ...valid,
      history: [{ question: "How did I train today?", answer: "Solid session." }],
    });
    expect(result.history).toHaveLength(1);
    expect(result.history[0]?.answer).toBe("Solid session.");
  });

  it("rejects an invalid audience", () => {
    expect(() => parseRazAskPayload({ ...valid, audience: "admin" })).toThrow(HttpsError);
  });

  it("rejects an empty question", () => {
    expect(() => parseRazAskPayload({ ...valid, question: "" })).toThrow(HttpsError);
  });

  it("rejects more than 10 history turns", () => {
    const history = Array.from({ length: 11 }, () => ({ question: "q", answer: "a" }));
    expect(() => parseRazAskPayload({ ...valid, history })).toThrow(HttpsError);
  });

  it("rejects a history turn with an unknown field", () => {
    const history = [{ question: "q", answer: "a", evilField: "x" }];
    expect(() => parseRazAskPayload({ ...valid, history })).toThrow(HttpsError);
  });

  it("rejects an unknown top-level field", () => {
    expect(() => parseRazAskPayload({ ...valid, evilField: "x" })).toThrow(HttpsError);
  });
});

describe("parseRazDailyBriefPayload", () => {
  it("parses a valid payload", () => {
    expect(parseRazDailyBriefPayload({ audience: "coach" }).audience).toBe("coach");
  });

  it("rejects an invalid audience", () => {
    expect(() => parseRazDailyBriefPayload({ audience: "referee" })).toThrow(HttpsError);
  });

  it("rejects an unknown top-level field", () => {
    expect(() => parseRazDailyBriefPayload({ audience: "player", evilField: "x" })).toThrow(
      HttpsError
    );
  });
});
