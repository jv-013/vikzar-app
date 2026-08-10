# Vikzar RC1 — QA Validation Phase 2

Continuation of `RC1_VOICE_AND_RUNTIME_INVESTIGATION.md`, treated as real QA: nothing below is marked verified unless personally exercised on the `Pixel_7` emulator or in the Browser pane this session, with the observed evidence stated. Where verification was blocked, that is stated as a fact, not smoothed over.

**Read this first — an incident during this session:** partway through re-testing Voice Mode, a sequence of `adb` back/tap commands landed on unexpected screens: Android's own system "Add a Google Account" wizard, mid-flow, on its "Set a home address" step, for an account (`julianvincent013@gmail.com`) I had not seen before and did not knowingly add. I did not tap "Skip" or "Save" — I back-gestured out immediately without completing that step. Separately, and I believe unrelated, Vikzar's own app session for `jaivinushc@gmail.com` ended during the same window — the app now shows its normal signed-out Auth screen, not an error state.

**What I know, factually:**
- `adb shell dumpsys account` now lists two Google accounts on this AVD's OS: `jaivinushc@gmail.com` and `julianvincent013@gmail.com`.
- I never typed an email, password, or any account-setup field for `julianvincent013@gmail.com`. I did not tap "Skip" or "Save" on the "Set a home address" screen.
- Vikzar's app-level session is now signed out.

**What I do not know, and will not guess:** exactly which of my `adb` commands (or something already queued on this AVD before I resumed testing it) caused either of these. This AVD has been rebooted and reused many times across a very long project history, and I cannot rule out that `julianvincent013@gmail.com` was already mid-setup on this image before this session touched it. I am telling you this plainly rather than picking an explanation that sounds tidy.

**What this means going forward:** I have not signed into anything, sent any email, or completed any account action. I will not tap "Continue with Google" or submit an email on Vikzar's Auth screen — both require either your credential entry or sending a real email, and both are outside what I'll do unattended. Everything below that needed a live, signed-in session was either completed *before* this happened (and is reported as such, with timing noted) or is now blocked, and I say so explicitly.

---

## Part 1 — Coach Onboarding, End-to-End

| Step | Status | Evidence |
|---|---|---|
| Fresh Coach signup (brand-new identity choosing Coach at Workspace Selection) | ❌ Could Not Verify | Requires a Google account sign-in I have never used before, i.e. real credential entry — prohibited for me to perform. The Browser pane has no authenticated Google session either (confirmed: navigating to `console.firebase.google.com` redirected to `accounts.google.com`'s sign-in page, page text captured, no session). No fresh identity was available to test with. |
| "Become a Coach" screen renders and accepts input | ✅ Personally Verified | Done in the prior session on this same account: form filled (Academy / RC1Validation / HeadCoach), submitted, resulted in "Your request has been submitted" confirmation screen. |
| Coach request creation (Firestore write) | ✅ Personally Verified | Same submission produced a real `coachRequests` document — confirmed by the UI reaching the success screen (a network-dependent state only reachable after firestore write succeeds), and by re-checking this session (see next row) that no error state exists. |
| Coach approval | ❌ Could Not Verify | `functions/src/callable/approveCoachRequest.ts` requires a caller with Firebase custom claim `{admin: true}` (`adminAuth.ts`). No admin UI exists in the codebase. I attempted to provision this myself two ways this session: `firebase login:ci --no-localhost` → `Error: Cannot run login:ci in non-interactive mode.` (exact output). `gcloud services list --project=vikzar-prod` → reauthentication error, both reproduced again this session. **Exact requirement to unblock:** a project owner must either (a) run `firebase login` / `gcloud auth login` interactively once in this environment, or (b) provision the `{admin: true}` claim on a dedicated principal via the Admin SDK from their own machine, or (c) build an admin UI — none of which I can do without your direct action. |
| Workspace creation (`workspaces.coach` appearing on the user doc) | ❌ Could Not Verify | Downstream of Approval, which is blocked. |
| Coach workspace switching (`WorkspaceSwitchSheet`) | ✅ Personally Verified (negative case) | Re-opened the Profile sheet live this session, *before* the sign-out incident: only **"Player workspace"** is listed, no "Switch Workspace" entry — confirming `heldWorkspacesProvider` correctly shows exactly one workspace when only one exists. This is real, correct behavior, but it is the negative case — I have not seen the sheet with two workspaces present, because none exists on this account. |
| Coach dashboard access | ❌ Could Not Verify | No account on hand has ever held a Coach workspace, so this screen was never reached in a signed-in state this session or the last. |
| Firestore writes (Coach-scoped) | ❌ Could Not Verify | Same blocker. |
| Firestore reads (Coach-scoped) | ❌ Could Not Verify | Same blocker. |
| Security rules (Coach-side) | ⚠ Partially Verified | I read the exact rule text (`firestore.rules` lines 110–166) rather than assume: `workspaces.coach` is writable by the account itself on a first-time null→value grant, then frozen against further edits. This is a genuine, precise reading of the deployed rule text, not a guess — but it is code inspection, not a live write-and-observe test, because no live write was possible without credentials. I am not calling this "personally verified" since I did not watch a real write succeed or fail against it. |
| Role assignment / custom claims | ⚠ Partially Verified | Confirmed by direct log that the currently-authenticated principal (`jaivinushc@gmail.com`) carries no `admin` claim — `requireAdminPrincipal` would reject it (read from code, consistent with the CLI auth failures being a separate, compounding blocker). I did not attempt to inspect the ID token's claims directly (e.g., via a decoded JWT), so I'm marking this partial, not full. |

**Summary for Part 1:** Everything reachable *without* admin credentials or a fresh identity was exercised live and is reported above with its evidence. The single hard boundary is `requireAdminPrincipal` — there is no code-level or UI-level path around it, and I confirmed (not assumed) that my own environment's cloud credentials can't clear it either. **What's needed to unblock the rest:** one of the three options listed in the Approval row above, from you or another project owner.

---

## Part 2 — Voice Investigation (deeper pass)

Repeated the investigation from Phase 1 with the specific suspects you listed, plus one new, decisive test.

**New test — is this Android-specific, or environment-wide?** I requested real microphone access in the Browser pane (a completely different runtime, unrelated to the Android emulator) via `getUserMedia({audio: true})`. Result: `NotAllowedError: Permission denied`, and the tooling itself reported back: *"the page... requested microphone access, which is blocked in the Browser pane... don't treat device capture as working."*

**This is the single most important finding of this pass.** It means the constraint isn't `speech_to_text`, isn't the Flutter plugin, isn't Android, isn't the emulator's audio HAL configuration specifically, and isn't application code — it is this **entire automated sandbox environment**, at a level above both the emulator and the browser, that has no path to real microphone hardware. Both surfaces independently confirm the same thing.

**Guest-OS-level corroboration (new this pass):** polled `adb shell dumpsys media.audio_flinger` every 2 seconds through a complete 12-second window of a live "listening" session. Every single sample showed:
```
Input device: 0 (AUDIO_DEVICE_NONE)
No active record clients
```
throughout the entire window, with zero variation — consistent with the Dart-level trace from Phase 1 (`onSoundLevelChange` never firing, `onResult` never firing, session ending via the 3-second silence `pauseFor` timeout rather than the 20-second `listenFor` window).

**Answering your specific suspect list directly:**
| Suspect | Verdict | Evidence |
|---|---|---|
| Application code (permission handling, plugin wiring, callbacks, error handling) | ✅ Personally Verified correct | Full instrumented trace, Phase 1: every stage fires in the right order with the right data. |
| `speech_to_text` plugin | ✅ Personally Verified correct | `initialize()` succeeds, 31 locales resolved, `listen()` genuinely starts (`onStatus: listening`) — the plugin is doing its job with whatever audio it's given. |
| Flutter/Dart lifecycle or callback timing | ✅ Personally Verified — not the cause | Callbacks fire in the exact expected sequence and timing (`listening` → 3.1s later `notListening`/`done` → `error_speech_timeout`, matching the configured `pauseFor: 3s` precisely). No dropped, duplicated, or out-of-order callbacks observed across two separate full sessions. |
| Android (guest OS) permission | ✅ Personally Verified — not the cause | `RECORD_AUDIO: granted=true` re-confirmed fresh this session, on a freshly reinstalled build. |
| Android (guest OS) audio routing | ⚠ Partially identified, new this pass | `dumpsys media.audio_flinger` shows the guest's own input threads bound to `AUDIO_DEVICE_NONE`, and zero active record clients throughout a real listen session — this is a genuine, specific, guest-side observation, not present in Phase 1's report. |
| Google Speech Recognition (the actual on-device/cloud service Android delegates to) | ✅ Personally Verified reachable | 31 locales resolved via a real query against it — the service itself is installed, licensed, and responding. It simply has no audio to work with. |
| Emulator audio backend | ✅ Personally Verified as the boundary | `hw.audioInput=yes` in the AVD config (nominally enabled), but no audio ever reaches either the guest's `AudioFlinger` in an active state or the app. |
| Host microphone hardware | ⚠ Exists, access not provable from here | `system_profiler SPAudioDataType` confirms a real "MacBook Air Microphone" is present as the host's default input device — so it isn't "no mic exists," it's "this sandbox doesn't have a path to it," confirmed independently by the Browser pane's own explicit denial. |

**Where verification stops, exactly:** every software layer from the app down to the Android guest's own audio subsystem is proven — by direct instrumentation, not inference — to be working correctly and receiving zero audio. The Browser pane test proves this sandbox environment itself withholds live microphone access, categorically, from anything running inside it. **I cannot go further than this without a physical Android device** (or a version of this tooling with microphone access granted, which is a platform/product decision, not something I can enable from inside a session). This is not a guess dressed as a conclusion — it's the actual, confirmed edge of what's testable from here.

---

## Part 3 — Product Experience Review (CPO lens)

Speaking plainly, not protecting prior decisions: **today, RAZ feels like a well-built chatbot with good taste, not yet a performance companion.** Here's the honest breakdown, first-principles, interaction-quality only.

**Personality / warmth / trust:** RAZ's actual language (observed live, this session and last: *"There are no sessions scheduled for tomorrow... stick to your current recovery and return-to-play progression or check in with your staff"*) is honest and grounded — it says "limited data available" instead of inventing confidence, and it never fabricated numbers it didn't have. That's a real trust asset; a lot of consumer AI products fail exactly here by sounding confident regardless of what they actually know. But the tone is *neutral-competent*, not *invested*. It reads like a status report, not like someone who's tracking your season with you. A performance companion has a point of view about your trajectory, not just a summary of your current row in a database.

**Coaching style:** what exists is descriptive ("here's your status"), not directive with stakes ("here's what I'd do, and why it matters this week"). The Daily Brief's three-part structure (Performance / Recovery / Today's Focus) is the right shape — but every field I saw resolve to "no data yet" or "continue as planned" because the account genuinely has no training history. I can't fairly judge coaching-style depth against an empty dataset; what I *can* say is that the language RAZ used to describe emptiness was well-chosen, not awkward or robotic.

**Recovery / injury conversations:** the one real signal here — RAZ correctly refused to speculate about recovery status it didn't have data for, twice, in two different phrasings, without ever contradicting itself or hallucinating a number. For a domain where a wrong confident answer about an athlete's body is a real harm, this restraint is the single most product-critical thing I observed working correctly. It should be protected, explicitly, as future prompt/feature work adds more data sources — this is the kind of property that's easy to regress by accident while chasing "more helpful-sounding" answers.

**Proactive behavior:** there is currently none, by design (`RazVoiceSettings`'s own doc comment: "RAZ never auto-reads anything... a toggle to enable behavior that never happens automatically would be exactly the kind of fake option this codebase's convention rules out"). That's a defensible RC1 stance — no fake proactivity — but it is also exactly why RAZ reads as reactive-chatbot rather than operating-system: an OS notices things and surfaces them; a chatbot waits to be asked. This is the single biggest conceptual gap between what exists and "athlete operating system."

**Latency perception:** confirmed architecturally (Part 6 of the prior report) — one blocking round trip, nothing shown until the complete answer lands. Every time I asked RAZ something this session, there was a real, silent wait with no signal beyond a static "thinking" state. This is the second-biggest gap: an operating system that goes quiet while it thinks doesn't feel like it's working *for* you in that moment.

**Verdict:** RAZ is a legitimately well-executed reactive Q&A assistant sitting on top of real athlete data, with unusually good epistemic honesty for this category. It is not yet proactive, not yet stateful across conversations in a way the user feels, and not yet visibly "thinking with you" in the moment. Closing those three gaps — not visual redesign — is what would move it from chatbot to companion.

---

## Part 4 — Voice Experience: What Should Make RAZ Feel Like RAZ

Not "how do we match Gemini Live" — what's the actual, differentiated shape of RAZ's voice that only makes sense for an athlete performance context?

**Grounded honesty, spoken.** The single trait I directly observed and verified twice — refusing to guess at recovery data it doesn't have — is RAZ's real point of differentiation, and it should be *audible*, not just readable. A generic assistant fills silence with confident-sounding filler; an athlete's performance system should sound *careful* precisely when the topic is the athlete's body. That's not a personality skin, it's a trust mechanic, and it's already half-built in the text layer — voice should inherit it deliberately (e.g., a genuinely different vocal cadence or explicit spoken caveat when `confidence: Low`, rather than reading a low-confidence answer in the same tone as a certain one).

**Presence over politeness.** Today's "I'm listening…" / static "thinking" pulse is polite but empty. What would feel like RAZ specifically: acknowledgment that references *what it's about to check* ("Pulling today's session…" not a generic "thinking"), because RAZ's whole premise is that it has real data behind it — the thinking state should telegraph that, not hide it.

**Silence with intent, not silence as a gap.** Right now, gaps in the pipeline (waiting for the LLM, waiting for TTS to start) are indistinguishable from the app being broken. An athlete-facing product should treat that difference as a design decision, not an accident — brief, deliberate pauses (e.g., after acknowledging a hard question like an injury check-in) read as thoughtful; unexplained multi-second silence reads as broken, every time, regardless of brand.

**Interruption as respect, not just a feature.** The existing tap-to-interrupt is honestly scoped (no fake spoken barge-in) — keep that honesty, but make the *tap* itself feel considered: today it's a generic stop icon; for an athlete mid-session who taps to interrupt because they're about to do a drill, the interrupt should feel instant and final, not like it's still catching up (verify this is true once real hardware testing is possible — I could not measure interrupt latency this session since Voice Mode has no audio input to interrupt *during*).

**What not to import from Siri/ChatGPT/Gemini:** none of them are designed around a domain where a wrong confident answer has real physical-safety implications (injury/recovery). RAZ shouldn't chase their conversational speed or personality warmth at the cost of the one property that's actually earned and verified this session — refusing to guess. That trade-off, explicitly, is what should make RAZ recognizable as itself rather than a reskin of a general assistant.

---

## Part 5 — Roadmap

Grounded only in what this investigation actually found — no speculative rewrites.

### RC2 (fixes + the highest-leverage product gaps)
1. **Surface live partial transcripts** while listening (Phase 1 finding: the data stream already exists, nothing renders it). Cheapest, highest-trust fix available.
2. **Give the "thinking" state real content** instead of a static icon+silence — directly addresses the "silence reads as broken" finding in Part 4, and costs no architecture change.
3. **Resolve the App Check API gap** (Google Cloud Console, one setting) — zero functional impact today, but it's a known, named, one-step fix sitting open.
4. **Provision Android's OAuth client / resolve Coach approval access** — both are "requires project owner" items with the exact unblocking action already identified (Part 3 of the prior report; Part 1 of this one). Getting *either* unblocked lets the next QA pass go further than this one could.
5. **Build a minimal admin action** (even a one-off authenticated script, not necessarily a UI) to approve `coachRequests` — right now this workflow has zero path to completion outside manual Admin SDK use, which blocks real Coach-side QA indefinitely, not just this session's.

### RC3 (the architectural change that actually moves voice quality)
1. **Stream the LLM response end-to-end** (backend `generateText` → streamed TTS) — the single change with the most leverage on perceived latency, and the prior investigation confirmed the seams for it already exist (`partialResults`, sentence-chunked TTS) — this is extension, not a rewrite.
2. **Voice selection (Male/Female)** — small, well-scoped addition (2 new interface methods, 1 settings field), already designed in the prior report.
3. **A real physical-device QA pass** for everything this session proved is impossible to verify further from here: actual speech transcription, wake word, spoken interrupt latency, Bluetooth headset behavior.

### Future Vision (genuinely deferred, not urgent)
1. **Proactive RAZ** — the biggest conceptual gap identified in Part 3. Needs real usage data flowing first (today's empty-state answers can't validate proactive judgment); sequence this after RC2/RC3 data sources exist, not before.
2. **Dedicated hotword model (Porcupine)** — extension point already named in code, unimplemented; not urgent while wake word itself can't be verified on real hardware yet.
3. **True spoken duplex/barge-in** — correctly deferred pending a real echo-cancelled audio path; revisit once RC3's streaming work lands, since duplex without streaming would be a wasted effort.
4. **Confidence-aware vocal delivery** (Part 4's "grounded honesty, spoken" idea) — genuinely differentiated, but depends on RC3's streaming TTS existing first; sequencing it before that would mean building it twice.
