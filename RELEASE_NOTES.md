# Vikzar — Release Notes

## v1.0.0-rc.1 (2026-08-09)

First release candidate to carry a real, release-signed Android APK and a live, production-verified RAZ conversational upgrade.

### RAZ — conversational AI coach
- **Streaming answers, live in production.** `razAsk` (revision `razask-00003-mad`) streams Gemini's response sentence-by-sentence via Firebase's streaming-callable protocol. Verified twice against real production traffic — confirmed via server-side logs (`llm_stream_started` → `raz_ask_succeeded`), not just a successful reply.
- **Mode-aware phrasing.** The client now sends `mode: "voice" | "text"` on every `razAsk` call; the backend adjusts response length/detail accordingly (voice stays to one or two short sentences; text can go longer). The underlying reasoning never changes — only how much of it gets said.
- **Real memory.** RAZ now writes to `users/{uid}/razMemories/{topic}` when an athlete mentions a body part alongside a genuine concern word (e.g. "my right knee has felt tight"). Verified live in production this release: a real Firestore document was created from a real conversation, with the athlete's own words quoted back accurately.
- **Coaching personality.** Verified live: RAZ answers with a short, specific coaching follow-up ("Is the tightness constant, or does it mainly show up during specific movements?") rather than a generic LLM paragraph, and states plainly when it doesn't have enough data rather than guessing.
- **Male/Female voice selection.** Settings exposes a Male/Female picker built from the platform's real installed TTS voices — never invented. On devices where the platform can't confidently report a voice's gender (most stock Android), the picker correctly stays hidden rather than showing a guess.

### Release infrastructure
- **First real Android release signing identity for this app.** A new upload keystore (`android/keystore/vikzar-release.jks`) was generated this release; the release build type now signs with it instead of the debug keystore. See "Known Issues" — this keystore's SHA-1 is not yet registered with Google Sign-In's OAuth client, so Google Sign-In does not yet work on release-signed builds until that's done.
- **Fixed a deployment-discovery bug** that made every Cloud Function invisible to `firebase deploy`'s discovery step: a stray, committed `functions.json` file at the repo root shadowed Node's module resolution for the `functions/` directory. Removed; discovery now correctly finds all 20 functions.

## Prior — RC1 (uncommitted foundation work)
Auth (Google Sign-In, Email Link, Sign in with Apple entitlement), Coach/Player onboarding, team creation/join-by-invite, sessions, live monitoring, notifications, and Firestore security hardening (closed a privilege-escalation gap in team join/create rules) — implemented in earlier sessions, still pending its own commit. See `RC1_FINAL_AUDIT.md`, `RC1_FINAL_VALIDATION_REPORT.md`, `RC1_KNOWN_LIMITATIONS.md` for that work's own record.
