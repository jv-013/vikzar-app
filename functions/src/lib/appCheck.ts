/**
 * Phase 13 §9 — Firebase App Check enforcement for Cloud Functions.
 *
 * Deliberately **not** wired into any `onCall` definition yet. Every
 * `onCall(...)` in this codebase can take `{ enforceAppCheck: true }` as
 * its first argument (e.g. `onCall({ enforceAppCheck: true }, handler)`)
 * to reject any call lacking a valid App Check token — but flipping that
 * on before every real client is already sending tokens would instantly
 * break every legitimate caller (the laptop ingestion pipeline, and any
 * signed-in Player/Coach app install that predates this rollout).
 *
 * Correct rollout order, once the project owner has done the Console
 * work App Check requires (registering this app with Play Integrity /
 * App Attest / a reCAPTCHA v3 site key — see
 * `lib/services/firebase/app_check_service.dart` on the Flutter side for
 * exactly what's already wired client-side):
 *   1. Ship the client (already sends App Check tokens on every call,
 *      per `activateAppCheck()`) to all real users/devices.
 *   2. Confirm token delivery in the Firebase Console's App Check metrics
 *      for each function — real traffic should show as "verified", not
 *      "unmetered"/failing.
 *   3. Only then, add `{ enforceAppCheck: true }` to each `onCall(...)`
 *      call site in `callable/*.ts` and redeploy.
 *
 * `startSession`/`ingestLiveTick`/`completeSession`/`submitAlert`/
 * `submitReport` are called by the laptop ingestion pipeline specifically
 * — that pipeline would need its own App Check registration (Firebase
 * App Check supports non-Firebase/service clients via a custom token
 * exchange) before enforcement is turned on for those five, or every
 * laptop deployment breaks simultaneously.
 */
export const APP_CHECK_ROLLOUT_COMPLETE = false;
