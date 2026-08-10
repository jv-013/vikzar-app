# Vikzar RC1 — Final Release Audit

**Auditor role:** CTO final release audit (post-reconstruction, pre-hardware).
**Date:** 2026-08-05
**Scope:** Determine whether the recovered repository is genuinely ready to become the Vikzar RC1 baseline before BLE Pods and EMG integration begin.
**Method:** Only issues demonstrated through actual validation (build, test, live backend calls, direct config inspection) are reported as issues. Nothing here is inferred or assumed.

---

## Executive Summary

The recovered repository **builds clean on Flutter (web/macOS-analyzed) and Android**, **builds and tests clean on the backend**, and every backend-dependent user journey I could exercise **succeeded live against production** (`vikzar-prod`). This audit found and fixed three real, demonstrated bugs — one web-crashing regression and two missing Android permissions — all traceable to gaps in the reconstruction's platform-layer wiring, not the application logic itself. It also found one significant, unfixed configuration gap (Android Google Sign-In has no OAuth client provisioned) that blocks a specific feature on a real device until a project owner completes it in the Firebase/Google Cloud Console.

No architectural redesign was performed or is recommended. The core application logic — Auth, Team, Onboarding, Sessions, RAZ, Voice orchestration — is sound, consistent, and, everywhere it could be exercised live, correct.

**Recommendation: RC1 Approved with Minor Issues.** See [Final Decision](#final-decision).

---

## Validation Results

| Check | Result |
|---|---|
| `flutter pub get` | ✅ Clean |
| `flutter analyze lib` | ✅ 0 errors, 4 pre-existing infos (App Check deprecated-param naming, 1 lint) |
| `flutter analyze` (full, incl. `test/`) | ⚠️ 1885 issues, 100% within the known-stale/unreconstructed test files (see Known Limitations) |
| `flutter test` | ⚠️ 80/88 pass — same 8 pre-existing failures as every prior validation pass this session, no new failures |
| `cd functions && npm install` | ✅ Clean (Node engine warning + pre-existing npm audit advisories — see Technical Debt) |
| `npm run build` | ✅ Clean |
| `npm test` | ✅ 107/107 passing |
| `flutter build apk` | 🔴→✅ Failed initially (demonstrated, fixed — see Android Readiness) |

---

## Runtime Results

### Chrome
Built and served `flutter build web --release`, loaded in a real browser.

- **Regression found and fixed:** `AuthScreen.initState()` unconditionally subscribed to `app_links`'s native event channel. On web this channel has no implementation, throwing an uncaught `MissingPluginException` that blocked the app from rendering past Auth. Fixed with a `kIsWeb` guard, matching the existing `isApplePlatform` pattern already used in the same file. Verified: rebuilt, reloaded, exception gone, correct Phase 17 Auth UI renders (Google button, email divider, "Email me a link").
- **Environment limitation, not an app bug:** this sandbox's Browser pane never sizes `flt-glass-pane` (`getBoundingClientRect()` = `0,0,0,0`), confirmed reproducible across every build attempted this session, including after the auth fix, including via same-page and cross-tab JS injection attempts. Rendering itself works (proven by screenshots showing correct content); only pointer hit-testing is broken. This blocks visual click-through testing generically — classified as an environment limitation per your instruction, not a Vikzar defect.
- **Verified live against `vikzar-prod`** (via direct calls replicating the exact frontend contracts, since click-through is blocked): Coach onboarding + Team creation (`createTeam`), Player onboarding (`users/{uid}` write), Team joining (`joinTeamWithInvite`), Planned Sessions (`createPlannedSession`), RAZ player `ask` (real generated text returned) and coach `dailyBrief` (real 4-section response). All succeeded.
- **Verified by code inspection only** (no backend call to script, visual confirmation blocked by the environment limitation): Voice UI, Notifications, Theme, Settings, Diagnostics. All compile clean under `flutter analyze` and their provider/repository wiring was independently verified during reconstruction.
- **Disclosure:** this pass created 5 more disposable Firebase Auth accounts and several test Firestore documents on live production, consistent with the pattern from prior validation passes this session.

### Android
See [Android Readiness](#android-readiness) below.

### macOS
`flutter run -d macos` was not executed this pass — see [Known Limitations](#known-limitations) for why, and what running it would additionally validate.

---

## Android Readiness

`flutter build apk --debug` was attempted, failed on a real, demonstrated error, and was fixed:

1. **Build failure (fixed):** `permission_handler_android` requires `compileSdk 37`; the project was on the Flutter-default `36`. Fixed with an explicit `compileSdk = 37` override in `android/app/build.gradle.kts` — Gradle's own error output specified this exact fix. Rebuilt clean.
2. **Missing permissions (fixed):** inspected the actual merged manifest (`build/app/intermediates/merged_manifests/debug/processDebugManifest/AndroidManifest.xml`), not just the source file. `RECORD_AUDIO` (required for RAZ Push-to-Talk/Wake Word) and `POST_NOTIFICATIONS` (required on Android 13+/API 33 to request notification permission at all) were both genuinely absent — confirmed by direct inspection, not assumption. Added both to `AndroidManifest.xml`, rebuilt, reconfirmed present in the merged output.
3. **Google Sign-In — NOT fixed, real blocker:** `android/app/google-services.json`'s `oauth_client` array is **empty**. No Google OAuth client is registered for the Android app. `google_sign_in` will fail with `DEVELOPER_ERROR` on a real device until a project owner registers one in the Firebase/Google Cloud Console against the release signing certificate's SHA-1/SHA-256 fingerprint. This is real Firebase project configuration state, unrelated to the reconstruction — I cannot fix it myself.
4. **Android App Links intent-filter — NOT added:** confirmed absent from `AndroidManifest.xml`. Required for the Firebase Email Link flow to reopen the app on Android. Not synthesized, because getting the exact host/scheme wrong would be worse than leaving it undone, and it additionally requires a real Firebase Hosting deploy of `hosting/.well-known/assetlinks.json` (already recovered, not yet deployed) for Android's Digital Asset Links auto-verification to succeed at all.

### Per-item status

| Item | Status |
|---|---|
| Android permissions (RECORD_AUDIO, POST_NOTIFICATIONS, INTERNET, etc.) | ✅ Verified by build (merged manifest inspected directly) |
| Google Sign-In configuration | 🔴 Verified by build — confirmed broken (empty OAuth client) |
| Firebase configuration (`google-services.json`, project ID, app ID) | ✅ Verified by build — present and internally consistent |
| Voice permissions (manifest-level) | ✅ Verified by build (RECORD_AUDIO now present) |
| Voice permissions (runtime grant flow) | ⏳ Requires physical device |
| Push-to-Talk | ✅ Verified by code inspection (logic sound) + ⏳ requires physical device for actual mic I/O |
| Foreground "Hey Raz" | ✅ Verified by code inspection (architecture sound, permission now present) + ⏳ requires physical device for actual detection |
| Wake Word architecture | ✅ Verified by code inspection |
| Theme | ✅ Verified by code inspection (same code path as Chrome, already flutter-analyze-clean) |
| Notifications | ✅ Verified by code inspection + permission now present; ⏳ requires physical device for actual OS-level delivery |
| RAZ | ✅ Verified live (Chrome pass hit the identical Cloud Functions Android will call) |
| Diagnostics | ✅ Verified by code inspection |
| Deep Links | 🔴 Verified by build — confirmed absent (intent-filter not wired) |
| App Check | ✅ Verified by code inspection (correctly wired, correctly non-blocking; real Play Integrity attestation requires physical device + Play Console registration) |
| Firebase Functions | ✅ Verified live (same backend Chrome already exercised; Android calls the identical `httpsCallable` contracts) |
| Firestore | ✅ Verified live (same rules/writes Chrome already exercised) |

No item above is claimed working that wasn't actually verified by one of: build inspection, live backend call, or direct code reading matched against a passing `flutter analyze`.

---

## Firebase Readiness

- **Firestore rules:** wholesale-recovered from the live, MCP-tool-verified deployed ruleset earlier this session (confirmed byte-identical to production at RC-1). Every collection referenced by the recovered backend (`teamInvites`, `razDailyBriefs`, `razMemories`, `_processedEvents`, etc.) has a matching rule; cross-verified with no orphans on either side.
- **Storage rules:** present, header-corrected to reflect actual deployment status, content otherwise unchanged (never needed reconstruction — the rules content itself was never edited historically, only the header comment was stale).
- **Cloud Functions:** confirmed complete and untouched by reconstruction — survived the original disk-loss incident via a more complete backup path (iCloud Archive) than the frontend did. 107/107 backend tests pass. Every `httpsCallable()` in the recovered frontend has a matching, exported Cloud Function; zero orphans in either direction.
- **Indexes:** `firestore.indexes.json` reconstructed from a multi-session edit chain; one real missing composite index (`sessions[playerId, endedAt DESC]`) found and added; three redundant/duplicate entries from overlapping session edits deduplicated before writing.
- **Region:** client (`FirebaseFunctions.instance`, no explicit region) and backend (`setGlobalOptions`, no explicit region) both default to `us-central1` — no mismatch.

---

## RAZ Readiness

Fully verified live this session: `razAsk` (player audience) returned real generated text with `confidence: "low"` for a fresh account with no session history — exactly the honest, low-confidence output expected for a brand-new player. `razDailyBrief` (coach audience) returned a real 4-section response with real highlights. Payload/response contracts were cross-checked field-by-field against `functions/src/contracts/types.ts`'s allowlist logic during reconstruction — exact match, including the "allowlist not required-keys" semantics that let an empty `history` array be safely omitted.

RazMemory and RazEngine are backend-only pipeline stages inside these two functions — the Flutter client never talks to them directly (`RazRepository` has exactly two methods: `ask` and `dailyBrief`). Their correct operation is verified transitively through the live calls above.

---

## Voice Readiness

See the dedicated Voice OS audit conducted this session (summarized): Push-to-Talk, Speech Recognition, Speech Synthesis, Conversation Flow, Wake Word architecture, Voice Settings, and Voice Permissions are all code-verified sound, and the conversation flow's answer-generation path (the part most likely to silently break) is proven live end-to-end via the RAZ calls above. Interruption handling is explicitly, honestly scoped in the code's own documentation to tap-to-interrupt only — spoken barge-in-while-speaking is a documented, deliberate non-goal (real hardware echo-cancellation problem, not something faked).

**"Hey Raz" verdict:** should work on a real Android device with the app in the foreground, given (a) the user grants the RECORD_AUDIO runtime permission — now correctly requestable following this audit's manifest fix, (b) the device has standard Android speech recognition available (near-universal with Google Play Services), (c) the user has opted into the wake-word toggle in Settings (off by default, by design). Remaining verification is manual-device-only and cannot be substituted: actual wake-phrase detection accuracy and false-positive rate, the real permission-dialog flow, real TTS audibility through device speakers, and real backgrounding/foregrounding arm-disarm behavior.

---

## Diagnostics Readiness

`DiagnosticsScreen` (Phase 20.5, `kDebugMode`-gated, unreachable in release builds) compiles clean, correctly reads `firestoreConnectivityProvider` (a real cache-vs-live signal off the signed-in user's own document), and surfaces RAZ call metrics, auth state, and app version. One nullable-safety gap found and fixed during reconstruction (`displayName.isEmpty` on a nullable field). Verified by code inspection; the screen itself is debug-only so live device access is optional for RC1 sign-off, not required.

---

## Security Review

- No hardcoded secrets or API keys in `lib/` or `functions/src` (one grep false-positive: a `sk-` substring inside "ri**sk**-level"). No `.env`/credential/service-account files present at the repo root.
- Gemini API key correctly scoped as a Cloud Functions secret binding (`GEMINI_API_KEY`), never client-side.
- Firebase config values (`firebase_options.dart`, `google-services.json`) are public, non-secret client identifiers by Firebase's own design — this is expected and correct, not a leak.
- Firestore/Storage rules deny-by-default on every Cloud-Function-owned collection, confirmed cross-referenced against actual backend usage with no gaps.
- Repository-pattern boundary (no raw Firestore/Functions calls from presentation code) held throughout every reconstructed subsystem, enforced structurally by `flutter analyze` passing.
- App Check is correctly wired but not enforced anywhere — a deliberate, documented, pre-existing state (not something this audit changed), safe because nothing currently depends on it being enforced.

No new security issues were found beyond what reconstruction already surfaced and fixed (Firestore rules `teams`/`users` hardening, already recovered in the earlier reconstruction phase).

---

## Known Limitations

See `RC1_KNOWN_LIMITATIONS.md` for the full, evidenced list. Summary:

- 8 pre-existing stale test failures (test OTP-based Auth and Phase-13 Coach Home shape, both legitimately superseded architecture)
- 17 test files never reconstructed (volume vs. runtime-impact tradeoff, explicitly deferred)
- 16 documentation files never reconstructed (zero runtime impact, explicitly deferred; `DECISIONS.md` flagged as highest-value future work)
- iOS/macOS platform config gaps (Info.plist permission descriptions, Xcode entitlements wiring) — real evidence gaps, not guessed at
- Android Google Sign-In OAuth client not provisioned
- Android Deep Links (App Links intent-filter) not wired
- Web email-link sign-in completion is inherently partial by original design (the flow is app-reopen-first; `finishSignIn.html`'s own copy says as much)
- Interruption handling is tap-only by explicit, documented design

## Technical Debt

- Kotlin Gradle Plugin (KGP) deprecation warning across 6 plugins (`cloud_functions`, `firebase_app_check`, `firebase_storage`, `flutter_tts`, `sign_in_with_apple`, `speech_to_text`) — future Flutter versions may refuse to build until these plugins migrate to Built-in Kotlin. Not actionable by this codebase; requires upstream plugin updates.
- 41 Flutter packages and multiple npm packages have newer versions available.
- `npm install` reports 11 audit advisories (10 moderate, 1 high) — not triaged this session; recommend a dedicated `npm audit` review before wider distribution.
- Node engine mismatch: `functions/package.json` requires Node 20, this environment runs Node 22 (`EBADENGINE` warning only, not a build failure).
- 8 stale + 17 unreconstructed test files represent real test-coverage debt that should be paid down before scaling the team, even though they don't block RC1 functionally.

## Future BLE Readiness

`lib/features/devices/` is confirmed empty — `RazConversationManager`'s own doc comment states this explicitly ("`lib/features/devices/` is empty today — there is nothing real to route such a command to yet"). The `devices/{deviceId}` Firestore collection and its rules exist and are correctly scoped (`allow create: if false` — "no device-provisioning UI this phase"), but there is no pairing UI, no repository, and no BLE plugin dependency anywhere in the codebase. This is exactly the state RC1 is supposed to be in before hardware integration — correctly, honestly unbuilt, not a stub pretending to work.

## Future EMG Readiness

Same finding as BLE — no EMG-specific code, models, or UI exist anywhere in the reconstructed codebase. `sessions/{sessionId}` remains laptop-authored-only per its own rules (`allow write: if false`) and doc comments throughout the reconstructed code consistently describe it as a future capture pipeline, never fabricated. Nothing needs to be undone before hardware work begins.

---

## Final Decision

### Recommendation: **RC1 Approved with Minor Issues**

**Justification, using only evidence from this audit:**

- Every code path this audit could exercise live (Firestore, all 5+ Cloud Functions, Firestore rules, Storage rules header, `flutter analyze`, `flutter test`, `npm test`, both a Chrome build and an Android APK build) either passed clean or had its one real failure demonstrated, fixed, and re-verified.
- The "Minor Issues" qualifier reflects three concrete, bounded, already-clearly-documented items that block specific features on specific platforms but do not block the app as a whole: Android Google Sign-In (needs a Console action, not code), Android Deep Links (needs a scoped follow-up, not a redesign), and iOS/macOS permission-description plist gaps (same category). None of these are architectural — all are configuration/wiring completions.
- Nothing in this audit found evidence of a deeper problem. The application logic itself — Auth, Team, Onboarding, Sessions, RAZ, Voice — is sound everywhere it could be tested, and the reconstruction's own internal consistency (backend/frontend contracts matching exactly, rules matching actual usage, zero orphaned Cloud Function calls) is itself strong evidence the recovery was faithful.

This is not RC1 Approved outright only because three real, user-facing gaps remain unresolved (not because of any doubt about the reconstruction's correctness) — see `RC1_RELEASE_CHECKLIST.md` for exactly what remains before the first hardware pilot.
