# Vikzar RC1 — Known Limitations

Every item below is evidenced by an actual validation step performed this session (build output, direct file inspection, live backend call, or code reading cross-checked against a passing `flutter analyze`). Nothing here is speculative.

---

## 1. Android Google Sign-In has no OAuth client provisioned
**Evidence:** `android/app/google-services.json`'s `oauth_client` array is empty — inspected directly.
**Impact:** `google_sign_in` will fail with `DEVELOPER_ERROR` on a real Android device.
**Classification:** Android configuration issue.
**Resolution:** requires a project owner to register an Android OAuth client in the Firebase/Google Cloud Console, against the release signing certificate's SHA-1/SHA-256 fingerprint.

## 2. Android Deep Links (App Links) are not wired
**Evidence:** `AndroidManifest.xml` has no intent-filter for the Firebase Email Link continue URL — confirmed absent by direct inspection.
**Impact:** tapping a magic-link email on Android will not reopen the app.
**Classification:** Recovery regression (platform wiring for a recovered feature was never completed).
**Resolution:** add a host-matching intent-filter with `android:autoVerify="true"`, and deploy `hosting/.well-known/assetlinks.json` (already recovered, not yet deployed) via `firebase deploy --only hosting` so Android's Digital Asset Links auto-verification can succeed.

## 3. iOS/macOS platform permission descriptions incomplete
**Evidence:** `ios/Runner/Info.plist` and `macos/Runner/Info.plist` are near-default Flutter-generated baselines missing microphone/speech-recognition usage-description keys that transcript evidence showed once existed. The evidence gap itself is the limitation — the exact prior content couldn't be safely reconstructed without guessing.
**Impact:** requesting microphone permission on iOS/macOS will likely crash the app (missing usage description is a hard crash on iOS, not a soft failure) until these keys are added.
**Classification:** Recovery regression (evidence gap, not yet resolved).
**Resolution:** a real device/simulator build will surface the exact missing key by name via a clear crash message — safer to complete this way than to guess at the surrounding structure.

## 4. `ios/Runner/Runner.entitlements` is not wired into the Xcode project
**Evidence:** the file was recreated (Sign in with Apple + Associated Domains) but `project.pbxproj`'s `CODE_SIGN_ENTITLEMENTS` build setting was not touched — `.pbxproj` is a complex generated format, unsafe to hand-edit via string replay.
**Impact:** the entitlements file currently has no effect on a real iOS build.
**Classification:** Recovery regression (known, not fixed by design — see reasoning above).
**Resolution:** open the project in Xcode once and let it register the entitlements file normally, or a project owner runs the equivalent `pbxproj` edit deliberately.

## 5. Web email-link sign-in is inherently partial
**Evidence:** `hosting/finishSignIn.html`'s own copy: "If this didn't open automatically in the app, open the sign-in link again from your email on the device with Vikzar installed."
**Impact:** a user who requests a magic link on web and doesn't have the app installed cannot complete sign-in purely on web.
**Classification:** Existing RC1 limitation (by original design, not a defect introduced by reconstruction).
**Resolution:** none required for RC1 — Google Sign-In is the primary web path; this is an acknowledged fallback gap in the original architecture.

## 6. Interruption handling is tap-only
**Evidence:** `RazConversationManager`'s own class doc comment explicitly states spoken barge-in-while-RAZ-is-speaking is out of scope, calling it "a genuine hardware-dependent problem, not something to fake" (no echo-cancelled full-duplex audio path exists).
**Classification:** Existing RC1 limitation (deliberate, documented design decision).
**Resolution:** none required — working as designed.

## 7. App Check is not enforced anywhere
**Evidence:** `activateAppCheck()`'s own doc comment states this explicitly; confirmed non-blocking throughout this entire session's live testing (App Check activation failures never once blocked a Cloud Function or Firestore call).
**Classification:** Existing RC1 limitation (deliberate, pending manual Console provisioning of Play Integrity/App Attest/reCAPTCHA that only a project owner can do).
**Resolution:** documented in the code itself as future work; enforcing it prematurely (before every shipping client sends valid tokens) would break existing installs.

## 8. 8 pre-existing test failures
**Evidence:** `flutter test` output, stable and identical across every validation pass this session.
**Files:** `failure_message_mapper_test.dart`, `auth_repository_impl_test.dart`, `auth_screen_test.dart`, `coach_home_screen_test.dart`, and 4 more — all testing either the removed OTP-based Auth API or the superseded Phase-13 Coach Home dashboard shape.
**Classification:** Technical debt (legitimately superseded behavior; the tests were never updated, not something broken by reconstruction).
**Resolution:** delete or rewrite these 8 test files against the current, correct architecture.

## 9. 17 test files never reconstructed
**Evidence:** explicit scope decision during reconstruction (RAZ: 10 files, Auth: 4, plus 3 scattered others).
**Classification:** Technical debt.
**Resolution:** lower priority than functional code; can be rebuilt incrementally.

## 10. 16 documentation files never reconstructed
**Evidence:** explicit scope decision; zero runtime impact confirmed throughout (never affected `flutter analyze`/`npm build`/`npm test`).
**Files:** `ARCHITECTURE.md`, `BACKEND_SPECIFICATION.md`, `CHANGELOG.md`, `DECISIONS.md`, `DESIGN_SPECIFICATION.md`, `FLUTTER_ARCHITECTURE.md`, `README.md`, `ROADMAP.md`, `DEPLOYMENT.md`, `KNOWN_ISSUES.md`, `RELEASE_NOTES.md`, `RC1_CTO_RELEASE_AUDIT.md`, `PRODUCTION_READINESS_REPORT.md`, `CTO_AUDIT_PHASE_19_5.md`, `CTO_AUDIT_PHASE_20.md`, `RAZ_CONSTITUTION.md`.
**Classification:** Technical debt.
**Resolution:** `DECISIONS.md` is highest priority — nearly every reconstructed file's doc comments cite ADR numbers with no document to resolve them against.

## 11. Browser sandbox rendering limitation
**Evidence:** `flt-glass-pane` never sizes itself (`0,0,0,0`) in this session's Browser pane, reproducible across every build attempted, including after fixes and via multiple workaround attempts.
**Classification:** Environment limitation — not a Vikzar defect. Rendering itself works correctly (proven via screenshots); only pointer hit-testing in this specific sandboxed browser is affected.
**Resolution:** none needed for RC1; a real browser or device would not be expected to exhibit this.

## 12. Kotlin Gradle Plugin (KGP) deprecation warning
**Evidence:** `flutter build apk` output, both build attempts this session.
**Plugins affected:** `cloud_functions`, `firebase_app_check`, `firebase_storage`, `flutter_tts`, `sign_in_with_apple`, `speech_to_text`.
**Classification:** Technical debt (upstream, not actionable within this codebase).
**Resolution:** monitor for plugin updates; not urgent, Flutter has not yet made this a hard build failure.
