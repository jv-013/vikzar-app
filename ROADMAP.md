# Vikzar Roadmap

This roadmap describes the phased path from architecture to a production-ready MVP. It is intentionally sequenced, not dated — phases are ordered by dependency, not by calendar. A phase should be substantially complete, and its decisions recorded in [DECISIONS.md](DECISIONS.md), before the next phase begins in earnest, though some overlap is expected in practice.

Each phase should update [SPECIFICATION.md](SPECIFICATION.md) as it resolves placeholders, and every feature introduced must be checked against [PRODUCT_PRINCIPLES.md](PRODUCT_PRINCIPLES.md) before it is built.

---

## Phase 0 — Foundation

Establish the project's documentation foundation: README, specification, product principles, decision log, roadmap, and changelog. No application code.

**Status:** Complete.

## Phase 1 — Architecture Definition

Define the technical architecture: state management approach, backend and cloud strategy, data model, BLE integration approach, and how the codebase will structure shared vs. adaptive UI across phone, tablet, and desktop. Record all resulting choices in [DECISIONS.md](DECISIONS.md) and reflect them in [SPECIFICATION.md](SPECIFICATION.md).

**Status:** Complete. Full blueprint recorded in [ARCHITECTURE.md](ARCHITECTURE.md); decisions logged as ADR-005 through ADR-029 in [DECISIONS.md](DECISIONS.md). Revised in **Phase 1.6** ([DECISIONS.md ADR-030](DECISIONS.md#adr-030-laptop-centric-ble-etl-and-ml-pipeline-for-mvp)) to confirm the laptop-centric MVP architecture: BLE, ETL, feature extraction, ML, and risk prediction are a laptop responsibility, not a Flutter responsibility, for MVP. This resolved the BLE-plugin-selection and AI-model/provider open questions (both now belong to the laptop pipeline, outside this repository's scope). Remaining open questions (sign-in method list, compliance requirements, CI/CD provider) are tracked in [ARCHITECTURE.md's Open Questions](ARCHITECTURE.md#open-questions) — later phases below should resolve the relevant one before proceeding.

## Phase 2 — Design Foundations

Establish the visual and interaction design system — the language that makes the application feel premium, calm, modern, and trustworthy (Principle 8), expressed responsively across form factors. Define specific breakpoint values and adaptive layout behavior for phone, tablet, and desktop, within the mechanism established in [ARCHITECTURE.md §20](ARCHITECTURE.md#20-responsive-layout-strategy) and §21–22 (design tokens and theming).

**Status: Frozen.** Phase 2A (Product Design & UX Architecture) was drafted, then went through a dedicated freeze/validation audit (one BLOCKER, five WARN, two RECOMMEND findings) before being marked **Pending Freeze**, and is now **Frozen** with every approved finding corrected. Full specification recorded in [DESIGN_SPECIFICATION.md](DESIGN_SPECIFICATION.md): brand foundation, visual language, typography/spacing/grid/colour/elevation/radius/iconography/motion systems (including a List Row component added during the freeze pass), navigation architecture (the Player/Coach workspace switcher, per [DECISIONS.md ADR-031](DECISIONS.md#adr-031-single-application-with-player-and-coach-workspace-switching)), full information architecture for both workspaces, a corrected six-screen onboarding flow, a complete screen inventory, user flows, component library, and low-fidelity wireframe descriptions for every MVP screen. Alert Crimson is approved and scoped exclusively to Critical risk states. Remaining open items (typeface licensing, bespoke icon commissioning, coach team-invite flow detail) are minor, non-blocking, and tracked in that document's Open Questions for resolution during Phase 3, not before it.

## Phase 3 — Project Initialization & Core Scaffolding

Initialize the Flutter project itself, establish the codebase structure agreed in [ARCHITECTURE.md](ARCHITECTURE.md) (feature-first folders, Riverpod, go_router, Firebase project setup), and set up the baseline navigation, theming, and platform targets (Android, iOS, macOS, Windows, Linux). Theming and navigation implementation follow the tokens and navigation architecture frozen in [DESIGN_SPECIFICATION.md](DESIGN_SPECIFICATION.md) exactly. No BLE plugin dependency is needed for this phase — the Flutter app has no BLE role at MVP (Phase 5). Resolve the CI/CD provider open question before or during this phase, and resolve [DESIGN_SPECIFICATION.md's Open Questions](DESIGN_SPECIFICATION.md#open-questions) (typeface, Alert Crimson sign-off, bespoke icons) before token implementation. Firebase project setup (Firestore collections, Security Rules, Cloud Functions) follows the schema and rules strategy in [BACKEND_SPECIFICATION.md](BACKEND_SPECIFICATION.md).

**Status: bootstrap complete; feature implementation not yet started.** The Flutter project now exists — created for Android, iOS, macOS, Windows, Linux, and Web from one codebase, with the exact `lib/` folder structure from [FLUTTER_ARCHITECTURE.md §2](FLUTTER_ARCHITECTURE.md#2-folder-structure) (`app/`, `core/`, `design_system/`, `routing/`, `services/`, `shared/`, and all 12 `features/*` folders, each with a placeholder README and the standard presentation/domain/data layer structure). The design system's tokens and both themes (light/dark, `useMaterial3: true`, the `VikzarColors`/`VikzarElevation` `ThemeExtension`s, Alert Crimson correctly scoped to Critical-risk-only per the Phase 2 freeze) are implemented, alongside `app.dart`/`bootstrap.dart`/`main.dart`, a minimal go_router with **only** `/splash` wired to a working Splash screen, `analysis_options.yaml` with strict lints, and a passing test suite. `flutter analyze` and `flutter test` pass; `flutter run` verified launching on Chrome (web). No Authentication, no Firebase project/logic, no onboarding, and no feature screens beyond Splash exist yet — those remain this phase's and Phase 4's respective work. Seven engineering decisions proposed as ADR-032 through ADR-038 ([FLUTTER_ARCHITECTURE.md §20](FLUTTER_ARCHITECTURE.md#20-architecture-decisions)) are still pending approval and formal recording in [DECISIONS.md](DECISIONS.md).

## Phase 4 — Authentication

Design and implement account creation and sign-in for Players and Coaches, on Firebase Authentication per [ARCHITECTURE.md §9](ARCHITECTURE.md#9-authentication-architecture). Resolve which sign-in methods are offered at MVP (open question in [ARCHITECTURE.md](ARCHITECTURE.md#open-questions)).

**Status: Complete** (built across **Phase 5 — Identity & Access**, **Phase 6 — Complete Onboarding Experience**, **Phase 7 — Player Home, Coach Home & Application Shell**, **Phase 8A — Production Firebase Infrastructure**, and **Phase 8B — Production Firebase Backend Integration** in implementation sequence; the roadmap phase number and the implementation phase labels diverged here and are not reconciled retroactively, per this project's append-only decision history). Firebase Authentication is implemented as a passwordless email + 6-digit code flow, **locked as a permanent product decision at Phase 8A** — no password, magic link, phone auth, Google Sign-In, or Apple Sign-In will be added ([ARCHITECTURE.md](ARCHITECTURE.md#open-questions)'s sign-in-method question resolved; [DECISIONS.md ADR-043](DECISIONS.md#adr-043-passwordless-email-otp-authentication-replaces-email--password)), against the real, connected **`vikzar-prod`** Firebase project (Android, iOS, macOS, Web — [DECISIONS.md ADR-050](DECISIONS.md#adr-050-production-firebase-connection-requires-the-project-owners-own-credentials--cannot-be-completed-by-an-agent), superseding the placeholder era of [ADR-042](DECISIONS.md#adr-042-placeholder-firebase-configuration-for-pre-project-development)); OTP code *verification* remains a documented placeholder pending real delivery/verification infrastructure ([ADR-044](DECISIONS.md#adr-044-placeholder-otp-verification-pending-real-backend-delivery)). Session persistence and the workspace/role model ([DECISIONS.md ADR-031](DECISIONS.md#adr-031-single-application-with-player-and-coach-workspace-switching)) are in place. Full authentication and onboarding routing now covers Splash → Auth → Workspace Selection → complete Player and Coach onboarding flows (now genuinely persisted to Firestore on completion) → **a real application shell**: Player Home and Coach Home (Phase 7), with bottom navigation, a profile badge/sheet consolidating account actions and workspace switching, Settings, Profile, and a Notification Center streaming real (currently empty) data. Session/sensor/team-monitoring data on both Home screens remains an honest placeholder — no Bluetooth/ETL/ML pipeline exists yet, so **Phases 6–11 below now build additively on top of these screens** (populating Home's placeholders with real data, adding Timeline/History/Live Monitoring/Team/Alerts' full detail) rather than creating them from nothing.

**Phase 8A — Production Firebase Infrastructure (2026-07-20):** the project owner ran `flutterfire configure` against `vikzar-prod`, covering all four Firebase-supported Flutter platforms present in this repository (Android, iOS, macOS, Web). `lib/firebase_options.dart` is committed and wired into `bootstrap.dart`; the placeholder configuration is deleted. `firebase_storage` added alongside the existing Auth/Firestore SDK wrappers. Enabling the Authentication/Firestore/Storage *products* in the Firebase Console has not been confirmed and remains the one soft blocker — real Firebase calls fail gracefully, not crash, until then. This phase also corrected product-description wording repository-wide that incorrectly framed Vikzar as a medical/injury-prevention product — it is a sports performance and biomechanics analytics platform; the existing "not a medical diagnosis" disclaimers were already correct and untouched.

**Phase 8B — Production Firebase Backend Integration (2026-07-20):** every remaining placeholder backend implementation replaced with real Firestore reads/writes, per [DECISIONS.md ADR-051](DECISIONS.md#adr-051-client-direct-firestore-writes-for-workspace-team-and-onboarding-state-mvp-self-service-model) (client-direct writes for workspace/team/onboarding state — an MVP self-service model, secured by `firestore.rules`, standing in for the schema's originally Cloud-Function-gated design until real Cloud Functions exist). Onboarding completion, profile edits, team creation/joining, Become-a-Coach requests, and notifications all persist to and read from Firestore now; the Phase 7-flagged local-state account-leak is fixed ([ADR-052](DECISIONS.md#adr-052-local-device-state-is-scoped-per-firebase-uid)); offline persistence is enabled. `firestore.rules`/`storage.rules`/`firestore.indexes.json` are written and referenced from `firebase.json` but **not deployed**. Email OTP delivery/verification remains untouched and still a documented placeholder ([ADR-044](DECISIONS.md#adr-044-placeholder-otp-verification-pending-real-backend-delivery)).

## Phase 5 — Direct Device Connectivity (BLE) — Future Capability, Not MVP

**This phase is deferred and is not part of the MVP path.** For MVP, all Bluetooth discovery, pairing, and connection to Vikzar hardware (Smart Pod, EMG Thigh Band) is performed entirely by the laptop pipeline, not the Flutter application ([DECISIONS.md ADR-030](DECISIONS.md#adr-030-laptop-centric-ble-etl-and-ml-pipeline-for-mvp); [ARCHITECTURE.md §7](ARCHITECTURE.md#7-ble-architecture)). Phases 6 onward do not depend on this phase, and it is not scheduled as part of the MVP sequence. It remains here as a placeholder for a documented future capability — direct phone-to-wearable BLE connection, as described in [ARCHITECTURE.md's Future Evolution section](ARCHITECTURE.md#future-evolution) — to be scheduled only if and when that capability is prioritized. The Flutter application's only MVP-relevant device capability (read-only device status and coach-managed assignment) is delivered under Phase 11, not this phase. See also "Out of Scope for This Roadmap" below.

## Phase 6 — Live Sensor Streaming (Display)

Design and implement real-time display, within the Flutter application, of already-processed live session data synchronized from the laptop pipeline via Firebase — not streaming from a directly-connected device, per Phase 5's deferral. Build against the live session data model and read contract in [BACKEND_SPECIFICATION.md §8](BACKEND_SPECIFICATION.md#8-live-session-data-model) and [§22](BACKEND_SPECIFICATION.md#22-flutter-read-contract).

## Phase 7 — Live Team Monitoring

Design and implement the coach-facing real-time, multi-player monitoring view, reading from the `teams/{teamId}/liveMonitoring` collection defined in [BACKEND_SPECIFICATION.md §1.4](BACKEND_SPECIFICATION.md#1-complete-firestore-schema). Treated as core MVP functionality, not a later enhancement.

## Phase 8 — Session History

Design and implement historical session records for Players (own sessions) and Coaches (team sessions), per the read contract in [BACKEND_SPECIFICATION.md §22](BACKEND_SPECIFICATION.md#22-flutter-read-contract).

## Phase 9 — Player Profiles & Team Management

Design and implement player profile data and coach-facing team/roster management, against the ownership models in [BACKEND_SPECIFICATION.md §4–§6](BACKEND_SPECIFICATION.md#4-player-ownership-model).

## Phase 10 — AI-Powered Player Insights

Design and implement the Flutter-side presentation of AI-generated player insights and training intelligence (alerts and reports) produced by the laptop-based ML/Risk Engine pipeline, against the integration seam defined in [ARCHITECTURE.md §14](ARCHITECTURE.md#14-ai-analysis-pipeline) and the concrete alert and report models in [BACKEND_SPECIFICATION.md §12–§13](BACKEND_SPECIFICATION.md#12-alert-model). This phase is Flutter-only (display/consumption); the ML pipeline itself is outside this repository's scope, per ADR-030.

## Phase 11 — Device Management & Notifications

Design and implement Flutter-side device management (viewing status, coach-managed assignment — no pairing flow, per Phase 5's deferral) and the notification system for Players and Coaches, per the device ownership model and notification triggers in [BACKEND_SPECIFICATION.md §7](BACKEND_SPECIFICATION.md#7-device-ownership-model) and [§18](BACKEND_SPECIFICATION.md#18-notification-triggers).

## Phase 12 — Cross-Platform Hardening

Dedicated pass across all target platforms (Android phone/tablet, iPhone, iPad, macOS, Windows, Linux) to ensure adaptive layouts genuinely take advantage of larger displays — particularly for Coach workflows — rather than merely resizing phone layouts.

## Phase 13 — MVP Stabilization & Production Readiness

Hardening pass across the full MVP feature set: reliability of the laptop pipeline's data delivery and Flutter's live-data display, data integrity of session history, security and privacy review, and overall readiness for production release. Regulatory/compliance requirements (e.g. HIPAA, GDPR, or a sport-specific data standard) must be confirmed and, if applicable, reflected in the security architecture ([ARCHITECTURE.md §19](ARCHITECTURE.md#19-security-architecture)) no later than this phase. The proposed data retention windows in [BACKEND_SPECIFICATION.md §20](BACKEND_SPECIFICATION.md#20-data-retention-strategy) must be confirmed against that compliance review before production.

---

## Out of Scope for This Roadmap

The following are acknowledged as future directions but are explicitly not part of the path to MVP, per [SPECIFICATION.md](SPECIFICATION.md):

- Additional user roles beyond Player and Coach (e.g. clinician, club administrator)
- Flutter Web as a shipped target (architecture remains compatible, but Web is not built at MVP)
- Any hardware beyond the Smart Pod and EMG Thigh Band
- **Direct phone-to-wearable BLE connection from the Flutter application** (Phase 5, above). Confirmed as MVP architecture by [DECISIONS.md ADR-030](DECISIONS.md#adr-030-laptop-centric-ble-etl-and-ml-pipeline-for-mvp): all Bluetooth connectivity, ETL, feature extraction, ML inference, and risk prediction are a laptop-pipeline responsibility for MVP. This is a documented future capability, not an MVP feature — see [ARCHITECTURE.md's Future Evolution section](ARCHITECTURE.md#future-evolution) for how it can be added later without a backend redesign.

Introducing any of the above requires a recorded decision in [DECISIONS.md](DECISIONS.md) and an update to this roadmap.
