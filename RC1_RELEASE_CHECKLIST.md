# Vikzar RC1 — Release Checklist

Every remaining manual step before Vikzar's first hardware pilot (BLE Pods + EMG). Grouped by who needs to do it and why. Nothing on this list was performed automatically — this is a checklist, not a change log.

---

## Before any real-device testing

- [ ] **Android real-device validation** — install the debug APK (`build/app/outputs/flutter-apk/app-debug.apk`, already built and verified this session) on a physical Android device. Confirm: app launches, Auth screen renders, RECORD_AUDIO/POST_NOTIFICATIONS permission dialogs appear correctly, no crash on cold start.
- [ ] **iOS/macOS real-device or simulator validation** — `flutter run -d macos` and a real iOS build were not exercised this session. Run both and capture whatever the first real crash/error is (expected candidate: missing microphone usage-description key, per Known Limitation #3).
- [ ] **`flutter run` on Chrome in a real (non-sandboxed) browser** — this session's environment has a confirmed rendering sandbox limitation (Known Limitation #11); a normal developer machine's Chrome should not exhibit it. Confirms full click-through UI actually works, not just renders.

## Google Sign-In

- [ ] **Register an Android OAuth client** in the Firebase/Google Cloud Console for `vikzar-prod`, scoped to `com.vikzar.vikzar` and the release signing certificate's SHA-1/SHA-256 (Known Limitation #1). Without this, Android Google Sign-In fails with `DEVELOPER_ERROR`.
- [ ] Confirm the iOS OAuth client (transcript evidence suggests one may already be provisioned — `com.googleusercontent.apps.295770188338-...` — but this was not independently re-verified this session) is genuinely live, then complete the iOS `Info.plist` `CFBundleURLTypes` entry accordingly.
- [ ] Re-run the Google Sign-In flow end-to-end on both platforms once provisioned.

## Apple Sign-In (future)

- [ ] Add the "Sign in with Apple" capability to the App ID in the Apple Developer portal.
- [ ] Regenerate the provisioning profile.
- [ ] Wire `ios/Runner/Runner.entitlements` (already created this session) into `project.pbxproj`'s `CODE_SIGN_ENTITLEMENTS` — either via Xcode directly or a deliberate manual edit (Known Limitation #4).
- [ ] Verify Sign in with Apple end-to-end on a real iOS device (it's inert without a real signed build).

## Deep Links / Email Link sign-in

- [ ] Add an Android App Links intent-filter (`android:autoVerify="true"`) matching the Firebase Email Link continue URL (Known Limitation #2).
- [ ] Deploy `hosting/.well-known/assetlinks.json` (already recovered this session) via `firebase deploy --only hosting` so Android's Digital Asset Links verification can actually succeed.
- [ ] Complete the missing iOS/macOS permission-description keys surfaced by a real build attempt (Known Limitation #3), then verify the Associated Domains entitlement reopens the app from a tapped email link on a real device.

## Wake Word / Voice verification (physical device required — cannot be substituted)

- [ ] Grant microphone permission on a real device and confirm the runtime dialog appears correctly.
- [ ] Enable the "Hey Raz" toggle in Settings and speak the wake phrase near the device; confirm detection and false-positive rate are acceptable.
- [ ] Confirm TTS is actually audible through the device speaker at the default rate/volume.
- [ ] Background the app (lock screen, switch apps) while wake word is armed; confirm the microphone actually stops (per `RazVoiceController.didChangeAppLifecycleState`'s teardown logic) and re-arms correctly on resume.
- [ ] Test Push-to-Talk end-to-end: tap to talk, speak a real question, confirm RAZ's spoken answer.
- [ ] Test tap-to-interrupt ("stop talking over me") while RAZ is mid-speech.

## Firebase / Backend

- [ ] Clean up the disposable test accounts/documents created during this session's live validation passes (multiple `vikzar.validate.*`/`vikzar.chrome.*` Auth accounts, `teams`, `users`, `plannedSessions` documents on `vikzar-prod`) — self-delete is denied by rules, needs Console or Admin SDK cleanup.
- [ ] Decide on and schedule Play Integrity (Android) / App Attest (iOS) / reCAPTCHA v3 (web) provisioning for App Check, then flip enforcement only once every shipping client sends valid tokens (Known Limitation #7).
- [ ] Triage the 11 `npm audit` advisories (10 moderate, 1 high) in `functions/`.
- [ ] Address the Node engine mismatch (`functions/package.json` requires Node 20; this environment ran Node 22) before setting up CI, if not already handled there.

## Test & documentation debt (non-blocking, recommended before scaling the team)

- [ ] Delete or rewrite the 8 stale test files testing removed OTP-based Auth / superseded Phase-13 Coach Home shape.
- [ ] Reconstruct or rewrite the 17 never-reconstructed test files, starting with RAZ (largest gap).
- [ ] Reconstruct `DECISIONS.md` at minimum — every recovered file's doc comments cite ADR numbers with nothing to resolve them against.

## BLE integration (future, not started)

- [ ] `lib/features/devices/` is confirmed empty — build the pairing UI, repository, and BLE plugin integration from scratch when hardware work begins.
- [ ] The `devices/{deviceId}` Firestore schema and rules already exist and are correctly scoped — no rules work needed to start BLE integration, only client code.

## EMG integration (future, not started)

- [ ] No EMG-specific code exists anywhere in the codebase. `sessions/{sessionId}` remains laptop-authored-only by design (`allow write: if false`) — this is the correct, intentional state to build EMG capture on top of, not something to undo first.

---

**Recommended order:** Real-device validation first (surfaces the exact iOS permission-description keys needed), then Google Sign-In + Deep Links (both need Console access, do them together), then Wake Word/Voice manual verification, then test/doc debt whenever convenient. BLE/EMG are separate, later workstreams — nothing above blocks starting them once the platform gaps are closed.
