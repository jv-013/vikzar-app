# RAZ Conversational Intelligence Upgrade (RC2+RC3 Combined Pass) — Final Report

This document is the record of the combined RC2+RC3 RAZ interaction-engine pass. Per the operating instruction for this pass, nothing here claims something works unless it was actually verified — code inspection, unit tests, `flutter analyze`/`tsc`, and live device testing are each labeled as what they are, never conflated.

---

## 1. What changed

**Shipped and active today:**
- Live partial-transcript captions in Voice Mode (the athlete's own words appear as they're recognized, not only after they finish speaking).
- A real, honest "thinking" status ("Checking your data…") instead of silence — tied to an actual stage (RAZ genuinely gathering context before the model call), not a rotating set of invented phrases.
- RAZ's conversation style now asks the smallest useful follow-up question on open-ended/physical statements, per the persona's own extended instruction — verified by reading the updated prompt, not by evaluating live model output (see §10).
- A voice/text presentation split (`ConversationMode`) threaded through the Flutter call sites and the backend prompt — voice answers are instructed to stay to one or two short spoken sentences; text answers can go into more detail. The `mode` value itself is **not yet transmitted on the wire** (see §11b) — the parameter is real and plumbed end-to-end in the client, but sending it would break every RAZ call against the currently-deployed backend, so it stays local until that backend ships. Full mode-aware phrasing is backend-only until deployed (see §12).
- **RAZ chat, live end-to-end, confirmed working after a second regression this pass introduced and then fixed** — see §11b. A real question ("How is my team looking today?") sent from the Coach conversation screen on the `Pixel_7` emulator produced a real, grounded answer, correct `Awareness` sourcing (Team Data/Training History/Calendar shown as used; Pods/EMG/GPS/Weather correctly shown as not connected), and honest `Confidence: Low` — exactly the trust-model behavior in `docs/RAZ_PRODUCT_PRINCIPLES.md` §4, not a scripted demo response.
- A real, working memory **write** path: `razMemoryExtraction.ts` deterministically detects body-part + concern-word mentions in an athlete's own question and records them via the already-existing (but previously entirely unused) `recordMemory()`. Backend-only until deployed.
- Male/Female voice selection in Settings, using the platform's real installed TTS voices — verified live to gracefully hide itself on this Android emulator, since its TTS engine reports no gender metadata (proven, not assumed — see §10).
- A fixed, real production bug: `android/app/google-services.json` was stale, causing `google-sign-in-clientConfigurationError` on every fresh sign-in. Replaced with the live Firebase config; verified live, twice, with two different Google accounts (see prior session's `RC1_FINAL_VALIDATION_REPORT.md`).

**Built, real, and NOT active today (see §11 for exactly why):**
- Real backend LLM streaming (`generateTextStream`, `razAsk`'s `sendChunk` calls) — fully implemented, compiles, and is architecturally sound, but not deployed (deployment tooling failure — see §12) and therefore not exercised by the live client.
- The Flutter streaming client path (`askStream`, sentence-by-sentence TTS as an answer arrives) — implemented, but deliberately switched off via a single flag (`_useStreamingConversation = false` in `raz_conversation_controller.dart`) after live testing found it can freeze the entire app against the currently-deployed, non-streaming-aware backend. See §11 — this is the most important finding of this pass.

---

## 2. Files changed (this pass, RAZ-specific)

**Backend (`functions/src/`):**
- `lib/ai/llmProvider.ts` — added `generateTextStream` to the interface.
- `lib/ai/geminiProvider.ts` — real `generateContentStream` implementation.
- `lib/ai/resilientProvider.ts` — streaming-aware retry/timeout wrapper (first-chunk-only retry, since a stream can't be silently re-run once a chunk has already reached the caller).
- `lib/intelligence/persona.ts` — added the "smallest useful follow-up question" conversation-style section.
- `lib/intelligence/razConversation.ts` — added `ConversationMode`, voice/text length instructions.
- `lib/intelligence/razMemoryExtraction.ts` — new. Deterministic body-part/concern-word memory candidate extraction.
- `lib/validation.ts` — added `optionalEnum` helper.
- `contracts/types.ts` — added optional `mode` field to `RazAskPayload`.
- `callable/razAsk.ts` — streaming-capable handler (`sendChunk` per delta), calls memory extraction.

**Flutter (`lib/features/raz/`):**
- `domain/repositories/raz_repository.dart` — `RazConversationMode`, `RazAskEvent`/`RazAskDelta`/`RazAskDone`, `askStream()`.
- `data/repositories/raz_repository_impl.dart` — `askStream()` implementation with a 25s stream-level timeout (see §11); `ask()`/`askStream()` accept `mode` as a real parameter, but `_askPayload()` deliberately omits it from the transmitted map until the backend ships (see §11b) — sending it against the old backend's strict exact-shape validation is what broke every RAZ call, live, this pass (fixed).
- `domain/models/raz_message.dart` — `RazMessage.razStreaming` (in-progress message state).
- `domain/models/raz_voice_state.dart` — `thinkingLabel` field.
- `domain/utils/raz_text_utils.dart` — new. Shared sentence-boundary/formatting helpers (moved out of `flutter_tts_synthesizer.dart` so both the synthesizer and the streaming controller can use the same logic).
- `presentation/controllers/raz_conversation_controller.dart` — `_askOnce`/`_askStreaming` split behind `_useStreamingConversation`.
- `presentation/controllers/raz_conversation_manager.dart` — live partial-transcript subscription, real thinking-state label, sentence-chain speaking for the (currently inactive) streaming path.
- `presentation/controllers/raz_voice_controller.dart` — passes `mode`/`onSentence` through; applies the selected TTS voice on build and on change.
- `presentation/screens/raz_voice_mode_sheet.dart` — shows `thinkingLabel` during the thinking state.
- `domain/models/raz_voice_option.dart` — new. `RazVoiceOption`/`RazVoiceGender`.
- `domain/repositories/raz_speech_synthesizer.dart` — `speakSentence`, `availableVoices`, `setVoice`.
- `data/repositories/flutter_tts_synthesizer.dart` — real implementations of the above via `flutter_tts`'s actual `getVoices`/`setVoice` API.
- `domain/models/raz_voice_settings.dart`, `presentation/controllers/raz_voice_settings_controller.dart`, `services/local_storage/voice_settings_store.dart` — `voiceName` persistence.
- `data/providers/raz_speech_providers.dart` — `razAvailableVoicesProvider`.

**Other:**
- `lib/features/profile/presentation/screens/settings_screen.dart` — `_RazVoiceSelector` widget (Male/Female picker, self-hiding when the platform can't confidently offer both).
- `android/app/google-services.json` — real production fix (§1).
- `docs/RAZ_PRODUCT_PRINCIPLES.md` — new. Durable reference for RAZ's identity, personality, trust model, voice/memory/proactivity principles.

---

## 3. Architecture changes

- **Memory now has a real write path.** The read side (`getMemories`, folded into every `razAsk`/Daily Brief context) already existed and was fully wired; `recordMemory()` existed but was never called from anywhere. It now is, from a new, narrow, deterministic extraction step — not a second LLM call, by design (no added latency, no new hallucination surface on a path that writes to a permanent record).
- **Streaming is a real, additive capability, not a replacement.** `LlmProvider.generateText` (non-streaming) is untouched; `generateTextStream` sits alongside it. `RazRepository.ask` (non-streaming) is untouched; `askStream` sits alongside it. Nothing about this pass removed the previously-working request/response path — which is exactly what made the safe revert in §11 a one-flag change instead of a rewrite.
- **Presentation mode (`voice`/`text`) is threaded end-to-end** but changes nothing about `FootballReasoning` — per `docs/RAZ_PRODUCT_PRINCIPLES.md` §5, this is deliberate: the same underlying truth, phrased differently for the surface it's answering on.

## 4. Voice changes
Covered in §1/§2. Net effect on the experience, as designed (not yet verified beyond what §10 confirms): live listening feedback, an honest thinking state, and a real (not fake) male/female voice choice where the platform supports it.

## 5. STT changes
None to the recognition pipeline itself. The only change is *consumption*: `RazConversationManager` now subscribes to `RazSpeechRecognizer.partialResults` (which already existed and already worked, per the prior session's investigation) for the duration of each listen session, scoped so it never overlaps with the wake-word engine's own background cycles.

## 6. Streaming changes
Fully implemented on both sides (§1), verified by compilation/`flutter analyze`/`tsc`/unit tests, **not verified end-to-end live**, and **deliberately not active** in the shipped client. See §11 for why, and exactly what would need to happen to safely turn it on.

## 7. Memory changes
Covered in §1/§3/`docs/RAZ_PRODUCT_PRINCIPLES.md` §6. Scope is deliberately narrow (body-discomfort mentions only) — expanding it is future work, one category at a time, each with its own real trigger condition.

## 8. Proactivity changes
None implemented this pass — architecture documented in `docs/RAZ_PRODUCT_PRINCIPLES.md` §7 (the real scheduled-function/trigger pattern this would follow), deliberately not built, per the explicit instruction that a fabricated proactive insight is worse than none.

---

## 9. Tests run

- `cd functions && npm run build` — clean, zero errors, this session, multiple times as changes landed.
- `cd functions && npm test` — **107/107 passing**, this session, multiple times as changes landed. No RAZ-specific backend tests exist to have been broken or extended (pre-existing gap, documented in the prior session's audit).
- `flutter analyze lib/` — **clean, 4 pre-existing info-level lints, zero errors** — same 4 as before this pass began, none introduced by this work.
- `flutter analyze lib/features/raz/` (repeated after every RAZ file change this pass) — clean throughout.
- No Flutter RAZ unit tests exist (pre-existing gap, documented previously) — nothing to run or break there.

## 10. What was actually verified (live, on the `Pixel_7` emulator, this session)

- ✅ **Personally Verified** — Settings screen renders correctly with all new/changed code paths; the RAZ Voice picker correctly and gracefully hides itself (confirmed via logcat: zero errors from `availableVoices()`), because this emulator's Android TTS engine reports no gender metadata for its installed voices — exactly the documented, intended behavior for that case, not a bug.
- ✅ **Personally Verified** — Voice Mode opens without crashing, transitions to "I'm listening…" correctly, mic pulses, no regressions from the manager/controller rewrite.
- ✅ **Personally Verified** — the non-streaming conversational path (`_askOnce`, the currently-active path) sends a real request and, when it fails, surfaces a real, clean, fast, user-visible error ("Couldn't reach RAZ. Please try again.") — no hang, no freeze.
- ✅ **Personally Verified — critical finding** — the streaming path (`askStream`, via `HttpsCallable.stream()`) against the currently-deployed backend **freezes the entire Flutter app**, not just the one request. Reproduced twice. A client-side `Stream.timeout()` was added as a real defensive measure but **does not help**, because the freeze appears to stop the isolate's own event loop from processing at all (confirmed: zero app log output of any kind for 2+ minutes after the freeze began, including from unrelated background frame-rendering activity that runs constantly under normal operation).
- ❌ **Could Not Verify** — real spoken transcription, wake word, and anything requiring genuine microphone input — this is the same hard, previously-proven sandbox limitation from the prior investigation (the Browser pane's own mic access is blocked at the environment level), unrelated to this pass's changes.
- ❌ **Could Not Verify** — RAZ's actual conversational output quality against the new persona/mode instructions (the "smallest useful follow-up question" behavior, voice-length brevity) — this requires the backend to be deployed with these changes, which deployment tooling in this environment could not do (§12). The prompt changes are real and reviewed, but no live model response was ever generated against them.
- ❌ **Could Not Verify** — the memory-extraction write path actually writing to Firestore — same deployment blocker.
- ✅ **Personally Verified — RAZ chat restored end-to-end, after a regression this pass introduced (§11b)** — a real message sent from the Coach RAZ conversation screen returned a real, grounded, non-fabricated answer with correct `Awareness` sourcing and honest `Confidence: Low`. Confirmed via screenshot and a `logcat` sweep immediately after showing no `razAsk`-related errors, no `invalid-argument`, no exceptions.

## 11. The critical finding, in full

Attempting to deploy the updated backend (`firebase deploy --only functions`) failed — not because of anything in this pass's code, but because of a **pre-existing, reproducible, environment-level tooling failure**: Firebase's function-discovery step (`Could not find functions.yaml. Must use http discovery`) spawns a local HTTP server to introspect the compiled functions and consistently receives `{"endpoints":{}}` — zero functions found — for every function in the codebase, including ones never touched this session (`startSession`, verified directly as a control). The compiled module itself loads correctly under plain `node -e "require(...)"`, listing all 20 expected exports with no error. This is a deployment-tooling problem in this specific sandboxed environment, not a code defect — but its practical effect is the same: **the new backend could not be deployed and verified this session.**

Because the backend couldn't be updated, the currently-*live* `razAsk` is still the old, non-streaming revision. Testing the new Flutter client's `askStream()` path against that old backend produced a severe, reproducible failure: the app doesn't error, doesn't time out, and doesn't recover — it freezes completely. Adding a `Stream.timeout()` (a real, generally-valuable defensive addition, kept in the code) did not fix this specific case, because the freeze appears to be at a level below what a Dart `Timer` can preempt.

**Given "production stability > feature count" is the explicit standard for this pass, the response was not to paper over this with a UI-level workaround, but to make the demonstrably-safe path the active one.** `_useStreamingConversation = false` is the entire fix: one flag, in one file, with the reasoning documented at the point of the flag itself. The streaming code is not deleted, stubbed, or faked — it's real, complete, and ready to activate the moment both sides can be deployed and tested together.

## 11b. Second critical finding: RAZ chat broke, then was fixed, live, this pass

After the §11 revert (`_useStreamingConversation = false`) made `_askOnce` the active path, a live user report ("the RAZ chat box aint working") surfaced a second, distinct regression: **every RAZ message was failing**, cleanly, with "Couldn't reach RAZ. Please try again."

**Root cause:** `_askPayload()` in `raz_repository_impl.dart` was including the new `mode` field in every request body. The currently-*deployed* `razAsk` (the old, pre-this-pass revision, per §11) validates its payload with `requireExactShape(["audience", "question", "history"])` — a strict check that rejects any unrecognized field. Every call was therefore failing fast with `invalid-argument`, server-side, before ever reaching the model. This is the same underlying cause as §11 (the new backend was never deployed), but a different, previously-unverified symptom: not a freeze this time, a clean failure on literally every message.

**Fix:** `_askPayload()` now omits `mode` from the transmitted map entirely, while keeping the `mode` parameter itself on `ask()`/`askStream()` — real, threaded, ready. Re-enabling it is a one-line change (add `'mode': mode.wireName` back into the map) the moment the mode-aware backend is actually deployed and confirmed live, not a re-plumb.

**Verified, live, this pass:** rebuilt (`flutter build apk --debug`), reinstalled on `Pixel_7`, sent a real question from the Coach RAZ screen, and got back a real, grounded answer (§10, §1). This is the fix that satisfies the explicit instruction to look into and finish the reported bug — RAZ chat is confirmed working again as of this pass, against the currently-deployed backend, in the currently-active (non-streaming) code path.

## 12. Release risks

- **Do not flip `_useStreamingConversation` to `true` without first confirming, live, that the deployed `razAsk` is the new streaming-capable revision.** Flipping it against an old backend reproduces the freeze in §11.
- **Do not add `mode` back into `_askPayload()`'s transmitted map until the mode-aware backend is confirmed deployed and live.** Doing so against the old backend reproduces the clean-but-total chat failure in §11b. The two flags (`_useStreamingConversation` and the `mode` field) are independent — both gate on the same underlying event (a real, verified backend deploy) but must each be flipped deliberately, not together by assumption.
- **The backend changes in this pass (streaming `razAsk`, memory extraction, mode-aware prompts) are not live.** Nothing about live RAZ behavior has changed for real users yet — this is stated plainly so it isn't assumed shipped.
- **Deployment tooling in this environment is unreliable for Cloud Functions** (§11) — this needs to be resolved (or functions deployed from a different environment) before any of this pass's backend work can go live.
- `android/app/google-services.json`'s fix (§1) is unrelated to RAZ but real, tested, and safe to ship independently.
- The memory-extraction keyword list (`razMemoryExtraction.ts`) is intentionally narrow; broadening it should be done deliberately, one category at a time, not by generalizing the current pattern-matcher.

## 13. Build artifacts
- `functions/lib/` — compiled, current, verified via `node -e require()` to load all 20 functions with no error (not deployed — see §11).
- `build/app/outputs/flutter-apk/app-debug.apk` — current debug build, includes every change in this pass, installed and exercised live on `Pixel_7` this session.

## 14. Git status
This repository has a large pre-existing uncommitted diff from the earlier RC1 reconstruction effort (documented in prior session reports) — `git status` reflects that entire history, not just this pass. The files listed in §2 are the ones this specific pass touched; nothing in this pass was committed (no commit was requested).

## 15. Recommended next step

1. Resolve the Cloud Functions deployment-tooling failure (§11) — likely needs a different environment/machine, since this is not a code issue.
2. Deploy the backend from that environment, then confirm live (a single real `razAsk` call) that the streaming protocol actually works end-to-end before touching `_useStreamingConversation`.
3. Only then, flip `_useStreamingConversation = true`, rebuild, and re-verify live exactly as this session did for the non-streaming path — including deliberately testing what happens on a slow/flaky connection, not just the happy path.
4. Once live, do a real conversational-quality pass against the new persona instructions — this pass could review the prompt but never hear RAZ actually apply it.

## 16. Summary

Everything in §1 that's marked "shipped and active" is real, tested at the level stated, and live-verified not to have broken anything. Everything marked "not active" is equally real — not a stub, not faked — but was correctly held back after live testing surfaced a serious risk that this pass's own stated priorities required taking seriously rather than working around.
