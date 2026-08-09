# Vikzar — Known Issues (as of v1.0.0-rc.1, 2026-08-09)

Honest status only — nothing here is claimed working unless it was actually verified, and the verification method is stated.

## Release blockers
None. Everything below is either release-safe, a documented cloud-configuration step, or explicitly requires physical hardware that a release build doesn't block on.

## Cloud configuration (not a code issue)
- **Google Sign-In does not work on release-signed builds yet.** The new release keystore's SHA-1 (`6E:83:3D:FE:55:26:81:18:C6:1E:84:53:A6:73:13:B6:CA:87:24:E8`) needs to be added to the Google Cloud OAuth client, then `google-services.json` re-synced. Confirmed live: the sign-in flow opens Google's account picker and returns without completing, no crash. Email Link sign-in is unaffected. See `DEPLOYMENT.md`.
- **App Check is not enforced in production.** Production logs show `Callable request verification failed: AppCheck token was rejected` on every `razAsk` call this session, and separately `Firebase App Check API has not been used in project ... or it is disabled` (HTTP 403) on the client. Calls succeed anyway — App Check exists in config but isn't actually gating anything right now. Real gap, not new to this release; documented here so it isn't assumed to be providing protection it isn't.

## Physical device required (cannot be honestly claimed from emulator testing)
- **Real speech-to-text.** The Android emulator has no path to feed real audio to the speech recognizer — proven repeatedly across sessions, not re-litigated this sprint per instruction. Voice Mode opens, listens, and closes cleanly with no crash, but no real transcription was or could be exercised. **PHYSICAL DEVICE REQUIRED.**
- **Voice quality / Male-Female TTS voice character.** The picker is architecturally correct (queries real platform voices, never fabricates gender) and was already verified this pass to gracefully hide itself on this emulator (no gendered voices reported by Android's stock TTS engine here). Actual voice *quality* on a real phone's TTS engine — not tested. **PHYSICAL DEVICE REQUIRED.**
- **Streaming sentence-level TTS in Voice Mode**, end-to-end with a real spoken question, requires real STT input to trigger — see above. The code path (`RazConversationManager._ask`, sentence chaining, generation-counter guards) was verified via text-mode streaming this release, which exercises the same downstream pipeline from the point a question is known; only the "spoken question → transcript" leg is untested live.

## Release-safe (working, verified, shipping)
- Production RAZ streaming (`razAsk` revision `razask-00003-mad`) — verified via server logs (`llm_stream_started` → `raz_ask_succeeded`) across two separate real test calls.
- `mode` field accepted by production, no `invalid-argument` failures.
- Memory write path — verified via a real Firestore document created in production during this session's testing.
- RAZ coaching personality (short follow-up questions, honest "not enough data" responses) — verified via two live production conversations.
- `flutter analyze lib/` — clean except 4 pre-existing info-level lints (unrelated to this release; documented in prior sessions, not reintroduced).
- Backend: `npm run build` clean, `npm test` 115/115 passing.
- Release APK builds, installs, launches, and reaches the sign-in screen without crashing.

## Maintenance debt (explicitly out of scope this release)
- **Node 20 runtime.** Firebase Cloud Functions gen2 will eventually require a newer Node runtime. Not upgraded this release per explicit instruction — routine future maintenance, not a release blocker today.
- Several Flutter plugins (`cloud_functions`, `firebase_app_check`, `firebase_storage`, `flutter_tts`, `sign_in_with_apple`, `speech_to_text`) still apply the legacy Kotlin Gradle Plugin path; Flutter's build output warns this will eventually become a hard error. Not actionable from this repo alone (upstream plugin issue) — tracked here, not fixed this release.

## Repository state
- A large amount of prior, real, uncommitted work (auth rewrite, onboarding, sessions, team, live monitoring, notifications, Firestore security-rules hardening, several new features) still sits uncommitted in the working tree alongside this release's RAZ/signing changes. This release's commit deliberately does **not** include it — see the commit for exactly what's included. That work still needs its own review and commit before it's lost.
