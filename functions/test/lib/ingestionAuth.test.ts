import { HttpsError, CallableRequest } from "firebase-functions/v2/https";
import {
  requireIngestionPrincipal,
  requireTeamInScope,
  requireOrgInScope,
} from "../../src/lib/ingestionAuth";

function callableRequest(token: Record<string, unknown> | undefined): CallableRequest<unknown> {
  return {
    data: undefined,
    auth: token ? { uid: "ingestor-1", token: token as never } : undefined,
    rawRequest: {} as never,
  } as unknown as CallableRequest<unknown>;
}

describe("requireIngestionPrincipal", () => {
  it("returns claims for a valid ingestion principal", () => {
    const claims = requireIngestionPrincipal(
      callableRequest({ ingestor: true, orgId: "org_1", teamIds: ["team_1", "team_2"] })
    );
    expect(claims).toEqual({ ingestor: true, orgId: "org_1", teamIds: ["team_1", "team_2"] });
  });

  it("throws unauthenticated when there is no auth context", () => {
    expect(() => requireIngestionPrincipal(callableRequest(undefined))).toThrow(HttpsError);
  });

  it("throws permission-denied when ingestor claim is not true", () => {
    expect(() =>
      requireIngestionPrincipal(callableRequest({ ingestor: false, orgId: "o", teamIds: [] }))
    ).toThrow(HttpsError);
  });

  it("throws permission-denied when orgId is missing", () => {
    expect(() =>
      requireIngestionPrincipal(callableRequest({ ingestor: true, teamIds: [] }))
    ).toThrow(HttpsError);
  });

  it("throws permission-denied when teamIds is missing", () => {
    expect(() =>
      requireIngestionPrincipal(callableRequest({ ingestor: true, orgId: "o" }))
    ).toThrow(HttpsError);
  });

  it("throws permission-denied when a human user token is presented (no ingestor claim at all)", () => {
    expect(() => requireIngestionPrincipal(callableRequest({}))).toThrow(HttpsError);
  });
});

describe("requireTeamInScope", () => {
  const claims = { ingestor: true as const, orgId: "org_1", teamIds: ["team_1"] };

  it("allows a team within scope", () => {
    expect(() => requireTeamInScope(claims, "team_1")).not.toThrow();
  });

  it("allows null (individual session, no team)", () => {
    expect(() => requireTeamInScope(claims, null)).not.toThrow();
    expect(() => requireTeamInScope(claims, undefined)).not.toThrow();
  });

  it("rejects a team outside scope", () => {
    expect(() => requireTeamInScope(claims, "team_9")).toThrow(HttpsError);
  });
});

describe("requireOrgInScope", () => {
  const claims = { ingestor: true as const, orgId: "org_1", teamIds: [] };

  it("allows the matching org", () => {
    expect(() => requireOrgInScope(claims, "org_1")).not.toThrow();
  });

  it("allows null", () => {
    expect(() => requireOrgInScope(claims, null)).not.toThrow();
  });

  it("rejects a different org", () => {
    expect(() => requireOrgInScope(claims, "org_9")).toThrow(HttpsError);
  });
});
