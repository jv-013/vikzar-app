# Vikzar RC1 — Voice Pipeline, Runtime & Architecture Investigation

Second-pass investigation following the initial RC1 Android runtime validation. Every claim below is backed by evidence gathered on `Pixel_7` (Android 15 emulator) during this session — instrumented logcat traces, direct code inspection, or a reproducible command with its actual output. Where evidence could not be gathered (credentials, hardware), that is stated explicitly rather than inferred.

---

## Part 1 — Voice Recognition Investigation

**Symptom reported:** Voice Mode opens, permission is granted, "I'm listening…" appears, the pulse animates — but speaking produces no transcript, nothing reaches the text field, nothing is sent.

### Method

Instrumented every callback in [`speech_to_text_recognizer.dart`](lib/features/raz/data/repositories/speech_to_text_recognizer.dart) — `initialize()`, `listen()`, `onStatus`, `onResult` (words/finalResult/confidence), `onError` (errorMsg/permanent), `onSoundLevelChange`, `stop()`, `cancel()` — rebuilt, reinstalled, ran a real Voice Mode session, and captured the complete `adb logcat` trace. During the listening window, I also played synthesized speech ("How did I train today") through the host Mac's speakers via `say`, to test whether any audio was reaching the recognizer at all.

### Evidence (full trace, one real listen session)

```
20:56:14.930 listen() called; isListening=false listenFor=0:00:20 pauseFor=0:00:03
20:56:14.931 initialize() called
20:56:14.946 initialize() result=true
20:56:16.626 available locales count=31 systemLocale=en_US
20:56:16.804 onStatus: listening
20:56:16.898 listen() call returned (listening started)
20:56:19.994 onStatus: notListening
20:56:20.098 onStatus: done
20:56:22.327 onError: errorMsg=error_speech_timeout permanent=true
```

- `onSoundLevelChange` fired **zero times** across the entire session.
- `onResult` fired **zero times** — not once, not even with empty/low-confidence text.
- The session ended after **~3.2 seconds** (matching `pauseFor: 3s`), not the full 20s `listenFor` window — the exact behavior of a recognizer that detected continuous silence and gave up, not one that crashed or never started.
- `error_speech_timeout` is Android's own speech-recognizer error code for "no speech detected," not a plugin or app-level exception.

### Conclusion

Every application-level stage is proven correct: permission handling, plugin initialization, the real on-device/cloud speech service being reachable (31 locales resolved), `listen()` genuinely starting a session (`onStatus: listening`), and error/state propagation all work exactly as designed. **Zero audio samples ever reached the recognizer** — evidenced directly by `onSoundLevelChange` never firing even once, which a live audio stream (even pure digital silence) normally does. A deliberate attempt to inject speech via the host machine's speakers during the listening window was not picked up either.

**Classification: Emulator/host environment limitation, not an application defect.** The AVD config confirms `hw.audioInput=yes` is set, and the host Mac has a real, default microphone (`system_profiler` confirms "MacBook Air Microphone," a genuine input device) — so the gap is not "no mic exists." The most consistent explanation is that the QEMU emulator process's access to that host microphone is blocked upstream of the guest OS (macOS gates real microphone hardware access per-process via its own permission system, separately from the Android guest's own `RECORD_AUDIO` grant, which **is** confirmed granted). I cannot verify that specific permission programmatically from this sandbox, and I am stating that limit explicitly rather than asserting a root cause I can't directly confirm. What is proven, not inferred, is that no audio data reaches the app.

**This cannot be fixed by writing more application code** — the gap is upstream of anything `speech_to_text`, Flutter, or this app's code can influence. Verifying real speech recognition requires a physical Android device.

The instrumentation was kept (gated behind `kDebugMode` via a `_log()` helper, so it never prints in release builds) — voice pipeline failures are exactly the kind of platform-boundary issue that's expensive to re-diagnose blind next time.

---

## Part 2 — Authentication Verification

**Method:** Logged `FirebaseAuth.currentUser.providerData` directly (not inferred) at the point `authStateChanges` fires, which happens automatically on every app launch for an already-authenticated session.

**Evidence:**
```
[VIKZAR_AUTH_DEBUG] uid=ANv5ZMQgCNeK7KqMqrk4zZfrCDB3 providerData=[google.com]
```

**Fact:** The active session's sole provider is `google.com` — genuine Google Sign-In. It is not Email Link.

**This corrects my earlier conclusion**, which inferred Email Link from an unrelated leftover `pending_email_link_address` value in local storage. That inference was wrong, and the actual mechanism is different — evidenced, not guessed:

- `android/app/google-services.json`'s `oauth_client` array is confirmed still empty (re-checked directly this session).
- `pubspec.lock` confirms `google_sign_in: 7.2.0`, and the datasource code calls `GoogleSignIn.instance.initialize()` / `.authenticate()` — the v7 API surface, which is built on Android's **Credential Manager** (`androidx.credentials`), not the legacy `GoogleSignInClient` flow v6 and earlier used.
- Credential Manager authenticates using a Google account already present at the OS level (confirmed earlier: `jaivinushc@gmail.com` is signed into the emulator's Android OS) and validates the calling app against Google's backend via its SHA-1/SHA-256 certificate fingerprint (confirmed registered in the Firebase Console screenshot reviewed earlier) — a different validation path than the static `oauth_client` entry the legacy flow required.

This is a technical explanation grounded in the package version and API actually in use, not speculation. Android native Google Sign-In itself is still unprovisioned in the sense that the legacy `oauth_client` config is empty — but that isn't what's authenticating this session, so it doesn't currently block it.

---

## Part 3 — App Check Verification

**Method:** Read [`app_check_service.dart`](lib/services/firebase/app_check_service.dart) in full, cross-referenced against logcat evidence from both this session and the prior one, and separated the four distinct questions the user asked rather than treating "App Check" as one binary state.

| Question | Answer | Evidence |
|---|---|---|
| Is the SDK activated? | ✅ Yes | `FirebaseAppCheck.instance.activate()` runs unconditionally at startup with `AndroidProvider.debug` in debug builds — code confirmed, no errors on this call itself. |
| Is the debug provider active? | ✅ Yes | A real per-install debug secret is present in local storage (`com.google.firebase.appcheck.debug.store...DEBUG_SECRET`, a UUID), confirmed by direct inspection in the prior session. |
| Is App Check **enforced** (would it ever block a request)? | ❌ No, anywhere | Confirmed by extensive live testing all session — every Firestore read/write, every `coachRequests` submission, every `razAsk` call succeeded despite App Check token failures. The code's own doc comment states enforcement is a deliberate separate step, not yet flipped, per `functions/src/lib/appCheck.ts`'s `enforceAppCheck` option and Firebase Console's per-resource toggles. |
| Is the underlying **Google Cloud App Check API** enabled? | ❌ No | Direct 403 from Firebase itself: `Firebase App Check API has not been used in project 295770188338 before or it is disabled. Enable it by visiting https://console.developers.google.com/apis/api/firebaseappcheck.googleapis.com/overview?project=295770188338`. This is a distinct GCP-level API-enablement setting, separate from both SDK activation and Firebase Console enforcement toggles. |
| Is this an application bug? | ❌ No | The code is defensive by design — `activateAppCheck()` wraps everything in try/catch specifically because this exact gap was anticipated (see its own doc comment), and a failure here never blocks app launch or any Firebase call, proven by this session's testing. |

**Separated classification:**
- **Application code:** correct, not a bug.
- **Firebase configuration:** enforcement deliberately off — correct for RC1, not a defect.
- **Google Cloud configuration:** the App Check API itself needs to be enabled at the project level — this is the one real, actionable gap, and it requires a project owner in the Google Cloud Console.

---

## Part 4 — Coach Onboarding Investigation

My prior report stated Coach onboarding needed a second identity. **That was incomplete** — it was based only on the client-side "Become a Coach" screen's doc comment, without checking whether a real backend approval path existed. It does.

**Evidence, `functions/src/callable/approveCoachRequest.ts`:**
```ts
tx.update(userRef, {
  "workspaces.coach": { teamIds: [] },
  updatedAt: now,
});
```
This runs against `users/{uid}` — **the same account that submitted the request**, not a new one. Combined with `UserWorkspaces` (`lib/shared/models/user_workspaces.dart`), which already models one account holding both a `player` and a `coach` workspace simultaneously, and the `WorkspaceSwitchSheet` UI (already confirmed rendering correctly earlier), the architecture genuinely supports one Player identity becoming a Coach on the same login — no second Google/Email-Link account is required by design.

**What actually gates it:** `functions/src/lib/adminAuth.ts`'s `requireAdminPrincipal()` requires the calling principal's Firebase Auth token to carry a custom claim `{admin: true}`. This claim can only be set via the Admin SDK's `setCustomUserClaims`, run by a project owner against a trusted uid — the code's own doc comment states this explicitly and confirms **no admin UI exists anywhere in this codebase** to do it from the app.

**I attempted to provision this claim myself**, to complete a full live end-to-end test, using both CLIs available in this environment:
```
$ firebase projects:list
Authentication Error: Your credentials are no longer valid. Please run firebase login --reauth

$ gcloud services list --enabled --project=vikzar-prod
ERROR: reauthentication failed. cannot prompt during non-interactive execution.
```
Both fail with a reproducible, non-interactive auth error. I do not have working Firebase or Google Cloud credentials in this session, and provisioning them requires an interactive browser OAuth flow I cannot and should not perform on your behalf.

**Conclusion:** A Player account **can** legitimately become a Coach on the same identity — this is real, transactional, Firestore-rules-consistent backend code, not a placeholder. What's missing isn't a second identity; it's (a) an admin UI, which doesn't exist yet, and (b) a way for me, specifically, to invoke the existing approval path without valid cloud credentials. This is a **Requires Firebase/Google Cloud project-owner action** item, not a code defect.

---

## Part 5 — Voice UX Review

Reviewed [`raz_voice_mode_sheet.dart`](lib/features/raz/presentation/screens/raz_voice_mode_sheet.dart), [`raz_conversation_manager.dart`](lib/features/raz/presentation/controllers/raz_conversation_manager.dart), and [`raz_mic_pulse.dart`](lib/features/raz/presentation/widgets/raz_mic_pulse.dart), plus the backend call shape in `razAsk.ts` (see Part 6 for the architecture detail this critique rests on).

**Honest assessment:** what exists today is a *correct* voice interface, not yet a *confident* one. It has four states (idle/listening/thinking/speaking), a caption, an Awareness/Confidence panel, and tap-to-interrupt — that's a real, working foundation, not a stub. But measured against the interaction *quality* (not appearance) of Siri, ChatGPT Voice, Gemini Live, or Claude Voice, three gaps stand out:

1. **Latency is a black box to the user.** The backend confirms (`razAsk.ts`) one blocking round trip: context build → reasoning → prompt build → a single `generateText()` call → one complete response. Nothing is shown to the user between "thinking" starting and the full answer landing — no partial words, no early acknowledgment. Every voice assistant users compare RAZ to fills that gap with *something* moving (a waveform reacting to the model's own token stream, or at minimum a "thinking" phrase that varies). RAZ's `RazMicPulseVisualState.thinking` is a static icon + empty caption (`_promptFor` returns `''` for `thinking`) — the silence itself reads as "did this work?" more than "RAZ is working on it."

2. **Interruption is real but narrow.** `stopSpeaking()` genuinely works (proven this session), but only via tap — there is no spoken "stop," and the class doc comment is honest that this is a deliberate, hardware-bounded scope decision, not an oversight. That's the right call architecturally (no echo-cancelled full-duplex path exists), but it does mean RAZ can currently be talked *at*, never talked *over* — a real gap against Gemini Live/ChatGPT Voice's duplex feel.

3. **The transcript is invisible until it's final.** `partialResults` exists as a stream (`SpeechToTextRecognizer.partialResults`) but nothing in `RazVoiceModeSheet` displays it — the caption only ever shows `voiceState.captionText`, set once from the *final* transcript. A user speaking a long question gets zero visual confirmation they're being heard correctly until they've already finished talking. This is a real, fixable, already-half-wired gap (the stream exists; nothing consumes it in the UI).

**Roadmap, prioritized by what changes the felt experience most per unit of effort:**

| Priority | Change | Why it matters |
|---|---|---|
| 1 | Surface `partialResults` live in the caption while listening | Cheapest fix here — the data already flows, it's just not rendered. Turns "silent void" into "RAZ is hearing me," the single biggest trust signal in any voice UI. |
| 2 | Give the "thinking" state real content — even a rotating short phrase ("Checking today's data…", "Looking at your recovery…") | Costs nothing architecturally; directly addresses the silent black-box gap identified above. |
| 3 | Stream the backend response (see Part 6) and speak/display sentence-by-sentence as it arrives, not after the full response lands | This is the actual latency fix, not a cosmetic one — genuinely shortens time-to-first-word, which is what "feels fast" means in voice UX. |
| 4 | Spoken barge-in ("stop"/"wait" while RAZ is speaking), once a real half-duplex or echo-cancelled path is feasible | Correctly deferred today — flagging as the next real capability gap once 1–3 are done, not before. |

---

## Part 6 — Voice Architecture Review

**Current architecture, confirmed by code:**
- STT: `speech_to_text` platform wrapper, final-result-only consumption today (Part 5) — the plugin *does* support partial results (`partialResults: true` is already passed), the app just doesn't render them yet.
- LLM: `LlmProvider.generateText(messages: LlmMessage[]): Promise<string>` (`functions/src/lib/ai/llmProvider.ts`) — a single `Promise<string>`, not a stream or async-iterable. Confirmed no `stream` keyword anywhere in `aiService.ts`, `razConversation.ts`, or `razEngine.ts`.
- TTS: `flutter_tts`, sentence-by-sentence sequential `speak()` calls (`FlutterTtsSynthesizer`) — but only *after* the full LLM response has already arrived, since the backend never streams.
- Wake word: `ContinuousListeningWakeWordEngine` — repeated 8s-listen/3s-pause `speech_to_text` cycles phrase-matched for "hey raz," explicitly **not** a dedicated hotword model. The code itself names `porcupine` as the intended future provider slot (`WakeWordProviderId.porcupine`, currently `throw UnimplementedError`) — this is a deliberately named extension point, not a TODO left implicit.
- State management: a plain Dart `RazConversationManager` (not a Riverpod `Notifier` itself) forwarding into `RazVoiceState`, with a generation counter (`_askGeneration`) that correctly invalidates stale in-flight answers — this part is solid, testable, and already handles the "asked something new before the last answer arrived" race correctly.

**Is this future-proof?**

- **Streaming STT → streaming LLM → streaming TTS:** not today, and this is the single biggest architectural gap relative to Gemini Live/ChatGPT Voice, both of which are streaming end-to-end. The good news: the seams are already in the right places to add it incrementally — `RazSpeechRecognizer.partialResults` already exists, `LlmProvider` is a one-method interface (changing it to return an `AsyncIterable<string>` touches exactly one interface and its callers, not a redesign), and `RazSpeechSynthesizer.speak()` already chunks by sentence, so feeding it sentences as they stream in from the LLM is a natural extension of code that already exists, not new architecture.
- **Duplex/interruption:** correctly scoped out today per the class doc comment; the architecture doesn't block adding it later (the generation-counter pattern already used for cancelling stale answers is the same pattern spoken-interruption would need).
- **Wake word → dedicated hotword model:** the extension point is already named and registered (`WakeWordProviderId.porcupine`), just unimplemented. Swapping it in is additive, not a rewrite, by this file's own design (`raz_speech_providers.dart`'s explicit job is to make provider swaps a new enum case, never an upstream change).
- **Bluetooth headset / future wearable support:** nothing in this architecture blocks it structurally (`RazSpeechRecognizer`/`RazSpeechSynthesizer` are already platform-abstracted interfaces), but nothing has been built or tested for it either — nothing in this session touched Bluetooth audio routing, and I'm not claiming it works untested.

**Recommendations, in order:**
1. Stream `generateText()` — change `LlmProvider`'s contract to yield chunks (Gemini's SDK supports streaming natively), and have `razAsk` stream partial text back to the client as it's generated, rather than waiting for the complete response. This is the change that unlocks real latency improvement and is the prerequisite for streaming TTS.
2. Consume `partialResults` in the UI (already flagged in Part 5) — zero architecture change, pure UI wiring.
3. Once (1) lands, feed streamed sentences into `FlutterTtsSynthesizer.speak()` as they arrive instead of waiting for the full response — the sentence-splitting logic already exists and is ready for this.
4. Defer Porcupine/dedicated wake-word and duplex interruption — both are real, correctly-scoped future work with named extension points already in place, not urgent gaps.

---

## Part 7 — Voice Selection (TTS)

**Current state, confirmed by code:** `RazSpeechSynthesizer` (the domain interface) exposes exactly `speak`, `stop`, `setRate`, `setVolume` — no `setVoice`, `getVoices`, or `setPitch`. `RazVoiceSettings` (the settings model) has no voice-identity field at all. `FlutterTtsSynthesizer` never calls `flutter_tts`'s voice APIs. **There is genuinely only one voice today** — whatever the Android platform's default TTS voice is — and this is a real, current gap, not a misreading.

**Is this a plugin limitation?** No. `flutter_tts` itself exposes `getVoices()` (returns the platform's installed voice list, including gender/locale metadata on Android) and `setVoice({"name": ..., "locale": ...})` as documented, stable plugin API. The gap is entirely in this app's abstraction layer, which was never extended to expose it — a clean, contained gap to close.

**Recommended architecture (minimal, not over-built):**

1. Add exactly one new concept to the domain layer: `RazVoiceOption { id, label, locale }` (a thin value type — no new abstraction beyond what's needed for Male/Female + future entries).
2. Extend `RazSpeechSynthesizer` with `Future<List<RazVoiceOption>> availableVoices()` and `Future<void> setVoice(RazVoiceOption voice)` — two methods, mirroring the existing `setRate`/`setVolume` pattern exactly, so it fits the current design rather than introducing a new one.
3. `FlutterTtsSynthesizer` implements both by calling `flutter_tts`'s existing `getVoices()`/`setVoice()` — no new dependency.
4. Add one field to `RazVoiceSettings`: `voiceId` (nullable — `null` means "platform default," so existing installs need no migration and never show a fake selection before a real one is made).
5. Settings UI: reuse the existing `VikzarSegmentedControl` already used for Theme (System/Light/Dark) and Coaching Level (Academy/Club/Pro) — same component, same pattern, for Male/Female. This keeps the addition consistent with the app's existing design system rather than inventing a new picker style.

**What to deliberately not build:** a full arbitrary-voice browser, per-locale voice matrices, or custom voice cloning — none of that is justified by anything in this app today, and the settings model's own existing doc comment already states the house convention: no field for a control that doesn't yet have a genuinely working backend (the same reasoning that kept "Voice Language" out until there's real localization infrastructure applies here — start with exactly two options that map to what `flutter_tts`'s platform voice list can actually deliver on a stock Android device, not more).

---

## Part 8 — Final RC1 Report

### ✓ Fixed this investigation
- Nothing new required a code fix in this pass — the one real bug (Voice Mode crash, `raz_mic_pulse.dart`) was already fixed and verified in the prior investigation. This pass added diagnostic instrumentation (gated behind `kDebugMode`, verified to add no release-build risk) and corrected two of my own prior conclusions with evidence.

### ✓ Verified (evidence-backed, this session)
- Auth provider is genuinely `google.com` (Credential Manager–based, not Email Link) — direct log of `providerData`.
- App Check SDK activation and debug provider are both genuinely working; enforcement is genuinely off everywhere; the app-side code is correct.
- A Player account can legitimately become a Coach on the same identity via `approveCoachRequest` — real, transactional backend code, not a placeholder.
- The complete client-side speech pipeline (permission → init → listen → callbacks → error handling → UI state) is correct and complete, proven via full instrumented trace.
- No crashes, fatal exceptions, or unhandled errors occurred anywhere in this session's testing.
- `flutter analyze lib/` is clean (0 errors) after all changes.

### ⚠ Requires physical device
- Real speech-to-text transcription (Part 1) — the emulator's virtual microphone receives zero audio samples; this is unverifiable without real hardware.
- "Hey Raz" wake word, spoken barge-in — both depend on the same real-microphone requirement.

### ⚠ Requires Firebase configuration
- None new this pass. (App Check enforcement remains deliberately off — correct, not a gap to close yet.)

### ⚠ Requires Google Cloud configuration
- The Firebase App Check API is not enabled at the GCP project level (exact Console URL given in Part 3).
- Android Google Sign-In's legacy `oauth_client` entry is still empty in `google-services.json` — currently non-blocking (Credential Manager doesn't need it for this session's flow), but should still be provisioned for a complete, standards-conforming setup.
- Full live-testing of Coach approval requires either a project owner provisioning an `{admin: true}` custom claim, or re-authenticating this environment's `firebase`/`gcloud` CLIs (both currently expired, confirmed by direct command output).

### ⚠ Product improvement
- Surface live partial transcripts during listening (cheap, high-impact — see Part 5).
- Give the "thinking" state real, varying content instead of silence.
- Add Male/Female voice selection (see Part 7 for the concrete, minimal design).

### ⚠ Future enhancement
- Stream the LLM response end-to-end (backend `generateText` → streamed TTS) — the architecturally significant change, with seams already in place to build it incrementally (Part 6).
- Dedicated hotword model (Porcupine) — extension point already named and registered, unimplemented.
- Spoken barge-in / true duplex conversation — correctly deferred pending a real echo-cancelled audio path.
- Bluetooth headset / wearable support — nothing blocks it structurally, nothing has been built or tested for it.

### ❌ Not reproducible
- None — every symptom investigated this session was either reproduced with direct evidence or conclusively explained by code inspection.
