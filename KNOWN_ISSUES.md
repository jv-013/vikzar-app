# Vikzar — Known Issues (as of v1.0.0-rc.1, 2026-08-09)

Honest status only. Every line is labeled VERIFIED, PARTIALLY VERIFIED, PHYSICAL DEVICE REQUIRED, EXTERNAL CREDENTIAL REQUIRED, or KNOWN MAINTENANCE DEBT — never claimed working merely because it compiles.

## Release blockers
None for Android. iOS/macOS distribution requires Apple credentials this environment doesn't have (see below) — the code itself is release-ready on those platforms too.

## VERIFIED (real, live evidence — not "it compiled")
- **Android Google Sign-In on the release-signed APK.** The new keystore's SHA-1 was registered with Firebase, `google-services.json` re-downloaded and replaced, APK rebuilt and reinstalled fresh. A real Google Sign-In completed and the app launched straight into an authenticated Player home screen ("Good evening, Jai.") — confirmed via `adb shell dumpsys account` showing real Google accounts on the test device and the app reaching authenticated app state on a fresh install with no other auth path available.
- **Production RAZ streaming**, including on the release-signed, R8-minified/obfuscated APK specifically — confirmed via production server logs (`llm_stream_started` → `raz_ask_succeeded`) for calls made from both the debug and the release build.
- **RAZ memory write path** — a real Firestore document (`right_knee_discomfort`) was created in production from a real conversation, with the athlete's own words quoted back accurately.
- **RAZ coaching personality** — verified across three live production conversations (two debug build, one release build): short, specific follow-up questions instead of essays, honest "not enough data" instead of invented answers.
- **Android APK — genuinely release-signed.** Verified via `apksigner verify --print-certs`: certificate SHA-1 `6E:83:3D:FE:55:26:81:18:C6:1E:84:53:A6:73:13:B6:CA:87:24:E8` matches the real release keystore, not the debug one.
- **Android AAB** builds successfully (`flutter build appbundle --release`), standard bundle structure confirmed.
- **iOS release build** compiles clean (`flutter build ios --release --no-codesign`) after fixing a real deployment-target mismatch (Firebase's SDKs now require iOS 15.0; the project was still at 13.0) — unsigned `.app`, 47.2MB. Rebuilt and reconfirmed successful a second time after adding the microphone/speech-recognition Info.plist strings and the Google Sign-In URL scheme.
- **iOS Google Sign-In OAuth client is now provisioned.** A fresh `firebase apps:sdkconfig IOS` fetch returned a real `CLIENT_ID`/`REVERSED_CLIENT_ID` that the previously-tracked `GoogleService-Info.plist` did not have — replaced the tracked file with the live config, and added the required `CFBundleURLTypes`/`CFBundleURLSchemes` entry to `Info.plist` using that exact `REVERSED_CLIENT_ID`. This resolves what was previously documented as an external-credential blocker. **Not yet exercised live** (no Apple Developer Team means no signed build to actually run Google Sign-In on a device/simulator against) — the configuration is complete and correct, but end-to-end completion is unverified.
- **iOS/macOS microphone + speech-recognition permissions.** `macos/Runner/Info.plist` was missing `NSMicrophoneUsageDescription`/`NSSpeechRecognitionUsageDescription` — confirmed `speech_to_text` and `flutter_tts` both declare macOS platform support, so this was a real crash risk if RAZ voice were ever reached on macOS (today it isn't: `permission_handler_voice_permissions.dart`'s own `_isSupportedPlatform` already excludes macOS by design — this fix is defense-in-depth/future-proofing, not unblocking a currently-reachable path). Added, matching the equivalent iOS strings from earlier this release.
- **macOS release build** compiles and runs (`flutter build macos --release`) — ad-hoc signed only (`codesign` shows `flags=0x2(adhoc)`), confirmed via direct inspection.
- Backend: `npm run build` clean, `npm test` 115/115 passing. `flutter analyze lib/`: 4 pre-existing info-level lints only, none new.
- Security audit: no secrets/keys committed, keystore/`key.properties` correctly gitignored and untracked, no debug-signing fallback active in the actual built release artifact, no localhost/emulator-only assumptions in source, the `functions.json` root-collision bug does not recur.

## EXTERNAL CREDENTIAL REQUIRED
- **iOS/macOS code signing for real distribution.** No Apple Developer Team is configured anywhere in `ios/Runner.xcodeproj` or `macos/Runner.xcodeproj` (`DEVELOPMENT_TEAM` is unset; `CODE_SIGN_STYLE = Automatic` with no team to resolve against). Both platforms build successfully but only as unsigned (iOS) or ad-hoc-signed (macOS) artifacts — neither is distributable (App Store, TestFlight, notarized `.dmg`, or installable on another Mac without Gatekeeper overrides) until a real Apple Developer Program membership, Team ID, and provisioning profile are supplied. **Exact manual action required:** provide an Apple Developer Team ID (or add one to this machine's Xcode account) and re-run the release build with `CODE_SIGN_STYLE = Automatic` resolved against it, or supply a manual distribution certificate + provisioning profile. This same gap is also why iOS Google Sign-In (config now complete, see above) and Apple Sign-In (entitlement present, see `ios/Runner/Runner.entitlements`) can't be exercised end-to-end this pass — both need a real signed build/simulator run to test, not just correct configuration.
- **Windows build** cannot be attempted at all from this environment — `flutter build windows` requires a Windows host with Visual Studio; this session runs on macOS. The `windows/` project scaffold exists in the repo (`CMakeLists.txt`, `flutter/`, `runner/`) but has not been buildable or testable this release. **NOT TESTABLE HERE.**

## PHYSICAL DEVICE REQUIRED
- **Real speech-to-text.** No Android/iOS emulator or simulator can feed real audio to a speech recognizer. Voice Mode opens, listens, and closes cleanly with no crash on the Android emulator; no real transcription was or could be exercised.
- **TTS voice quality**, and Male/Female voice **character** specifically. The picker itself is architecturally correct (real platform voices only, never fabricated) and correctly self-hides on the Android emulator (no gendered voices reported there) — but actual voice quality on real hardware is untested.
- **iPad-specific physical testing.** `TARGETED_DEVICE_FAMILY = "1,2"` and iPad-specific orientation keys are present in `Info.plist`, so the app is configured for iPad — but no physical iPad or iPad simulator session was used this release to verify layout/orientation/split-screen behavior live.

## PARTIALLY VERIFIED
- **Android release build, full feature smoke test.** Launch, Google Sign-In, RAZ text, RAZ streaming were all verified live on the release APK. Settings/voice-selector screen, notifications, and full workspace-switching were **not** re-tested on the release build specifically this pass (their underlying code was unchanged since the prior session where they were verified on a debug build) — carried forward, not re-verified fresh.
- **iOS Simulator smoke test — attempted, not completed.** An iPhone 17 and iPad Pro 11" (M5) simulator were both booted and a debug `flutter run` was started against the iPhone simulator to smoke-test auth/RAZ live. The build did not finish compiling within this sprint's time budget (concurrent Android/macOS release builds were competing for the same machine's CPU) and was stopped rather than let run past the sprint deadline. No behavioral UI verification (auth, RAZ, navigation) was obtained from a simulator this pass — only the release *build* itself was verified (twice). This is a real gap, not a claim of success: iOS app behavior is unverified beyond "it compiles."

## KNOWN MAINTENANCE DEBT (explicitly out of scope this release)
- **Node 20 runtime** — Cloud Functions gen2 will eventually require a newer runtime. Not upgraded, per explicit instruction.
- Several Flutter plugins still apply the legacy Kotlin Gradle Plugin path on Android (`cloud_functions`, `firebase_app_check`, `firebase_storage`, `flutter_tts`, `sign_in_with_apple`, `speech_to_text`) — Flutter warns this becomes a hard error in a future version. Upstream plugin issue, not actionable from this repo.
- App Check is configured but not actually enforced in production (confirmed via logs: rejected tokens don't block calls). Real gap, not new to this release.

## Final test matrix

| | Android | iOS | iPadOS | macOS | Windows |
|---|---|---|---|---|---|
| Build | PASS | PASS | PASS (same build) | PASS | NOT TESTABLE HERE — needs Windows host |
| Release config | PASS | PASS (after iOS 15.0 deployment-target fix) | PASS | PASS | NOT TESTABLE HERE |
| Signing | PASS — real release keystore | BLOCKED — no Apple Developer Team | BLOCKED — same as iOS | PARTIAL — ad-hoc only | NOT TESTABLE HERE |
| Firebase | PASS | PASS (config present) | PASS | PASS (config present) | NOT TESTABLE HERE |
| Google Sign-In | PASS — verified live, real account | BLOCKED — iOS OAuth client not fully provisioned | BLOCKED — same as iOS | NOT TESTED — no iOS Dev Team to exercise it meaningfully | NOT TESTABLE HERE |
| Apple Sign-In | N/A (Android) | PARTIAL — entitlement present, inert without Apple Developer Team | PARTIAL — same | PARTIAL — same | N/A |
| Email Link | PASS (prior session) | NOT RE-TESTED this pass | NOT RE-TESTED | NOT RE-TESTED | NOT TESTABLE HERE |
| RAZ text | PASS — live production, 3 conversations | NOT TESTED — no runnable signed build | NOT TESTED | NOT TESTED | NOT TESTABLE HERE |
| RAZ streaming | PASS — verified via production logs, debug AND release APK | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTABLE HERE |
| RAZ voice UI | PASS — opens, listens, closes cleanly, no crash | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTABLE HERE |
| STT | PHYSICAL DEVICE REQUIRED | PHYSICAL DEVICE REQUIRED | PHYSICAL DEVICE REQUIRED | PHYSICAL DEVICE REQUIRED | NOT TESTABLE HERE |
| TTS | PARTIAL — architecture verified, quality PHYSICAL DEVICE REQUIRED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTABLE HERE |
| Notifications | NOT RE-TESTED this pass (unchanged code) | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTABLE HERE |
| Deep links | NOT RE-TESTED this pass | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTABLE HERE |
| Workspace switching | NOT RE-TESTED this pass (unchanged code) | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTABLE HERE |
| Coach flow | NOT RE-TESTED this pass (unchanged code) | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTABLE HERE |
| Player flow | PASS — live this pass, Google Sign-In → Home → RAZ | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTABLE HERE |

## Repository state
A large amount of prior, real, uncommitted work (auth rewrite, onboarding, sessions, team, live monitoring, notifications, Firestore security-rules hardening, several new features) still sits uncommitted in the working tree alongside this release's changes. This release's commit deliberately does **not** include it.
