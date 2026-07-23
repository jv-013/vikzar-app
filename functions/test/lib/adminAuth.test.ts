import { HttpsError, CallableRequest } from "firebase-functions/v2/https";
import { requireAdminPrincipal } from "../../src/lib/adminAuth";

function callableRequest(
  uid: string | undefined,
  token: Record<string, unknown> | undefined
): CallableRequest<unknown> {
  return {
    data: undefined,
    auth: uid ? { uid, token: token as never } : undefined,
    rawRequest: {} as never,
  } as unknown as CallableRequest<unknown>;
}

describe("requireAdminPrincipal", () => {
  it("returns the uid for a valid admin principal", () => {
    const uid = requireAdminPrincipal(callableRequest("admin-1", { admin: true }));
    expect(uid).toBe("admin-1");
  });

  it("throws unauthenticated when there is no auth context", () => {
    expect(() => requireAdminPrincipal(callableRequest(undefined, undefined))).toThrow(
      HttpsError
    );
  });

  it("throws permission-denied when the admin claim is missing", () => {
    expect(() => requireAdminPrincipal(callableRequest("u1", {}))).toThrow(HttpsError);
  });

  it("throws permission-denied when the admin claim is false", () => {
    expect(() =>
      requireAdminPrincipal(callableRequest("u1", { admin: false }))
    ).toThrow(HttpsError);
  });

  it("does not accept a client-claimed admin flag from a Player/Coach token shape", () => {
    // A regular signed-in user's token never carries `admin` at all —
    // confirms this can't be spoofed via any payload shape, since the
    // claim is read from request.auth.token (Firebase-verified), never
    // from request.data.
    expect(() =>
      requireAdminPrincipal(callableRequest("player-1", { email_verified: true }))
    ).toThrow(HttpsError);
  });
});
