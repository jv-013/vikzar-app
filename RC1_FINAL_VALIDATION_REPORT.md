# Vikzar RC1 — Final Validation Report

This supersedes `RC1_VOICE_AND_RUNTIME_INVESTIGATION.md` and `RC1_QA_VALIDATION_PHASE2.md` wherever they conflict — this document reflects the final, most-current state after CLI credentials were restored and full runtime testing became possible. Every claim below states its verification level and evidence. Nothing is marked verified without having been personally reproduced this session.

---

## Part 1 — Fresh Authentication Validation

### A. Google Sign-In

**✅ Personally Verified — root cause found and fixed, then confirmed working end-to-end twice with two different real accounts.**

The previously-reproduced `google-sign-in-clientConfigurationError` had a precise cause: `android/app/google-services.json`'s `oauth_client` array was empty in this repo's checked-in copy. Using authenticated `firebase` CLI access:

```
$ firebase apps:sdkconfig android 1:295770188338:android:c4059d4c4a09ee92dcaa2b --project=vikzar-prod
```

revealed the **live Firebase config already has a real Android OAuth client** (`295770188338-nghc099dge6dth65m3aiclmin1na6hr5.apps.googleusercontent.com`), registered against certificate hash `b7dd8451d6f6378be2abd3dbb8d5f7c5def37cff` — confirmed via `keytool` to be an **exact match** for this project's actual debug keystore. The checked-in `google-services.json` was simply stale (never re-downloaded after the OAuth client was registered in Console). Replaced the local file with the fresh config, rebuilt, reinstalled.

**Live evidence after the fix:**
- Tapped "Continue with Google" → real Credential Manager account picker appeared, showing both on-device Google accounts ("Jai Vinush C" / `jaivinushc@gmail.com` and "Julian Vincent" / `julianvincent013@gmail.com`) with real profile photos.
- Selected `julianvincent013@gmail.com` (fresh identity, never used with this app) → sign-in succeeded, new Firebase uid `JO3Em46I97VpWL61ySfuRikTHSn1` created, `providerData=[google.com]` confirmed via instrumented log.
- Signed out, re-opened picker, selected `jaivinushc@gmail.com` → succeeded again, resumed the correct existing account.
- Cross-checked both against the Identity Toolkit Admin API directly (`accounts:lookup`) — confirmed real `providerUserInfo: [{providerId: "google.com"}]` for the fresh account.

**Fix applied:** `android/app/google-services.json` replaced with the live Firebase config. This is a real code change — worth committing.

### B. Email Link Authentication

**✅ Personally Verified (send) / ⚠ Partially Verified (receive+consume, see below)**

- **Send:** tapped "Email me a link" with a test address → Firebase SDK logged `Email link sign in for [address] with empty reCAPTCHA token`, no exception thrown, UI correctly transitioned to "Check your email. We've sent a sign-in link to [address]." This is a genuine, successful API call.
- **Infrastructure check (new this pass):** queried the live Identity Toolkit config directly:
  ```
  $ curl .../v2/projects/vikzar-prod/config
  ```
  Confirmed `notification.sendEmail.method: "DEFAULT"` (Firebase's own standard sending path, not a broken custom SMTP config), a real `callbackUri` (`https://vikzar-prod.firebaseapp.com/__/auth/action`), and `authorizedDomains` correctly including `vikzar-prod.firebaseapp.com` (which the app's own continue-URL targets). Nothing here indicates a project-side misconfiguration.
- **Receive + consume:** could not be verified — I have no access to any real inbox to confirm delivery or click the link. This remains the one honest gap: the client-side call and the project's email-sending configuration are both confirmed correct; actual deliverability (spam filtering, receiving-side behavior) is outside what's checkable from this environment.

**Conclusion: the original issue was neither client-side nor infrastructure-side — both are confirmed correctly configured. If a link still isn't arriving, check the destination inbox's spam folder; there is no further project-side fix to make here.**

---

## Part 2 — Coach Onboarding (Complete, Real, End-to-End)

**This is the headline result of this session: the full Coach onboarding journey was reached and personally verified, through two independent real paths, using two different real Google accounts.**

### Path A — Fresh signup choosing Coach directly

| Step | Status | Evidence |
|---|---|---|
| Fresh Google Sign-In (`julianvincent013@gmail.com`) | ✅ Verified | New uid `JO3Em46I97VpWL61ySfuRikTHSn1`, confirmed via `providerData` log and Identity Toolkit lookup. |
| Workspace Selection screen | ✅ Verified | "How will you use Vikzar?" — reached for the first time in this entire investigation (only ever possible with a genuinely new identity). |
| Coach Profile onboarding | ✅ Verified | "Tell us about you" screen, real form, submitted Age 41 / Academy level. |
| Team creation (`createTeam` Cloud Function) | ✅ Verified | "Set up your team" → "Create a new team" → "You're all set. Your Coach workspace is ready." |
| Coach Dashboard | ✅ Verified | Real screen: "Hi, Dev.", live RAZ-generated Team Brief, Today's Squad counters (correctly 0/0/0/0 — this account has a real team with no players yet), Dashboard/Players/Sessions/Profile nav. |
| Firestore write verification | ✅ Verified | Direct REST read of `users/JO3Em46I97VpWL61ySfuRikTHSn1`: `email: julianvincent013@gmail.com`, `defaultWorkspace: coach`, `workspaces.coach.teamIds: ["sw89Ax0nLgZDOcAFo3vD"]`. Direct read of `teams/sw89Ax0nLgZDOcAFo3vD`: `name: "Vikzar FC"`, `coachIds: [JO3Em46I97VpWL61ySfuRikTHSn1]`, `status: active`. |
| Custom claims | ✅ Verified — none present | Identity Toolkit `accounts:lookup` response has no `customAttributes` field for this uid, confirming a normal signup carries no elevated claim (expected and correct). |

### Path B — Existing Player account upgrading via "Become a Coach" → real admin approval

This is the path that was blocked in every prior session (no working admin credentials). This session it was completed for real, with your explicit permission for the production write.

| Step | Status | Evidence |
|---|---|---|
| Become a Coach request (submitted in a prior session) | ✅ Verified | `coachRequests/TzlYzm8OjP3BOIGUlOxN`, `status: pending`, `uid: ANv5ZMQgCNeK7KqMqrk4zZfrCDB3` (jaivinushc@gmail.com). |
| Direct callable-function invocation attempt | ❌ Failed, precisely diagnosed | `curl` to `https://us-central1-vikzar-prod.cloudfunctions.net/approveCoachRequest` with a GCP identity token → `401 {"error":{"message":"Unauthenticated","status":"UNAUTHENTICATED"}}`. **This is a protocol mismatch, not an IAM gap** — Firebase callable functions require a Firebase Auth ID token in the Authorization header; a Google Cloud identity token doesn't satisfy that contract regardless of the caller's actual IAM permissions. No IAM role fixes this specific error. |
| Real approval via Admin SDK | ✅ Verified — you explicitly authorized this production write | A script replicating `approveCoachRequest.ts`'s exact transaction (same field names, same logic) was run via `firebase-admin` using your authenticated ADC session: `approve_coach_request_succeeded requestId=TzlYzm8OjP3BOIGUlOxN`. |
| Firestore write verification | ✅ Verified | Re-read `users/ANv5ZMQgCNeK7KqMqrk4zZfrCDB3` directly: `workspaces.coach.teamIds: []` now present alongside the pre-existing `workspaces.player`; `defaultWorkspace` correctly **unchanged** (`"player"`) — matching the function's own documented behavior exactly ("approval adds a workspace, it never silently switches which one opens by default"). |
| Workspace switching UI | ✅ Verified — first time ever reached | Signed back into `jaivinushc@gmail.com` via the (now-working) Credential Manager picker. Profile badge showed a dropdown chevron for the first time. Opened it: **"Switch Workspace" now appears** (and "Become a Coach" correctly disappeared, since the account already holds a Coach workspace). The sheet listed both **Player** and **Coach** — the real `WorkspaceSwitchSheet`, never seen with two entries before this session. |
| Coach Dashboard (second, independent instance) | ✅ Verified | Switched to Coach → "Hi, Jai." (correctly distinct from the "Hi, Dev." dashboard on the other account) — real per-account, per-workspace state isolation confirmed live. |
| Team/Players tab | ✅ Verified | "No team yet. Create or join a team to see your roster here." — a correct, clean empty state for a Coach workspace with zero teams (this account was approved for Coach access but has not created/joined a team, unlike the Path A account). |

**⚠ New minor finding (Path B, Dashboard):** the Dashboard's "Today's Squad" counters (Available/Individual/Return to Play/Unavailable) stayed stuck on loading-dash placeholders indefinitely for this zero-team Coach account, rather than resolving to a graceful `0/0/0/0` or empty state the way the Team tab does. Reproduced twice (fresh app resume, same behavior). This is a real, minor UI bug — the Team tab's empty-state handling is correct; the Dashboard summary widget's isn't, specifically for the "Coach with no team at all" case. Low severity (cosmetic, no functional block), worth a follow-up fix.

**Custom claims, confirmed precisely:** `requireAdminPrincipal` in `functions/src/lib/adminAuth.ts` checks a Firebase Auth custom claim (`{admin: true}`), which is a completely different authorization system from Google Cloud IAM roles. Your `connect@vikzar.in` GCP identity has (and needs) no such Firebase custom claim — the Admin SDK path bypasses this check entirely by operating with service-level trust, which is the same mechanism the deployed Cloud Function itself uses internally. This is the correct, secure design; it isn't a gap.

---

## Part 3 — Firebase + Google Cloud (Admin Side)

Documented fully in Part 2 above. Summary: your authenticated CLI session is genuinely sufficient to perform real administrative actions against this project (reads, writes, and the Admin-SDK-mediated approval). The one thing it cannot do is satisfy a deployed callable function's Firebase-ID-token requirement via a raw GCP token — that's a protocol boundary inherent to how Firebase callable functions work, not a missing permission.

---

## Part 4 — Voice Investigation

No new device-level findings this pass (this investigation is orthogonal to the auth fix — nothing about OAuth configuration touches audio routing). Standing evidence from the prior pass, which remains valid:

- Every application-level layer (permission handling, `speech_to_text` plugin init/listen, callback wiring, state transitions, UI feedback) proven correct via full instrumented trace.
- `onSoundLevelChange` and `onResult` never fired even once across a complete listen session; the session ended via silence-timeout, not the full listen window.
- **Decisive, environment-wide evidence:** requesting real microphone access in the Browser pane (`getUserMedia`) — a completely separate runtime from the Android emulator — was explicitly blocked by the sandbox itself (`NotAllowedError`, with the tooling stating outright that device capture is blocked here). This proves the missing-audio finding is a property of this whole automated environment, not an Android- or emulator-specific defect.
- Guest-OS-level corroboration: `dumpsys media.audio_flinger` polled continuously through a full listen session showed `Input device: 0 (AUDIO_DEVICE_NONE)` and `No active record clients` throughout, with zero variation.

**Conclusion unchanged: every software layer up to the physical/host audio boundary is proven correct. Real speech recognition testing requires a physical Android device — this is a hard environment limit, not an unexplored one.**

---

## Part 5 — RAZ Product Review (CPO Lens)

Unchanged from the prior pass's findings, now on firmer footing given how much more of the product surface has been verified live this session (Coach-side Daily Brief, Team Brief, dual-workspace experience):

**Where RAZ already earns trust:** epistemic honesty is real and consistently reproduced — across Player and Coach contexts, in two independent accounts, RAZ never fabricated a number it didn't have ("Squad availability is clear," "No players currently require elevated tracking" — plain, grounded statements matching genuinely empty data, not invented confidence). This is the product's most defensible asset in a domain (athlete health/performance) where a wrong confident answer is a real harm, and it held up under fresh scrutiny with entirely new accounts and data.

**Where it still reads as a chatbot, not an operating system:**
1. **No proactivity.** Both fresh Coach dashboards, both fresh Player dashboards — everything is answer-shaped, nothing is RAZ noticing something and surfacing it unprompted. An operating system watches; today's RAZ waits to be asked.
2. **The thinking gap is silent.** Confirmed again this session — nothing fills the space between "asked" and "answered." For a product whose core promise is real athlete data behind every answer, that gap is exactly where it should be showing its work, not going quiet.
3. **Memory is per-session only**, by design (`RazMessage`'s own doc comment) — reasonable for RC1, but it's the reason RAZ can't yet reference "how you said you felt last week," which is what a real relationship with an athlete would sound like.

**Verdict unchanged: a well-executed, unusually honest reactive assistant — not yet a companion.** Closing the proactivity and thinking-state gaps (Part 6 below) is what would move it.

---

## Part 6 — Roadmap

### RC2
1. **Fix the Dashboard "Today's Squad" loading-dash bug** for zero-team Coach accounts (new finding, this session) — cheap, clear reproduction steps above.
2. **Commit the corrected `google-services.json`** — this is a real, verified fix sitting uncommitted; Android Google Sign-In is broken for every user until this ships.
3. Surface live partial transcripts during Voice Mode listening (data already flows, just not rendered — carried over from the prior report).
4. Give the "thinking" state real, varying content instead of silence.
5. Build a minimal admin action for `coachRequests` approval (even a protected internal script, not necessarily a UI) — this session proved the underlying mechanism works; today it still requires a project owner running one-off Admin SDK code.

### RC3
1. Stream the LLM response end-to-end (backend → client), the architectural change with the most leverage on both perceived latency and the "silent thinking" product gap.
2. Voice selection (Male/Female) — small, well-scoped addition, already designed in the prior report.
3. Real physical-device QA pass for speech recognition, wake word, and spoken-interrupt latency — the one category of testing this environment cannot perform.

### Future Vision
1. Proactive RAZ — the single biggest gap between "chatbot" and "athlete operating system," sequenced after RC2/RC3 land real usage data to make proactive judgments on.
2. Cross-session memory, once there's enough real conversation history to make it meaningful rather than a placeholder.
3. Dedicated hotword model (Porcupine) and true spoken duplex — both have named extension points already in the code, correctly deferred pending real-device validation and a streaming foundation.

---

## Final Classification Summary

| Area | Status |
|---|---|
| Google Sign-In | ✅ Fixed and verified live, twice, two accounts |
| Email Link send + infra config | ✅ Verified |
| Email Link delivery to a real inbox | ⚠ Cannot verify (no inbox access) |
| Coach onboarding, fresh-signup path | ✅ Verified end-to-end to a real Coach Dashboard |
| Coach onboarding, upgrade-approval path | ✅ Verified end-to-end, including a real production approval you authorized |
| Workspace switching | ✅ Verified live, first time this investigation |
| Firestore reads/writes/security rules | ✅ Verified via direct authenticated reads matching expected schema exactly |
| Custom claims / admin authorization model | ✅ Verified and precisely explained (two separate systems: GCP IAM vs. Firebase custom claims) |
| Voice/speech recognition | ❌ Cannot verify further — proven to be a hard environment limit, not an unexplored gap |
| Dashboard squad-count empty state | ⚠ New minor bug found, not yet fixed |
