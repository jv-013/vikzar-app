# Vikzar Architecture & Product Decision Record

This document is the log of every significant product, UX, architecture, or engineering decision made on Vikzar. It exists so that future contributors understand not just what was decided, but why — and what alternatives were weighed and rejected.

Every future phase of work must record decisions here at the time they are made. A decision does not need to be technical to belong in this log — product scope and UX direction decisions belong here too.

## How to Add a Decision

Append a new entry using the template below. Do not edit or delete past entries to reflect a new decision — instead, add a new entry and, if it supersedes a prior one, set the prior entry's Status to `Superseded` and reference the new Decision ID.

```
### ADR-XXX: <Short Title>

- **Decision ID:** ADR-XXX
- **Decision:** <What was decided, stated plainly>
- **Reason:** <Why, including which product principle(s) it serves>
- **Alternatives Considered:** <What else was considered, and why it was not chosen>
- **Status:** Proposed | Accepted | Superseded | Rejected
- **Date:** <YYYY-MM-DD>
```

Statuses:

- **Proposed** — under discussion, not yet acted on.
- **Accepted** — in effect and should be followed.
- **Superseded** — no longer in effect; see the referenced newer ADR.
- **Rejected** — considered and explicitly not adopted, kept for record.

---

## Decisions

### ADR-001: Documentation-First Foundation Before Implementation

- **Decision ID:** ADR-001
- **Decision:** Establish README, SPECIFICATION, PRODUCT_PRINCIPLES, DECISIONS, ROADMAP, and CHANGELOG documents before initializing the Flutter project or writing any application code.
- **Reason:** Ensures architecture and product scope are agreed upon and recorded before implementation begins, rather than discovered ad hoc during coding. Supports Principle 9 (decisions must be documented) and Principle 10 (long-term maintainability).
- **Alternatives Considered:** Initializing the Flutter project first and documenting alongside/after implementation. Rejected because it risks implementation decisions being made without an agreed foundation, and documentation being deprioritized once code exists.
- **Status:** Accepted
- **Date:** 2026-07-19

### ADR-002: Single Flutter Codebase Across Phone, Tablet, and Desktop

- **Decision ID:** ADR-002
- **Decision:** Vikzar is built as a single Flutter codebase targeting Android phones/tablets, iPhone, iPad, macOS, Windows, and Linux, using responsive and adaptive layouts rather than platform-specific implementations wherever practical. The architecture must remain compatible with adding Flutter Web later, even though Web is not an MVP target.
- **Reason:** Coach workflows (e.g. Live Team Monitoring) benefit from larger displays, and player workflows are primarily mobile — a single adaptive codebase serves both without duplicating logic across separate apps. Supports long-term maintainability (Principle 10) and avoids overengineering separate platform apps (Principle 7).
- **Alternatives Considered:** Separate mobile-only app with a distinct web/desktop coach dashboard. Rejected at this stage as it would duplicate business logic and increase long-term maintenance burden; may be revisited if adaptive Flutter proves insufficient for a given platform.
- **Status:** Accepted
- **Date:** 2026-07-19

### ADR-003: MVP User Roles Limited to Player and Coach

- **Decision ID:** ADR-003
- **Decision:** The MVP supports exactly two user roles: Player and Coach. Additional roles such as clinician or club administrator are explicitly out of scope for MVP.
- **Reason:** Keeps MVP scope focused on the two roles with the clearest, most direct value (Principle 4) and avoids feature/role bloat before the core product is validated (Principle 1).
- **Alternatives Considered:** Including a clinician/medical role at MVP. Rejected for MVP to preserve scope discipline; may be introduced in a later phase once Player/Coach workflows are validated.
- **Status:** Accepted
- **Date:** 2026-07-19

### ADR-004: Live Team Monitoring Is In Scope for MVP

- **Decision ID:** ADR-004
- **Decision:** Live Team Monitoring (a coach's real-time view of live sensor data across multiple players during a session) is included in the MVP feature set, not deferred to a later release.
- **Reason:** Directly serves player safety during live sessions, which is the core value proposition of Vikzar (Principle 2, Principle 3). Deferring it would leave the MVP without its most safety-critical capability.
- **Alternatives Considered:** Shipping an MVP with only individual/player-facing live streaming and deferring the multi-player coach view to a later phase. Rejected because it would materially weaken the safety value of the MVP for coaches, the role most positioned to act on live data across a team.
- **Status:** Accepted
- **Date:** 2026-07-19

### ADR-005: Overall Application Architecture — Pragmatic Layered Architecture

- **Decision ID:** ADR-005
- **Decision:** Presentation / domain / data layering, feature-first, without a use-case class per operation.
- **Reason:** Preserves testability and Firebase/BLE isolation without the boilerplate of strict Clean Architecture, which is disproportionate to MVP team size. See [ARCHITECTURE.md §1](ARCHITECTURE.md#1-overall-application-architecture).
- **Alternatives Considered:** Strict Clean Architecture (full use-case layer); classic MVC.
- **Status:** Accepted
- **Date:** 2026-07-19

### ADR-006: Folder Structure — Feature-First

- **Decision ID:** ADR-006
- **Decision:** `lib/features/<feature>/{data,domain,presentation}` per feature, with small shared `core/`, `theme/`, `routing/`, `services/` folders. See [ARCHITECTURE.md §2](ARCHITECTURE.md#2-folder-structure).
- **Reason:** Keeps each feature self-contained and navigable at multi-year, multi-feature scale.
- **Alternatives Considered:** Layer-first top-level structure; flat/unstructured layout.
- **Status:** Accepted
- **Date:** 2026-07-19

### ADR-007: State Management — Riverpod

- **Decision ID:** ADR-007
- **Decision:** Riverpod is the state management solution across the app. See [ARCHITECTURE.md §3](ARCHITECTURE.md#3-state-management-strategy).
- **Reason:** Its stream-based providers are a direct fit for BLE and Firestore realtime data, the app's dominant technical characteristic; also doubles as the DI mechanism (ADR-009).
- **Alternatives Considered:** BLoC/Cubit; Provider; GetX.
- **Status:** Accepted
- **Date:** 2026-07-19

### ADR-008: Navigation Architecture — go_router

- **Decision ID:** ADR-008
- **Decision:** go_router with role-based shell routes (Player, Coach) and centralized auth/role redirect guarding. See [ARCHITECTURE.md §4](ARCHITECTURE.md#4-navigation-architecture).
- **Reason:** Declarative, Web-compatible (per ADR-002), first-class shell/nested route and redirect support needed for role-based, adaptive navigation.
- **Alternatives Considered:** Imperative Navigator 1.0; auto_route.
- **Status:** Accepted
- **Date:** 2026-07-19

### ADR-009: Dependency Injection — Riverpod Providers Only

- **Decision ID:** ADR-009
- **Decision:** No separate DI framework; Riverpod providers serve as the dependency injection mechanism. See [ARCHITECTURE.md §5](ARCHITECTURE.md#5-dependency-injection-strategy).
- **Reason:** One mechanism for state and dependencies avoids redundant systems solving the same problem (Principle 1).
- **Alternatives Considered:** `get_it` service locator; manual constructor wiring.
- **Status:** Accepted
- **Date:** 2026-07-19

### ADR-010: Repository Pattern for All External Data Access

- **Decision ID:** ADR-010
- **Decision:** Repository interfaces in each feature's domain layer, implementations in the data layer, wrapping Firebase and BLE access. See [ARCHITECTURE.md §6](ARCHITECTURE.md#6-repository-pattern).
- **Reason:** Isolates volatile external dependencies (Firebase, BLE) from business/UI logic; enables testing without a network or real hardware.
- **Alternatives Considered:** Direct SDK calls from controllers; a generic shared CRUD repository base class.
- **Status:** Accepted
- **Date:** 2026-07-19

### ADR-011: BLE Architecture — Central Service with Per-Device Protocol Adapters

- **Decision ID:** ADR-011
- **Decision:** A single `BleService` wraps the BLE plugin; a `DeviceProtocol` adapter per device type parses raw data. See [ARCHITECTURE.md §7](ARCHITECTURE.md#7-ble-architecture).
- **Reason:** Concentrates the architecture's highest technical risk (BLE plugin/platform behavior, especially on desktop) behind one seam, and makes adding future hardware additive.
- **Alternatives Considered:** Direct BLE plugin calls scattered across features; a hardcoded single-device parser.
- **Status:** Superseded — see [ADR-030](#adr-030-laptop-centric-ble-etl-and-ml-pipeline-for-mvp). This Flutter-side design does not apply to MVP, where BLE is a laptop responsibility; it remains the intended design for the Future Evolution path (direct phone-to-wearable BLE) documented in ARCHITECTURE.md.
- **Date:** 2026-07-19

### ADR-012: Cloud Architecture — Firebase as the Complete Backend Platform

- **Decision ID:** ADR-012
- **Decision:** Firebase (Auth, Firestore, Storage, Cloud Functions, Cloud Messaging) is the backend platform. See [ARCHITECTURE.md §8](ARCHITECTURE.md#8-cloud-architecture).
- **Reason:** Confirmed by explicit product direction (Firestore, Firebase Storage, and Cloud Functions were named directly); realtime primitives fit Live Team Monitoring, and an integrated platform minimizes operational burden for a small team.
- **Alternatives Considered:** Custom backend/API; alternative BaaS platform (e.g. Supabase).
- **Status:** Accepted
- **Date:** 2026-07-19

### ADR-013: Authentication Architecture — Firebase Auth with Firestore-Stored Role

- **Decision ID:** ADR-013
- **Decision:** Firebase Authentication for identity; Player/Coach role stored as a field on the Firestore user profile document, not in Auth custom claims. See [ARCHITECTURE.md §9](ARCHITECTURE.md#9-authentication-architecture).
- **Reason:** Simplest mechanism sufficient for MVP; custom claims add a Cloud Function and token-refresh moving part with no corresponding current-stage benefit.
- **Alternatives Considered:** Firebase Auth with role in custom claims; a custom, non-Firebase auth service.
- **Status:** Accepted
- **Date:** 2026-07-19

### ADR-014: Firestore Data Model — Structured Collections with Raw Data Routed to Storage

- **Decision ID:** ADR-014
- **Decision:** Separate `users`, `teams`, `sessions`, `devices`, `insights`, and per-user `notifications` collections; session documents hold summary metrics only, with raw high-frequency sensor data routed to Firebase Storage. See [ARCHITECTURE.md §10](ARCHITECTURE.md#10-firestore-data-model).
- **Reason:** Matches each data shape to the store suited to it, avoiding Firestore document-size/write-rate limits and keeping Security Rules scoped per resource.
- **Alternatives Considered:** Storing raw sensor samples directly in Firestore; a single denormalized per-user document.
- **Status:** Accepted
- **Date:** 2026-07-19

### ADR-015: Firebase Storage Usage — Raw Session Data and User Images

- **Decision ID:** ADR-015
- **Decision:** Firebase Storage holds raw session sensor exports and user-facing images, namespaced by owner/session. See [ARCHITECTURE.md §11](ARCHITECTURE.md#11-firebase-storage-usage).
- **Reason:** Purpose-built for large binary data; keeps Firestore documents small (ADR-014); avoids a second storage vendor.
- **Alternatives Considered:** Base64-encoding binary data into Firestore fields; a non-Firebase object storage provider.
- **Status:** Accepted
- **Date:** 2026-07-19

### ADR-016: Cloud Functions Responsibilities — Minimal, Trigger-Driven

- **Decision ID:** ADR-016
- **Decision:** Cloud Functions are scoped to exactly four responsibilities: AI pipeline triggering, push notification dispatch, server-side invariant enforcement, and (if needed) scheduled maintenance. See [ARCHITECTURE.md §12](ARCHITECTURE.md#12-cloud-functions-responsibilities).
- **Reason:** Reserves server-side execution for what genuinely requires it (trust boundaries, cross-user effects), keeping the client capable and the Functions codebase small and auditable.
- **Alternatives Considered:** Routing all business logic through Cloud Functions ("thin client"); no Cloud Functions at all.
- **Status:** Accepted. **Refined by [ADR-030](#adr-030-laptop-centric-ble-etl-and-ml-pipeline-for-mvp):** responsibility #1's wording ("AI pipeline triggering") is clarified to "validating and ingesting already-computed data" — Cloud Functions never trigger or perform computation. The four-item scope itself is unchanged.
- **Date:** 2026-07-19

### ADR-017: Notification Architecture — FCM Push with Firestore-Backed In-App Record

- **Decision ID:** ADR-017
- **Decision:** Firebase Cloud Messaging for push, triggered by Cloud Functions, paired with a `users/{uid}/notifications` Firestore subcollection for durable in-app history. See [ARCHITECTURE.md §13](ARCHITECTURE.md#13-notification-architecture).
- **Reason:** Push alone risks missed safety-relevant alerts; in-app alone fails timeliness. Both are needed together.
- **Alternatives Considered:** Push-only, no in-app record; in-app-only, no OS push.
- **Status:** Accepted
- **Date:** 2026-07-19

### ADR-018: AI Analysis Pipeline — Cloud-Orchestrated Seam, Model Unspecified

- **Decision ID:** ADR-018
- **Decision:** The app uploads session data and consumes results from an `insights` collection populated via a Cloud Function-triggered pipeline; the specific model/provider behind the trigger is not decided. See [ARCHITECTURE.md §14](ARCHITECTURE.md#14-ai-analysis-pipeline).
- **Reason:** Satisfies the "generated in the cloud" product requirement while avoiding inventing an undiscussed technology choice (model/provider).
- **Alternatives Considered:** On-device inference; naming a specific model/provider now.
- **Status:** Superseded — see [ADR-030](#adr-030-laptop-centric-ble-etl-and-ml-pipeline-for-mvp). The "cloud-orchestrated, model unspecified" framing is replaced: the pipeline runs on the laptop, not behind a Cloud Function trigger to unspecified cloud compute. The "generated in the cloud" product wording this decision was satisfying has also been corrected in SPECIFICATION.md §7.8.
- **Date:** 2026-07-19

### ADR-019: Offline Strategy — Firestore Built-In Persistence + Local Session Buffering

- **Decision ID:** ADR-019
- **Decision:** Rely on Firestore's built-in offline persistence for structured data, and buffer in-progress session data locally with sync-on-reconnect. No custom sync engine. See [ARCHITECTURE.md §15](ARCHITECTURE.md#15-offline-strategy).
- **Reason:** Solves the actual bounded risk (losing live session data) using platform-provided mechanisms, without building general-purpose offline infrastructure the product doesn't need.
- **Alternatives Considered:** Custom offline-first sync engine with conflict resolution; no offline handling.
- **Status:** Accepted
- **Date:** 2026-07-19

### ADR-020: Error Handling — Typed Result/Failure Pattern

- **Decision ID:** ADR-020
- **Decision:** Repository/service methods return a typed `Result`/`Failure` construct rather than throwing across layers; presentation maps failures to calm, plain-language messaging. See [ARCHITECTURE.md §16](ARCHITECTURE.md#16-error-handling).
- **Reason:** Ensures failures are handled consistently and never surfaced as raw technical errors, supporting a calm, trustworthy product feel.
- **Alternatives Considered:** Ad hoc exception catching in the UI; a single generic catch-all.
- **Status:** Accepted
- **Date:** 2026-07-19

### ADR-021: Logging Strategy — AppLogger Abstraction with Firebase Crashlytics

- **Decision ID:** ADR-021
- **Decision:** A thin `AppLogger` interface, backed by Crashlytics in production; no sensitive/health data in log output. See [ARCHITECTURE.md §17](ARCHITECTURE.md#17-logging-strategy).
- **Reason:** Gives production visibility while creating one enforced seam to keep health-adjacent data out of logs; reuses the already-adopted platform.
- **Alternatives Considered:** Unabstracted print/platform logging; a third-party observability service.
- **Status:** Proposed — Crashlytics adoption is this document's recommendation, not yet independently confirmed at the product level.
- **Date:** 2026-07-19

### ADR-022: Analytics Strategy — Firebase Analytics, Minimal Event Set

- **Decision ID:** ADR-022
- **Decision:** Firebase Analytics instrumented for a small, purposeful set of key events; no sensor/health values ever sent as analytics data. See [ARCHITECTURE.md §18](ARCHITECTURE.md#18-analytics-strategy).
- **Reason:** Answers real product questions (onboarding completion, feature adoption) without over-instrumentation, and keeps a firm privacy line from health data.
- **Alternatives Considered:** Exhaustive interaction tracking; no analytics at MVP.
- **Status:** Proposed — Analytics adoption is this document's recommendation, not yet independently confirmed at the product level.
- **Date:** 2026-07-19

### ADR-023: Security Architecture — Security Rules as Primary Enforcement

- **Decision ID:** ADR-023
- **Decision:** Firestore/Storage Security Rules, keyed off the Firestore-stored role (ADR-013), are the mandatory, server-enforced access control layer; client-side restriction is a UX layer only, never a substitute. See [ARCHITECTURE.md §19](ARCHITECTURE.md#19-security-architecture).
- **Reason:** Client-only enforcement is trivially bypassed and unacceptable for health-adjacent player data.
- **Alternatives Considered:** Client-only access restriction; a custom authorization backend in front of Firebase.
- **Status:** Accepted
- **Date:** 2026-07-19

### ADR-024: Responsive Layout Strategy — Breakpoint-Based Adaptive Layout

- **Decision ID:** ADR-024
- **Decision:** A single adaptive widget tree per screen, rearranging by compact/medium/expanded breakpoints; Coach screens designed expanded-first, Player screens compact-first. See [ARCHITECTURE.md §20](ARCHITECTURE.md#20-responsive-layout-strategy).
- **Reason:** Directly implements ADR-002's single-codebase requirement and Spec §6's mandate that coach workflows genuinely benefit from larger displays.
- **Alternatives Considered:** Separate screen implementations per platform; one fixed layout uniformly scaled.
- **Status:** Accepted
- **Date:** 2026-07-19

### ADR-025: Design System Strategy — Material 3 with Custom Tokens

- **Decision ID:** ADR-025
- **Decision:** Material 3 as the structural/adaptive-component foundation, customized via Vikzar-specific design tokens. See [ARCHITECTURE.md §21](ARCHITECTURE.md#21-design-system-strategy).
- **Reason:** Inherits adaptive component behavior for free while retaining full control over the premium/trustworthy visual identity Principle 8 requires.
- **Alternatives Considered:** Fully custom design system; unmodified Material 3.
- **Status:** Accepted
- **Date:** 2026-07-19

### ADR-026: Theme Architecture — Centralized, Token-Driven Theme

- **Decision ID:** ADR-026
- **Decision:** Centralized token classes generate light and dark `ThemeData` from day one, exposed reactively; no hardcoded styling in feature widgets. See [ARCHITECTURE.md §22](ARCHITECTURE.md#22-theme-architecture).
- **Reason:** Prevents visual drift across a multi-year codebase and avoids a costly dark-mode retrofit later, for low upfront cost now.
- **Alternatives Considered:** Hardcoded inline styling; centralized but light-mode-only theme.
- **Status:** Accepted
- **Date:** 2026-07-19

### ADR-027: Future Scalability Strategy — Extension Points, Not Speculative Infrastructure

- **Decision ID:** ADR-027
- **Decision:** Rely on extension points already present in ADR-005 through ADR-026 (protocol adapters, role field, feature modules, repository interfaces) rather than building dedicated scalability infrastructure now. See [ARCHITECTURE.md §23](ARCHITECTURE.md#23-future-scalability-strategy).
- **Reason:** Every plausible near-term extension already has a low-cost path; further speculative infrastructure (multi-tenant, generalized plugin system, on-device ML) has no confirmed requirement yet.
- **Alternatives Considered:** Proactively building for anticipated future needs now; no forward consideration at all.
- **Status:** Accepted
- **Date:** 2026-07-19

### ADR-028: Testing Strategy — Unit-Heavy Pyramid with Mandatory Safety-Flow Coverage

- **Decision ID:** ADR-028
- **Decision:** Test pyramid weighted toward unit tests using the Firebase Local Emulator Suite and a fake `BleService`; Authentication and Live Team Monitoring each require at least one integration-level test. See [ARCHITECTURE.md §24](ARCHITECTURE.md#24-testing-strategy).
- **Reason:** Matches test investment to engineering economics and to the product's actual safety risk profile, rather than a uniform or e2e-heavy default.
- **Alternatives Considered:** Heavy end-to-end testing across all platforms as the primary strategy; minimal/no automated testing.
- **Status:** Accepted. **Refined by [ADR-030](#adr-030-laptop-centric-ble-etl-and-ml-pipeline-for-mvp):** the "fake `BleService`" testing detail no longer applies to MVP, since Flutter has no BLE dependency; test data for laptop-originated collections is seeded directly into the Firebase emulator instead. The pyramid strategy and mandatory safety-flow coverage are unchanged.
- **Date:** 2026-07-19

### ADR-029: CI/CD Strategy — Staged Pipeline with Gated Backend Deployment

- **Decision ID:** ADR-029
- **Decision:** Automated analysis/test/build on every change and merge; Security Rules and Cloud Functions deployment as a separate, explicitly triggered step, never automatic. Specific CI provider not yet chosen. See [ARCHITECTURE.md §25](ARCHITECTURE.md#25-cicd-strategy).
- **Reason:** Matches automation aggressiveness to risk — client build/test automation is safe to run continuously, but backend deployment affects live data access immediately and broadly.
- **Alternatives Considered:** Fully automatic continuous deployment including backend; no CI/CD automation.
- **Status:** Accepted — pipeline pattern is decided; specific tooling is an open question pending version control setup.
- **Date:** 2026-07-19

### ADR-030: Laptop-Centric BLE, ETL, and ML Pipeline for MVP

- **Decision ID:** ADR-030
- **Decision:** For the MVP, all Bluetooth communication with Vikzar hardware (Smart Pod, EMG Thigh Band), ETL, feature extraction, machine learning inference, and injury risk prediction are performed exclusively by a laptop-based pipeline external to the Flutter codebase. The Flutter application does not connect to wearable devices directly during the MVP and has no BLE dependency of any kind. Flutter consumes exclusively already-processed data — session summaries, live monitoring ticks, alerts, and reports — synchronized via Firebase, exactly as specified in [BACKEND_SPECIFICATION.md](BACKEND_SPECIFICATION.md). This decision resolves the discrepancy identified between [BACKEND_SPECIFICATION.md](BACKEND_SPECIFICATION.md)'s laptop-centric system diagram and this repository's Phase 1 architecture (ARCHITECTURE.md §7's original Flutter-side `BleService` and §14's originally-unspecified AI pipeline compute location), flagged as Open Question 1 in BACKEND_SPECIFICATION.md and unresolved at the close of Phase 1.5.
- **Reason:** This is the explicitly approved MVP system architecture (Sensors → Bluetooth → Laptop → ETL → Feature Extraction → ML Pipeline → Risk Engine → Firebase → Flutter Application), confirmed directly for this phase. Independently of that direction, concentrating all BLE connectivity and sensor-derived computation on one purpose-built machine is architecturally sound: a laptop's BLE central role reliably holds many simultaneous peripheral connections (an entire team's devices during Live Team Monitoring) in a way phone-based BLE central roles typically do not match; it keeps the Flutter application free of the single most platform-fragile dependency (BLE plugin behavior varies materially by OS) across all seven target platforms; and it makes the non-negotiable constraint that Firebase never performs ETL/ML unambiguous to enforce, since no sensor-derived computation exists anywhere in the Flutter or Firebase layers to begin with.
- **Alternatives Considered:** Retaining the original Phase 1 design (Flutter-side `BleService` connecting directly to hardware, with an unspecified cloud-side compute step for ML) — rejected as it does not match the approved architecture and leaves the "where does ETL/ML run" question open rather than closed. A hybrid approach (laptop pipeline for supervised team sessions, direct phone BLE for unsupervised solo sessions, both active at MVP) — rejected for MVP as unnecessary complexity (Principle 7: doubles the trusted data-origination paths the backend must validate, and doubles the surfaces needing ETL/ML logic), but explicitly preserved as a well-defined future capability (see ARCHITECTURE.md's "Future Evolution" section) rather than discarded, since BACKEND_SPECIFICATION.md's ingestion contract was already designed to be principal-agnostic and does not require backend redesign to support it later.
- **Status:** Accepted
- **Date:** 2026-07-19

**Supersedes:** [ADR-011](#adr-011-ble-architecture--central-service-with-per-device-protocol-adapters) (Flutter-side `BleService`), [ADR-018](#adr-018-ai-analysis-pipeline--cloud-orchestrated-seam-model-unspecified) (cloud-orchestrated AI pipeline with unspecified compute location). **Refines:** [ADR-016](#adr-016-cloud-functions-responsibilities--minimal-trigger-driven) (Cloud Functions responsibility wording), [ADR-028](#adr-028-testing-strategy--unit-heavy-pyramid-with-mandatory-safety-flow-coverage) (BLE-fake testing detail). **Documented in full in:** [ARCHITECTURE.md §7](ARCHITECTURE.md#7-ble-architecture), [§12](ARCHITECTURE.md#12-cloud-functions-responsibilities), [§14](ARCHITECTURE.md#14-ai-analysis-pipeline), [§15](ARCHITECTURE.md#15-offline-strategy), and [ARCHITECTURE.md's Future Evolution section](ARCHITECTURE.md#future-evolution).

### ADR-031: Single Application with Player and Coach Workspace Switching

- **Decision ID:** ADR-031
- **Decision:** Vikzar is one Flutter application, not separate Player and Coach applications. A signed-in account can hold both a Player workspace and a Coach workspace simultaneously, and switches between them instantly, in-app, without logout or re-authentication — an "Instagram account switching"-style interaction. The active workspace determines the navigation shell and screen set shown, per [DESIGN_SPECIFICATION.md §13](DESIGN_SPECIFICATION.md#13-navigation-architecture). One consistent visual/design language is maintained across both workspaces.
- **Reason:** A single codebase serving both workspaces avoids duplicating navigation, theming, and component infrastructure (consistent with [ADR-002](#adr-002-single-flutter-codebase-across-phone-tablet-and-desktop)'s single-codebase rationale), and reflects the real-world need for one person (most commonly a coach who also trains, or a club administrator role in future) to move fluidly between perspectives without the friction of separate accounts or app installs. Treating the switch as lightweight as a tab change, not an account change, keeps onboarding and daily use frictionless (Principle 5).
- **Alternatives Considered:** Two separate applications (Player app, Coach app) — rejected as it duplicates infrastructure and prevents the fluid switching this decision requires. A single application with a single fixed role per account, no switching — rejected as it does not serve the case of one person needing both perspectives, and was explicitly ruled out by product direction for this phase.
- **Status:** Accepted — both the UX/product decision and, as of the Phase 2 freeze review, the data-model mechanism.

**Data model (resolved at the Phase 2 freeze review):** `users/{uid}.role` (a single required enum) is replaced by:

```
users/{uid}
  workspaces: {
    player?: { teamId: string | null }   // present only if this account has a Player workspace
    coach?:  { teamIds: string[] }       // present only if this account has a Coach workspace
  }
  defaultWorkspace: "player" | "coach"   // set once at onboarding; used only as the
                                          // fallback on a device with no locally cached
                                          // "last used workspace" state
```

- **`workspaces` is a structured object (map), not an array of strings.** The presence of the `player` or `coach` key *is* the "has this workspace" signal — no separate boolean flag needed. Each key carries its own workspace-scoped team reference(s), resolving an ambiguity the old flat `teamIds` array had: a single array couldn't distinguish "the team I play for" from "the team(s) I coach" for an account holding both workspaces. Under this shape, that distinction is structural, not inferred.
- **`defaultWorkspace` replaces `role`.** Set once at onboarding (Workspace Selection, [DESIGN_SPECIFICATION.md §19.1](DESIGN_SPECIFICATION.md#191-onboarding-flow)), rarely changed thereafter, used only as the fallback workspace on a device that has no local record of which workspace this account last used.
- **No `activeWorkspace` field in Firestore.** Which workspace a user is *currently viewing* is local, per-device app state (a Riverpod provider backed by local device storage), never written to the server. The server's responsibility is knowing what a user is *entitled to* (`workspaces`); which tab they currently have open is a client concern, not a synchronization concern. This avoids a Firestore write on every switch, avoids a multi-device consistency problem (two devices open in different workspaces would otherwise fight over a single server-side "active" pointer), and is a better technical match for "switching should feel instant, like changing a tab" (Principle 5) than a server round-trip would be.
- **Security Rules impact: minimal.** Re-verified against [BACKEND_SPECIFICATION.md §15](BACKEND_SPECIFICATION.md#15-security-rules-strategy): authorization is already resource-scoped (`teams/{teamId}.coachIds` for coach access, `sessions/{sessionId}.playerId` for player access), not account-role-scoped — the old `role` field was mainly a client-side routing convenience, not a security boundary. This change is therefore a client-model and schema correction, not a Security Rules rewrite.
- **Why resolved now, not deferred:** no user data exists yet — this is a zero-cost correction today and a real migration after Phase 4 ships. Resolving it before Phase 4 (Authentication) begins, as originally flagged, avoids that cost entirely.

This supersedes the `role` field definition in [BACKEND_SPECIFICATION.md §1.5](BACKEND_SPECIFICATION.md#1-complete-firestore-schema), which is updated to match.
- **Date:** 2026-07-19 (updated 2026-07-19, Phase 2 freeze review)

> **Numbering note:** [FLUTTER_ARCHITECTURE.md §20](FLUTTER_ARCHITECTURE.md#20-architecture-decisions) reserves ADR-032 through ADR-038 for seven Phase 3 decisions still awaiting approval — they are not yet recorded here. To avoid colliding with that reserved range, the Phase 5 ADRs below resume numbering at **ADR-039**. Whenever ADR-032–038 are formally approved and recorded, they slot in at their original numbers ahead of these; no renumbering of ADR-039 onward is needed since the reserved range is already accounted for.

### ADR-039: Colour Philosophy Freeze — Oxide Rose as Primary Action, Mineral Blue as Secondary Informational Accent

- **Decision ID:** ADR-039
- **Decision:** Vikzar's primary action/interactive colour is **Oxide Rose** (buttons, active states, focus rings, primary CTAs) and its secondary informational accent is **Mineral Blue** (charts, informational badges, non-primary interactive detail). This swaps the roles Phase 2A/Phase 4 had implicitly assumed (Mineral Blue as primary). Alert Crimson remains reserved exclusively for critical safety events. No gradients, no decorative colour use, no neon — colour exists only to communicate meaning, per the Permanent Design Principle recorded this phase in [DESIGN_SPECIFICATION.md §3](DESIGN_SPECIFICATION.md#3-design-philosophy).
- **Reason:** Explicit product direction this phase: the interface should read as "carved from darkness," with colour appearing only with purpose. Oxide Rose (a warm, muted rose-red) reads as an intentional, singular call to action against Plum Black in a way a cooler, more ambient blue does not — it is more distinguishable from informational/status colour and better reserved for "the one thing to do on this screen." Mineral Blue moving to secondary/informational keeps it available for charts and status detail without competing with the primary action colour for attention.
- **Alternatives Considered:** Leaving Mineral Blue as primary (the Phase 2A/4 status quo) — rejected per explicit direction this phase. Introducing a third, new accent colour for primary actions rather than repurposing an existing frozen colour — rejected as it would grow the palette rather than sharpen the existing one, contrary to the Permanent Design Principle's "colour exists only to communicate meaning" constraint.
- **Status:** Accepted
- **Date:** 2026-07-19

**Flagged, not resolved:** Oxide Rose now double-duties as both the Primary Action colour and the Elevated/High risk-status colour in the frozen Risk & Status Semantic Colours table ([DESIGN_SPECIFICATION.md §8](DESIGN_SPECIFICATION.md#8-colour-system)). No risk-display UI exists yet in the codebase (out of scope for this phase), so the collision has no present consequence, but it must be resolved — likely by giving risk status its own colour — before any risk-display screen is built. **Documented in full in:** [DESIGN_SPECIFICATION.md §3](DESIGN_SPECIFICATION.md#3-design-philosophy) and [§8](DESIGN_SPECIFICATION.md#8-colour-system).

### ADR-040: Single-Screen Sign-In-or-Create-Account Authentication Flow

- **Decision ID:** ADR-040
- **Decision:** Vikzar's authentication screen is a single email/password form with one "Continue" action — there is no separate Sign In / Sign Up toggle or screen. On submit, the app attempts sign-in first; if it fails because no account exists for that email (`user-not-found`, or `invalid-credential` on Firebase Auth SDK versions that no longer distinguish "wrong password" from "no such user"), the app creates the account instead. A wrong password for an existing account still surfaces as "incorrect password" rather than silently attempting (and failing) account creation.
- **Reason:** Reduces the identity flow to the minimum number of decisions a user makes before reaching the product (Principle 5: frictionless onboarding), and removes an entire screen/branch of UI for a distinction (new vs. returning user) the product does not need the user to declare — the backend can determine it. Generous spacing and a single calm form also serve the Permanent Design Principle recorded this phase.
- **Alternatives Considered:** Separate Sign In and Sign Up screens/tabs (the conventional pattern) — rejected as an unnecessary extra decision point for MVP scope. Attempting account creation first, falling back to sign-in — rejected because it inverts the more common case (returning users) into the slower path, and because Firebase Auth's `email-already-in-use` error is a less reliable signal across SDK versions than `user-not-found`/`invalid-credential` is for the chosen order.
- **Status:** Accepted
- **Date:** 2026-07-19

**Documented in full in:** [`auth_repository_impl.dart`](lib/features/auth/data/repositories/auth_repository_impl.dart), [DESIGN_SPECIFICATION.md §19.1](DESIGN_SPECIFICATION.md#191-onboarding-flow).

### ADR-041: Workspace Selection Writes Only Local Device State in the MVP Bootstrap

- **Decision ID:** ADR-041
- **Decision:** The Workspace Selection screen built this phase (Player or Coach) writes only the local, on-device active-workspace pointer (via `ActiveWorkspaceStore`/`activeWorkspaceProvider`, per [ADR-031](#adr-031-single-application-with-player-and-coach-workspace-switching)) when the user makes a selection. It does not call any Cloud Function and does not write to `users/{uid}.workspaces` or `users/{uid}.defaultWorkspace` in Firestore.
- **Reason:** [BACKEND_SPECIFICATION.md](BACKEND_SPECIFICATION.md) specifies `workspaces`/`defaultWorkspace` as Cloud-Function-written, not client-writable — that mutation belongs to the join-team/create-team onboarding flow ([ADR-038](FLUTTER_ARCHITECTURE.md#20-architecture-decisions), proposed), which this phase is explicitly scoped to *not* build. Confining this phase's Workspace Selection screen to the local-only pointer keeps it fully functional as a navigation waypoint (choosing which placeholder to view next) without reaching ahead into onboarding's responsibilities or writing Firestore data through a path that will be replaced once onboarding exists.
- **Alternatives Considered:** Having Workspace Selection call a stub/placeholder Cloud Function to write `workspaces` directly — rejected as it would require inventing onboarding's data-writing contract ahead of building onboarding itself, risking a mismatch once the real onboarding flow is designed. Deferring Workspace Selection entirely until onboarding ships — rejected because this phase's Identity Flow (Launch → Splash → Authentication → Workspace Selection → onboarding placeholder) explicitly requires the screen to exist and be navigable now.
- **Status:** Accepted
- **Date:** 2026-07-19

**Documented in full in:** [`workspace_selection_screen.dart`](lib/features/workspace/presentation/screens/workspace_selection_screen.dart), [`active_workspace_controller.dart`](lib/features/workspace/presentation/controllers/active_workspace_controller.dart).

### ADR-042: Placeholder Firebase Configuration for Pre-Project Development

- **Decision ID:** ADR-042
- **Decision:** The app initializes Firebase using well-formed but fake `FirebaseOptions` (`PlaceholderFirebaseOptions`, in [`firebase_options_placeholder.dart`](lib/firebase_options_placeholder.dart)) rather than real project credentials, since no Firebase project exists yet. Every Firebase-touching call is routed through the `Result`/`Failure` architecture ([ADR-020](#adr-020-error-handling--typed-resultfailure-pattern)) so a call failing against this placeholder configuration — which every call will, since no backend actually exists behind it — surfaces as a calm, mapped user-facing failure rather than a crash or an unhandled exception.
- **Reason:** Lets the full authentication/navigation architecture (screens, routing, state management, error handling) be built, tested, and demonstrated end-to-end before a real Firebase project is provisioned, without any code path assuming success is possible. This phase's manual verification confirmed the intended behavior directly: submitting the auth form against the placeholder configuration fails gracefully with "Something went wrong. Please try again." and the router correctly keeps the user on the Auth screen rather than misrouting on a failed sign-in.
- **Alternatives Considered:** Blocking this phase until a real Firebase project is provisioned — rejected as an unnecessary sequencing dependency; the identity/navigation architecture does not require a live backend to be built or tested correctly. Mocking `FirebaseAuth`/`FirebaseFirestore` at the app-bootstrap level instead of using real (placeholder-configured) SDK instances — rejected as it would leave `Firebase.initializeApp` itself, and the SDKs' real error-handling paths, unexercised.
- **Status:** Accepted — until real per-flavor Firebase projects are provisioned per [ADR-037](FLUTTER_ARCHITECTURE.md#20-architecture-decisions) (proposed), at which point this is superseded.
- **Date:** 2026-07-19

**Documented in full in:** [`firebase_options_placeholder.dart`](lib/firebase_options_placeholder.dart), [`bootstrap.dart`](lib/app/bootstrap.dart).

### ADR-043: Passwordless Email OTP Authentication Replaces Email + Password

- **Decision ID:** ADR-043
- **Decision:** Vikzar's identity gate is passwordless: a user enters their email, receives a 6-digit one-time code, and enters it to complete sign-in. There is no password, confirm-password, forgot-password, or password-complexity concept anywhere in the product. As before ([ADR-040](#adr-040-single-screen-sign-in-or-create-account-authentication-flow)), the user never declares whether they're a new or returning user — that is resolved silently after code verification.
- **Reason:** Explicit product direction this phase. A typed 6-digit code is a strictly smaller cognitive load than remembering, choosing, or resetting a password, and removes an entire category of support burden (password reset flows, complexity-rule friction) before it exists. Matches the calm, minimal-decision onboarding character established since Phase 2's freeze review.
- **Alternatives Considered:** Retaining email/password (the Phase 5 status quo) — rejected per explicit direction. Firebase Auth's native passwordless mechanism, email-link sign-in (`sendSignInLinkToEmail`) — rejected because it requires the user to leave the app and tap a link (and, on web, requires Dynamic Links / a hosted redirect domain that doesn't exist for this project), a fundamentally different and heavier interaction than typing a 6-digit code in place.
- **Status:** Accepted
- **Date:** 2026-07-19

**Locked at Phase 8A:** explicit product direction confirmed this is a *permanent* decision, not a placeholder pending a future sign-in-method addition — email-only, 6-digit Email OTP, with no passwords, magic links, phone authentication, Google Sign-In, or Apple Sign-In, ever. Nothing in this phase changed the implementation (still the placeholder verification from ADR-044 below); this note exists so the permanence is discoverable from this ADR directly, not only from the phase brief that stated it.

**Supersedes:** [ADR-040](#adr-040-single-screen-sign-in-or-create-account-authentication-flow)'s password-based mechanism — that ADR's "single continuous flow, no separate sign-up path" *principle* carries forward unchanged; only the credential type changes. **Documented in full in:** [`auth_repository.dart`](lib/features/auth/domain/repositories/auth_repository.dart), [`auth_controller.dart`](lib/features/auth/presentation/controllers/auth_controller.dart), [`auth_screen.dart`](lib/features/auth/presentation/screens/auth_screen.dart), [DESIGN_SPECIFICATION.md §19.1](DESIGN_SPECIFICATION.md#191-onboarding-flow).

### ADR-044: Placeholder OTP Verification Pending Real Backend Delivery

- **Decision ID:** ADR-044
- **Decision:** `AuthRepositoryImpl.verifyOtp` accepts any syntactically valid 6-digit code — there is no real code generation, email delivery, or server-side verification this phase. Underneath, it signs in (or transparently creates an account) against Firebase Auth's real email/password mechanism using a secret deterministically derived from the email address (SHA-256 of a fixed app-level string plus the lowercased, trimmed email) — a value never shown to, typed by, or reconstructable by the user, and never exposed by any public method signature above the repository's private implementation.
- **Reason:** Real 6-digit email OTP requires server-side infrastructure (a Cloud Function to generate, email, and verify a time-limited single-use code) that this phase explicitly does not build (no Firestore, no Cloud Functions). Rather than block the entire identity/onboarding UI on that infrastructure, this mechanism lets the full flow — including real Firebase session creation, real UID assignment, and real cross-restart persistence — work end-to-end today, on the same placeholder Firebase project already established by [ADR-042](#adr-042-placeholder-firebase-configuration-for-pre-project-development). Reusing Firebase's real email/password SDK methods (rather than, say, `signInAnonymously`) specifically preserves stable per-email UIDs, which [ADR-031](#adr-031-single-application-with-player-and-coach-workspace-switching)'s "one account, multiple workspaces" model depends on.
- **Alternatives Considered:** Blocking Phase 6 until real Cloud Function-backed OTP delivery exists — rejected as an unnecessary sequencing dependency, exactly the reasoning ADR-042 already established for placeholder Firebase itself. Using `signInAnonymously` per OTP attempt — rejected because it mints a new, unrelated UID every time, breaking "the same account across sessions and devices," which real OTP delivery will require just as much as this placeholder does.
- **Status:** Accepted — **not safe for production as implemented.** Before real users authenticate against a real Firebase project, this placeholder verification must be replaced by a real, server-issued, time-limited, single-use code checked by a Cloud Function; recorded here as an explicit blocker for a future phase, not a permanent shortcut.
- **Date:** 2026-07-19

**Documented in full in:** [`auth_repository_impl.dart`](lib/features/auth/data/repositories/auth_repository_impl.dart) (see its `verifyOtp` doc comment for the full reasoning, restated in code so it isn't only discoverable here).

### ADR-045: Typography Freeze — Nohemi (Headings) / Inter (Body)

- **Decision ID:** ADR-045
- **Decision:** Two typefaces, each with one job: **Nohemi** for the four heading-weight type-scale steps (Display, Headline, Title Large, Title) and **Inter** for the four body/UI steps (Body Large, Body, Label, Caption). Inter is implemented this phase via the `google_fonts` package (previously deferred at Phase 4 pending exactly this confirmation). Nohemi's font asset is not sourced this phase — headings render with the platform default system font at a single, documented swap point until a licensed Nohemi font file is supplied.
- **Reason:** Explicit product direction this phase, resolving the Phase 4/5 Open Question left by [ARCHITECTURE.md](ARCHITECTURE.md)/[DESIGN_SPECIFICATION.md](DESIGN_SPECIFICATION.md)'s original single-typeface "Inter, tentative" recommendation. A dedicated heading face gives Display/Headline-scale text (onboarding hero copy, screen titles) a more deliberate, "instrument-panel" character than reusing the body face at a larger size.
- **Alternatives Considered:** Using Inter for both roles now, swapping to Nohemi for headings later — rejected as it would look "finished" today and risk the still-open Nohemi gap being silently forgotten; leaving headings unset (system default) is a more honest, visibly-provisional signal that this half of the decision isn't complete. Sourcing Nohemi's font file automatically via a web fetch — rejected: Nohemi is a licensed commercial typeface (Pangram Pangram), and downloading/bundling a font binary from an unverified source without the user's explicit provisioning is both a licensing risk and outside what a phase brief can authorize on its own.
- **Status:** Accepted — Inter is fully in effect; Nohemi is frozen as the decision but pending its font asset.
- **Date:** 2026-07-19

**Documented in full in:** [`vikzar_text_theme.dart`](lib/design_system/theme/vikzar_text_theme.dart) (the Nohemi swap point's exact location), [DESIGN_SPECIFICATION.md §5](DESIGN_SPECIFICATION.md#5-typography-system).

### ADR-046: Onboarding Is Router-Gated as a Subtree, with Local Per-Workspace Completion Tracking

- **Decision ID:** ADR-046
- **Decision:** The router's redirect logic gates an entire onboarding **subtree** (`/onboarding/{workspace}/**`) rather than one exact path: once a workspace is chosen (locally, per [ADR-031](#adr-031-single-application-with-player-and-coach-workspace-switching)/[ADR-041](#adr-041-workspace-selection-writes-only-local-device-state-in-the-mvp-bootstrap)), the user may navigate freely among that workspace's own onboarding steps via ordinary `context.go()` calls; the redirect only forces a jump to that workspace's entry step when arriving from *outside* the subtree entirely. A new local-device store (`OnboardingProgressStore`, mirroring `ActiveWorkspaceStore`'s pattern) records, per workspace, whether this device has already completed that workspace's onboarding steps; if so, the entry step becomes the Onboarding Complete screen instead of Level, so a returning user isn't forced through Level/Profile/Permissions again every cold start.
- **Reason:** This corrects a routing defect discovered while building this phase: Phase 5's `routeDestinationProvider` checked Firestore's `workspaces` field being non-empty *before* ever consulting the local active-workspace pointer, and forcibly redirected to the exact single "onboarding placeholder" path on every recomputation. Since no Cloud Function exists to populate Firestore's `workspaces` field (by design, per ADR-041), that check was always true for every account, and forcing an exact-path redirect on every `redirect` invocation — including ones triggered by the onboarding screens' own forward navigation — meant a user could never actually leave the Workspace Selection screen. Phase 5 never surfaced this because its scope stopped at a single placeholder screen reachable directly from Workspace Selection; building this phase's real multi-step flow on top of the old logic would have reproduced the same dead end one level deeper, at every step boundary.
- **Alternatives Considered:** Keeping per-step exact-path redirect targets and updating `routeDestinationProvider`'s state on every step's "Continue" — rejected as needless churn (a `RouteDestination` recomputation, a `RouterRefreshNotifier` tick, and a full router `redirect` re-evaluation on every single onboarding field change) for information the router doesn't need at that granularity; a subtree gate expresses "is this user authorized to be anywhere in this workspace's onboarding" correctly without tracking exactly which step they're on. Persisting onboarding progress to Firestore instead of locally — rejected as out of scope (no Cloud Functions this phase) and unnecessary: which *screen* a user last saw is a device/UI concern, not an authorization concern, matching the reasoning ADR-031/ADR-041 already established for the active-workspace pointer itself.
- **Status:** Accepted
- **Date:** 2026-07-19

**Documented in full in:** [`route_guards.dart`](lib/routing/route_guards.dart), [`app_router.dart`](lib/routing/app_router.dart), [`onboarding_progress_store.dart`](lib/services/local_storage/onboarding_progress_store.dart).

### ADR-047: The Profile Badge Is the Single Entry Point for Account-Level Actions

- **Decision ID:** ADR-047
- **Decision:** The standalone workspace-switcher pill originally specified in [DESIGN_SPECIFICATION.md §13](DESIGN_SPECIFICATION.md#13-navigation-architecture) is replaced by a **profile badge** — an avatar plus the active workspace's label, in the same top-left app-bar position — that opens a single bottom sheet covering every account-level action: Profile, Settings, Notifications, Help, About, Sign Out, and, conditionally, either **Switch Workspace** (accounts holding more than one workspace) or **Become a Coach** (Player-only accounts). A single-workspace account — the common case, since every new account starts Player-only — sees the badge with no chevron and no "Switch Workspace" row at all: no dropdown affordance, no hint that a second workspace concept exists.
- **Reason:** Explicit product direction this phase, and a genuine simplification: the original design implied two adjacent top-bar controls both opening "a sheet about your account" (a workspace switcher and a separate Profile nav destination) once Profile became a real screen this phase. One entry point, shape-shifting by what the account actually holds, is fewer concepts for a user to learn and matches [UX Principle 5](PRODUCT_PRINCIPLES.md)'s "switching should feel as light as changing a tab" — the same badge a single-workspace user already understands ("that's me") is exactly where a dual-workspace user finds switching, once they have something to switch between.
- **Alternatives Considered:** Keeping the workspace-switcher pill and adding a separate always-visible profile icon — rejected as the redundant-adjacent-controls problem described above. Showing "Switch Workspace" (disabled/greyed) even for single-workspace accounts, as an affordance hint — rejected per this phase's explicit instruction: "no chevron, no indication that Coach exists" for a Player-only account; a greyed-out option is still an indication.
- **Status:** Accepted
- **Date:** 2026-07-19

**Documented in full in:** [`profile_badge.dart`](lib/features/profile/presentation/widgets/profile_badge.dart), [`profile_sheet.dart`](lib/features/profile/presentation/widgets/profile_sheet.dart), [`workspace_switch_sheet.dart`](lib/features/profile/presentation/widgets/workspace_switch_sheet.dart), [DESIGN_SPECIFICATION.md §13](DESIGN_SPECIFICATION.md#13-navigation-architecture).

### ADR-048: A Single Parameterized App Shell, Not a Player/Coach Scaffold Pair

- **Decision ID:** ADR-048
- **Decision:** The application shell (bottom navigation + top bar) is one `AppShellScaffold(workspace:)` widget, driven by a per-workspace nav-item list, rather than separate `PlayerShellScaffold`/`CoachShellScaffold` widgets as originally sketched in [FLUTTER_ARCHITECTURE.md §4](FLUTTER_ARCHITECTURE.md#4-navigation). Each workspace gets its own `StatefulShellRoute.indexedStack` (Player: Home/Timeline/History/Profile; Coach: Home/Live/Team/Alerts/Profile) so tab state is preserved per workspace, but both are built by the same scaffold widget.
- **Reason:** [DESIGN_SPECIFICATION.md §13](DESIGN_SPECIFICATION.md#13-navigation-architecture) already states the intent directly: "one consistent design language across both workspaces... the item sets differ, the visual system does not." A single parameterized widget expresses that literally; two near-identical scaffold classes would drift out of sync over time (a spacing tweak applied to one and forgotten in the other) in exactly the way a single shared component prevents. `StatefulShellRoute.indexedStack` (go_router's standard mechanism for bottom-nav-with-preserved-state) is used over a plain `ShellRoute`, matching this phase's "premium animations... never jarring" requirement — switching tabs must not reset scroll position or rebuild from scratch.
- **Alternatives Considered:** Two separate scaffold classes, per the original architecture sketch — rejected for the drift risk above, and because nothing about the two workspaces' *chrome* (as opposed to their content) actually differs enough to justify two implementations. A single `StatefulShellRoute` with a dynamic branch list computed from the active workspace — rejected as unnecessarily clever; go_router's route tree is meant to be static, and two separate `StatefulShellRoute` entries (one per workspace) is the more conventional, more debuggable shape.
- **Status:** Accepted
- **Date:** 2026-07-19

**Documented in full in:** [`app_shell_scaffold.dart`](lib/routing/shells/app_shell_scaffold.dart), [`app_router.dart`](lib/routing/app_router.dart).

### ADR-049: Become a Coach Is a Placeholder Request Flow, With No Real Approval

- **Decision ID:** ADR-049
- **Decision:** "Become a Coach" — reachable from a Player-only account's profile sheet — collects Coaching Level, Club/Academy Name, Current Role, and an optional Organization Email, then ends at a submitted-for-review confirmation screen. **No Cloud Function, no Firestore write, and no other mechanism exists to act on this request.** An account cannot reach dual-workspace status through this flow in this codebase today — that state is reachable only via Riverpod provider overrides in tests.
- **Reason:** Explicit product direction this phase: "Coach access is NOT automatically available... every new account begins as Player only." Building the complete request-collection UI now — while being honest that nothing receives it yet — follows the same placeholder pattern already established for Connect Pod and Create/Join Team in onboarding ([DECISIONS.md ADR-046](#adr-046-onboarding-is-router-gated-as-a-subtree-with-local-per-workspace-completion-tracking)'s neighbors): the UI is real and complete, the backend seam is honestly absent, not faked.
- **Alternatives Considered:** Auto-granting Coach access on submission (setting the local `onboardingCompletionProvider` flag directly) so the dual-workspace UI could be demonstrated end-to-end without test overrides — rejected outright; this phase is explicit that "No real Coach approval" exists, and simulating a grant would misrepresent what the product actually does today, which is worse than an honestly-limited demo path. Building a review/approval admin surface this phase to make the flow end-to-end — rejected as entirely out of scope (no backend, no Cloud Functions, no admin tooling anywhere in this codebase).
- **Status:** Accepted
- **Date:** 2026-07-19

**Documented in full in:** [`become_a_coach_screen.dart`](lib/features/workspace/presentation/screens/become_a_coach_screen.dart), [`become_a_coach_complete_screen.dart`](lib/features/workspace/presentation/screens/become_a_coach_complete_screen.dart).

### ADR-050: Production Firebase Connection Requires the Project Owner's Own Credentials — Cannot Be Completed by an Agent

- **Decision ID:** ADR-050
- **Decision:** Connecting this codebase to a real Firebase project is done via the FlutterFire CLI (`flutterfire configure`), which requires an authenticated `firebase login` session tied to the project owner's own Google/Firebase account and an interactive choice of which Firebase project to use (existing or newly created). Neither step can be performed by an agent working in this repository — there is no credential to reuse and no default project to safely assume. [`firebase-tools`](https://www.npmjs.com/package/firebase-tools) and [`flutterfire_cli`](https://pub.dev/packages/flutterfire_cli) are installed and ready (Phase 8A); the placeholder configuration (`lib/firebase_options_placeholder.dart`, per [ADR-042](#adr-042-placeholder-firebase-configuration-for-pre-project-development)) remains the active configuration until the project owner runs the commands below themselves.
- **Reason:** Guessing or fabricating a Firebase project ID, API key, or app ID — even structured to look plausible — would be strictly worse than an honest placeholder: it could silently point the app at a project the user doesn't control, or simply fail in a way that's harder to diagnose than "this is a documented placeholder." Phase 8A's own instruction is explicit on this point: "If my intervention is required (login, project selection, bundle IDs, SHA fingerprints, Apple configuration, etc.), stop and tell me exactly what command I need to run. Do not guess values."
- **What the project owner needs to run**, from the repository root:
  1. `firebase login` — opens a browser to authenticate with the Google account that owns (or will own) the Firebase project.
  2. `export PATH="$PATH":"$HOME/.pub-cache/bin"` (if `flutterfire` is not already on `PATH` — add to `.zshrc`/`.bash_profile` to persist).
  3. `flutterfire configure` — interactively select or create a Firebase project, then select platforms (Android, iOS, macOS, Web — the four Firebase officially supports for Flutter; Windows and Linux, both present in this repository from `flutter create`, are not Firebase-supported targets and are correctly left unconfigured). This generates `lib/firebase_options.dart`, `android/app/google-services.json`, `ios/Runner/GoogleService-Info.plist`, and `macos/Runner/GoogleService-Info.plist`, and wires the Android Gradle Google Services plugin automatically.
  4. In `lib/app/bootstrap.dart`: change the import from `firebase_options_placeholder.dart` to `firebase_options.dart`, and `PlaceholderFirebaseOptions.currentPlatform` to `DefaultFirebaseOptions.currentPlatform`. Delete `lib/firebase_options_placeholder.dart`.
  5. In the **Firebase Console**, enable the products this app depends on: Authentication (Email/Link provider is the closest built-in primitive to this project's locked passwordless-OTP decision, [ADR-043](#adr-043-passwordless-email-otp-authentication-replaces-email--password) — the actual OTP delivery/verification mechanism remains a later phase's work, per that ADR and [ADR-044](#adr-044-placeholder-otp-verification-pending-real-backend-delivery)), Cloud Firestore (start in production mode; Security Rules are a later phase's work), and Cloud Storage.
- **Alternatives Considered:** Proceeding with a fabricated-but-plausible-looking project ID/API key so the repository "looks complete" — rejected outright per the explicit instruction above and this project's established pattern of flagging blockers honestly rather than papering over them (the same reasoning as [ADR-044](#adr-044-placeholder-otp-verification-pending-real-backend-delivery)'s placeholder OTP verification). Attempting to run `flutterfire configure` non-interactively with assumed defaults — rejected: there is no safe default for "which Firebase project," and doing so risks silently attaching this codebase to the wrong project if one happens to already be selected in the local Firebase CLI's state.
- **Status:** Accepted — **completed 2026-07-20.** The project owner ran `flutterfire configure` against a real project (`vikzar-prod`), covering Android, iOS, macOS, and Web. `lib/firebase_options.dart` (generated), `android/app/google-services.json`, `ios/Runner/GoogleService-Info.plist`, and `macos/Runner/GoogleService-Info.plist` are committed; the Android Gradle Google Services plugin was wired automatically. Steps 1–4 above are done — `bootstrap.dart` now calls `DefaultFirebaseOptions.currentPlatform`, and `firebase_options_placeholder.dart` is deleted. **Step 5 (enabling Authentication/Firestore/Storage products in the Firebase Console) has not been confirmed** — Firestore/Storage reads and writes, and any real sign-in attempt, will fail with a Firebase-side error (e.g. `permission-denied` or a "product not enabled" error) until each product is turned on in the console; every repository still maps that to a calm `Failure` state, never a crash, so this is a soft blocker, not a broken build.
- **Date:** 2026-07-20

**Documented in full in:** [`firebase_options.dart`](lib/firebase_options.dart), [`bootstrap.dart`](lib/app/bootstrap.dart), [`firebase.json`](firebase.json).

### ADR-051: Client-Direct Firestore Writes for Workspace, Team, and Onboarding State (MVP Self-Service Model)

- **Decision ID:** ADR-051
- **Decision:** [BACKEND_SPECIFICATION.md](BACKEND_SPECIFICATION.md) originally restricted `users/{uid}.workspaces`, `users/{uid}.defaultWorkspace`, and the full `teams/{teamId}` document (beyond `name`/`ageGroup`) to Cloud-Function-only writes, so a server process could validate them (e.g. checking a team invite code before granting a `coach` workspace). This phase revises that: the Flutter Application now writes these fields directly, self-scoped (a user may only write their own `users/{uid}` document; a coach creating a team may only self-claim `coachIds == [request.auth.uid]` at creation; a player joining a team may only create their own `teams/{teamId}/members/{uid}` document), secured by the Security Rules in `firestore.rules` rather than server-side validation. The same applies to the new `playerProfile`/`coachProfile` fields ([BACKEND_SPECIFICATION.md §1.5](BACKEND_SPECIFICATION.md#15-usersuid)) and to the new `coachRequests/{requestId}` collection ([§1.12](BACKEND_SPECIFICATION.md#112-coachrequestsrequestid)).
- **Reason:** No Cloud Functions codebase exists in this repository — every phase through 8A has scoped Cloud Functions out entirely, consistent with [ARCHITECTURE.md](ARCHITECTURE.md)'s laptop-and-Cloud-Function-centric design being a later-phase concern. Phase 8B's explicit instruction is to replace placeholder repositories with genuine Firestore persistence for onboarding completion, workspace ownership, team creation/joining, and Become-a-Coach requests — with no Cloud Functions in scope. Leaving these fields Cloud-Function-only would make Phase 8B undoable without either fabricating a Cloud Functions deployment out of scope, or leaving onboarding, team creation, and profile data as unpersisted placeholders indefinitely, which is exactly what this phase is meant to end. Self-scoped, Rules-secured client writes are a standard, legitimate Firestore MVP pattern precisely for this situation: they are only as safe as the Rules that gate them, but they do not require inventing a Cloud Functions deployment ahead of when the project is ready to build one.
- **What this does *not* change:** anything already restricted to Cloud-Function-only writes for genuinely safety-derived or computed data — `careerStats`, `sessions`, `sessions/live/current`, `reports`, `teams/{teamId}/liveMonitoring/*`, and alert *creation* (only `acknowledged`/`acknowledgedBy`/`acknowledgedAt` were ever client-writable) all remain exactly as originally specified. This ADR only opens self-scoped identity/onboarding/team-membership fields that have no safety implication and no session/sensor data pipeline behind them yet.
- **Consequences accepted for MVP:** a coach "Join Team" invite code is, for now, simply the `teamId` itself shared out-of-band — there is no separate invite-code validation, since that validation was the exact Cloud-Function responsibility this ADR defers. A malicious client could, in principle, write an arbitrary `coachIds` array to a team they don't own if Rules were misconfigured; this is mitigated by writing `firestore.rules` precisely (self-claim-only at creation, immutable `coachIds` thereafter for non-members) and is flagged here so a future phase's real Cloud-Function-backed invite/approval flow is understood as tightening, not redesigning, this model.
- **Alternatives Considered:** Building a minimal Cloud Functions deployment this phase to preserve the original server-validated model — rejected as out of Phase 8B's explicit scope ("replace placeholder backend implementations," not "add a new backend runtime") and disproportionate to what onboarding/team-creation actually needs at MVP scale. Leaving `workspaces`/`defaultWorkspace`/team creation as local-only placeholders (the Phase 7/8A status quo) — rejected per Phase 8B's explicit "No more placeholder repositories. No fake users. No fake profiles. No fake workspaces." instruction.
- **Status:** Accepted — MVP only, expected to be tightened once real Cloud Functions exist.
- **Date:** 2026-07-20

**Supersedes:** [ADR-041](#adr-041-workspace-selection-writes-only-local-device-state-in-the-mvp-bootstrap)'s reasoning for *why* workspace state stayed local (that Cloud-Function-only writes made it unreachable) — the "active workspace is always local device state" *conclusion* is unaffected and remains permanent per [ADR-031](#adr-031-single-application-with-player-and-coach-workspace-switching); only *ownership* (`workspaces`, `defaultWorkspace`) is now a genuine client Firestore write. **Documented in full in:** [BACKEND_SPECIFICATION.md §1.2, §1.3, §1.5, §1.12, §15](BACKEND_SPECIFICATION.md#1-complete-firestore-schema), [`firestore.rules`](firestore.rules), [`user_repository_impl.dart`](lib/shared/repositories/user_repository_impl.dart), [`team_repository_impl.dart`](lib/features/team/data/repositories/team_repository_impl.dart).

### ADR-052: Local Device State Is Scoped Per Firebase UID

- **Decision ID:** ADR-052
- **Decision:** `ActiveWorkspaceStore` (and any future purely-local, per-account cache) now namespaces its `SharedPreferences` keys by the currently authenticated Firebase UID (e.g. `active_workspace::{uid}` rather than a single fixed `active_workspace` key). A `currentUidProvider`, derived from `authStateProvider`, supplies the active UID; reading or writing local workspace state with no authenticated UID is a programming error, not a silent no-op. Signing out clears the in-memory `activeWorkspaceProvider` state (it does not delete the stored value — the next sign-in with the same UID on the same device correctly restores it).
- **Reason:** Phase 7 shipped `ActiveWorkspaceStore` with one fixed, unscoped storage key. On a shared device, signing out of Account A and into Account B would read Account A's cached active-workspace pointer for Account B — the exact leakage Phase 8B flags: "Local state must always belong to the authenticated Firebase UID. Signing out must never leak workspace state into another account." Namespacing by UID is the direct fix; clearing (not scoping) in-memory state on sign-out prevents a stale value from a previous session flashing before the next account's data loads.
- **Alternatives Considered:** Clearing the stored value entirely on every sign-out — rejected because it would needlessly force the user to re-choose a workspace on every re-sign-in on their own device, when the whole point of `ActiveWorkspaceStore` (per [ADR-031](#adr-031-single-application-with-player-and-coach-workspace-switching)) is to remember that choice per device. Storing an explicit `lastSignedInUid` guard instead of namespacing every key — rejected as more state to keep in sync for the same outcome; namespacing the key itself makes cross-account leakage structurally impossible rather than reliant on remembering to check a guard.
- **Status:** Accepted
- **Date:** 2026-07-20

**Documented in full in:** [`active_workspace_store.dart`](lib/services/local_storage/active_workspace_store.dart), [`active_workspace_controller.dart`](lib/features/workspace/presentation/controllers/active_workspace_controller.dart).

### ADR-053: Notifications Read from a Real, Currently-Empty Firestore Stream — No More Seeded Placeholder Data

- **Decision ID:** ADR-053
- **Decision:** `NotificationsController` now streams `users/{uid}/notifications` directly from Firestore instead of returning a hardcoded two-item seed list after a simulated delay. Because notification *creation* is Cloud-Function-only ([BACKEND_SPECIFICATION.md §1.6, §18](BACKEND_SPECIFICATION.md#16-usersuidnotificationsnotificationid)) and no Cloud Functions or session/alert/report pipeline exists yet, this collection is genuinely, correctly empty for every account today — the Notification Center now shows its real empty state, not a fake populated one.
- **Reason:** Phase 8B: "Replace placeholder notification source with Firestore. Support empty, loading, real data." An always-empty real stream is a more honest state than a fake populated one — it is indistinguishable, from the UI's perspective, from "a real user with zero notifications so far," which is exactly what every account's true state is at this point in the product's build-out. The client only ever writes the `read` field on an existing notification document (§15); it never fabricates notification documents itself.
- **Alternatives Considered:** Leaving the seeded two-item placeholder in place since no notification-writing pipeline exists to ever populate it for real — rejected per Phase 8B's explicit "No fake profiles. No fake workspaces" instruction extending, in spirit, to fake notifications; a genuinely empty real stream is strictly more honest and costs nothing extra to build.
- **Status:** Accepted
- **Date:** 2026-07-20

**Documented in full in:** [`notifications_controller.dart`](lib/features/notifications/presentation/controllers/notifications_controller.dart), [`notification_repository_impl.dart`](lib/features/notifications/data/repositories/notification_repository_impl.dart).

### ADR-054: Root Cause of the Empty Firestore Console — Undeployed Security Rules, Not a Code Defect

- **Decision ID:** ADR-054
- **Decision:** Live testing this phase (a full sign-in → onboarding → "Get Started" pass against the real `vikzar-prod` project, instrumented with a console/network listener) reproduced the reported symptom directly: the onboarding-completion transaction's very first read (`Transaction.get` on `users/{uid}`, via `BatchGetDocuments`) fails with `{"code":"permission-denied"}`. The cause is exactly what [ADR-050](#adr-050-production-firebase-connection-requires-the-project-owners-own-credentials--cannot-be-completed-by-an-agent) and every Phase 8B CHANGELOG entry already flagged as an open blocker: `firestore.rules` and `storage.rules` were authored at Phase 8B but **never deployed** (explicitly out of that phase's scope — "Do not deploy. Only create them"), so the live project still runs whatever default rules existed when the Firestore database was created — for a database created in production mode, that default is `allow read, write: if false`, denying every client request regardless of authentication.
- **What this is *not*:** live testing also confirmed the code's own failure handling is already correct — `OnboardingCompletionController.complete()` does not clear the failure, does not navigate, and the screen shows an inline error rather than silently proceeding. The reported "onboarding completes successfully while Firestore stays empty" symptom was not reproduced as a code-level silent-success bug; every write failure this phase observed was caught, classified, and blocked navigation as designed. The most likely explanation for the original report is that it was observed before Phase 8B's transaction-gated completion flow existed, or under a build predating this exact commit.
- **A real, distinct bug *was* found and fixed alongside this:** the error shown for the reproduced failure was the generic "Something went wrong," not a `permission-denied`-specific message, because `cloud_firestore_web`'s `runTransaction` does not always surface a plain Dart `FirebaseException` for every failure shape a transaction can produce, and every repository's `on FirebaseException catch (e) { ... } catch (e) { UnknownFailure }` pair only classified the first shape correctly. Fixed by a new shared `mapFirestoreError(Object error)` ([`core/errors/firestore_failure_mapper.dart`](lib/core/errors/firestore_failure_mapper.dart)), which extracts a Firebase error code from any thrown object — a typed `FirebaseException`, a duck-typed `.code` property, or (last resort) a substring match against known codes in `toString()` — replacing every repository's narrower, duplicated `_mapException` method. This is real hardening regardless of the rules-deployment question: misclassifying a real, specific error as "unknown" is itself a small instance of this phase's "no silent failures" mandate being violated by an overly narrow catch type.
- **What was deliberately *not* done:** deploying `firestore.rules`/`storage.rules` to the live project. That is the one remaining action that would make onboarding actually succeed end-to-end, but it is a change to shared, live production infrastructure — outside what an agent should do unilaterally, exactly the same reasoning as [ADR-050](#adr-050-production-firebase-connection-requires-the-project-owners-own-credentials--cannot-be-completed-by-an-agent). Flagged to the project owner directly rather than deployed silently.
- **Alternatives Considered:** Assuming the symptom without live reproduction and guessing at a code fix — rejected per this phase's explicit "Do not guess" instruction; the actual root cause (rules, not code) would never have been found by re-reading the transaction logic alone, since that logic is correct. Silently deploying the rules to "just fix it" — rejected as an unauthorized change to shared production infrastructure.
- **Status:** Accepted
- **Date:** 2026-07-20

**Documented in full in:** [`core/errors/firestore_failure_mapper.dart`](lib/core/errors/firestore_failure_mapper.dart), every `data/repositories/*_impl.dart` file's catch clauses, [`onboarding_complete_screen.dart`](lib/features/onboarding/presentation/screens/onboarding_complete_screen.dart).

### ADR-055: OTP's Placeholder Status Is Now Disclosed in the UI

- **Decision ID:** ADR-055
- **Decision:** The OTP entry step now shows a small, calm, Caption-size line beneath the code field: "Code verification isn't live yet — any 6-digit code is accepted while this is in development." The underlying mechanism is unchanged from [ADR-044](#adr-044-placeholder-otp-verification-pending-real-backend-delivery) — real Firebase Authentication sign-in/account-creation still happens (this is not fake authentication, the session and UID are genuine) — only the *code* is unverified.
- **Reason:** Phase 8C's explicit mandate: "If verification is not genuinely implemented yet, make that explicit in the UI rather than silently accepting invalid codes." Prior to this, the screen's copy ("We've sent a 6-digit code to {email}") implied a real code had been generated and would be checked, when neither is true — a real user reading that copy would have no way to know the code step is currently a formality. This is the same class of problem [ADR-044](#adr-044-placeholder-otp-verification-pending-real-backend-delivery) already named honestly in code comments and the CHANGELOG; this phase's addition makes it visible in the product itself, not just in engineering documentation.
- **Alternatives Considered:** Rewriting "We've sent a 6-digit code to {email}" itself — rejected as out of this phase's explicit copy scope (Section 4 names exactly two lines to change, and this isn't one of them); the added disclaimer achieves the same honesty goal without touching copy the phase didn't ask for. Blocking the OTP step entirely until real verification exists — rejected as a redesign/feature change the phase's "Rules" section forbids ("no redesigns... no new features"); disclosure, not removal, is the minimal honest fix.
- **Status:** Accepted
- **Date:** 2026-07-20

**Documented in full in:** [`auth_screen.dart`](lib/features/auth/presentation/screens/auth_screen.dart).

### ADR-056: Onboarding's Required Fields Now Show Inline Validation Instead of a Silently-Disabled Button

- **Decision ID:** ADR-056
- **Decision:** On the Player Profile onboarding step, Continue is now always tappable. Tapping it while any required field (Name, Age, Height, Weight, Preferred Foot, Playing Position, Injury History) is unset reveals a "Required" message inline — under the relevant text field's own `errorText` slot, or as a small Caption-size Oxide Rose line beneath a segmented control/chip group that has no such slot — rather than leaving the button silently disabled with no explanation. Errors only appear after a tap attempt (never on first load, before the user has done anything) and clear live as each field is filled in.
- **Reason:** Phase 8C: "Make all required fields genuinely required. Use inline validation. No snackbars. No dialogs. No popups." The fields were already functionally required (a disabled Continue button already blocked progress), but a disabled button with zero explanatory feedback does not meet "genuinely required" in a way a user can act on — it just looks broken. Inline, per-field messages are the calmest way to satisfy this without a snackbar/dialog/popup, all of which the phase explicitly forbids.
- **Alternatives Considered:** Leaving Continue disabled until the form is complete, unchanged — rejected as not meeting "use inline validation," since a disabled button in isolation provides no inline information about *why*. Validating and disabling per-keystroke with immediate red borders on an untouched, empty field — rejected as needlessly alarming on first load (this phase's own product tone — DESIGN_SPECIFICATION.md §3, "calm rather than alarming" — argues against a form that opens already covered in errors before the user has typed anything).
- **Status:** Accepted
- **Date:** 2026-07-20

**Documented in full in:** [`player_profile_screen.dart`](lib/features/onboarding/presentation/screens/player/player_profile_screen.dart).

### ADR-057: Injury History Replaced by a Non-Medical Training Status Question

- **Decision ID:** ADR-057
- **Decision:** **Implemented at Phase 8D** — Phase 8C proposed this as a UX-review recommendation, not yet implemented (the original text below is preserved for its reasoning); Phase 8D's brief explicitly authorized implementing it ("If keeping it introduces unnecessary medical positioning, replace it with a more product-appropriate training availability/status question"). "Injury History" (`Never` / `Previously` / `Currently Recovering`, expanding to a clinical injury-type picker — ACL, Meniscus, Hamstring, Ankle, Other — when "Previously" is selected) is replaced by a single, non-medical **Training Status** question: `Full training` / `Returning from a break` / `Not currently training`, with no follow-up question. Implemented as `TrainingStatus` in `shared/models/player_profile.dart` (replacing `InjuryHistoryStatus`/`InjuryType`), persisted as `playerProfile.trainingStatus` (replacing `injuryStatus`/`injuryTypes`) per the updated `BACKEND_SPECIFICATION.md` §1.5. This is a field rename/re-scope, not a schema addition — "preserving existing backend compatibility wherever possible" per this phase's brief means keeping the same map shape (a single field inside `playerProfile`, no new collection), not literally keeping the old, medically-framed field name.
- **Reason:**
  1. **It is medical data collection in a product that explicitly disclaims providing medical diagnosis** (SPECIFICATION.md §3, non-goals: "Vikzar does not provide medical diagnosis"). "ACL," "Meniscus," and "Hamstring" are clinical/diagnostic terms, not sports-analytics terms — collecting them at account creation directly contradicts the terminology discipline the whole product was swept for at Phase 8A (replacing "injury prevention" language with "impact monitoring, biomechanics, movement analysis, elevated injury risk" throughout every other document and screen). This field is the one remaining place the product still asks a clinical-intake-style question.
  2. **It provides no traceable value today** (PRODUCT_PRINCIPLES.md Principle 4: "Every feature must provide clear value... If a feature cannot be tied to a concrete benefit, it does not belong in the product"). No screen, Risk Engine input, or coach-facing view reads `playerProfile.injuryStatus`/`injuryTypes` anywhere in this codebase — the data is collected and stored, never surfaced or acted on.
  3. **A Training Availability question keeps the same, already-recognized underlying value** — DESIGN_SPECIFICATION.md's own Phase 6 revision note for this field said "Currently Recovering" was "a meaningful enough distinction to be worth the one extra segment," i.e. the product already identified that *knowing a player is easing back into training* has value. A training-status framing captures exactly that signal — directly useful to a coach managing today's training load — without naming a medical condition, and without asking the player to self-report a clinical history the product has no mechanism to verify, store securely as health data, or act on.
  4. **It keeps onboarding shorter** (Principle 5): the conditional multi-select injury-type picker is the single most clinically-detailed, highest-friction field in the entire flow; a three-option segment control with no follow-up is a strict simplification.
- **What this does not do:** invent a new feature that *consumes* training-availability data (e.g., surfacing it to a coach) — that would be new scope, deferred to a future phase per Principle 7 ("scalability is a constraint on architecture, not a license to build features early"). The recommendation is scoped to the onboarding question itself.
- **Alternatives Considered:** Keeping "Injury History" but just renaming the label — rejected outright per the phase's explicit "Do NOT simply rename it" instruction, and renaming alone wouldn't resolve either the medical-framing or the no-consuming-feature problem. Removing the field entirely with no replacement — considered, but the product has already judged (Phase 6) that *some* recovery-adjacent signal is worth one form field; removing it outright would be a bigger product decision than this review is scoped to make unilaterally.
- **Status:** Accepted — implemented at Phase 8D.
- **Date:** 2026-07-20 (proposed), 2026-07-20 (implemented)

**Documented in full in:** [`player_profile.dart`](lib/shared/models/player_profile.dart), [`player_profile_screen.dart`](lib/features/onboarding/presentation/screens/player/player_profile_screen.dart), [`player_onboarding_data.dart`](lib/features/onboarding/domain/models/player_onboarding_data.dart), [`edit_profile_sheet.dart`](lib/features/profile/presentation/widgets/edit_profile_sheet.dart).

### ADR-058: Fixed a Dotted-Key Bug That Silently Broke Onboarding Completion for Every Account

- **Decision ID:** ADR-058
- **Decision:** `UserRepositoryImpl._completeOnboarding` (the shared transaction behind both `completePlayerOnboarding` and `completeCoachOnboarding`) wrote the workspace-completion field as `'workspaces.${workspace.firestoreKey}': workspaceMap` inside a plain `Map<String, dynamic>` passed to `transaction.set(docRef, update, SetOptions(merge: true))`. `DocumentReference.set()` does not expand a dotted string key into a nested field path — that expansion only happens for real `update()` calls or `FieldPath`-based dotted merge keys — so this literally wrote a single top-level field named `workspaces.player` (dot included in the field name), never a nested `workspaces` map containing a `player`/`coach` key. Fixed by writing a genuinely nested map instead: `'workspaces': {workspace.firestoreKey: workspaceMap}`, which `SetOptions(merge: true)` correctly deep-merges against any existing `workspaces` map (e.g. a user who already completed the other workspace's onboarding keeps that entry).
- **Reason:** This phase's live REST-API verification against `vikzar-prod` (reading a real `users/{uid}` document via an authenticated `fetch` after completing onboarding through the app's own UI) found the document contained a literal `workspaces.player` field, not a nested `workspaces` object. `AppUser.fromMap` (`lib/shared/models/app_user.dart`) only ever reads `data['workspaces']` as a nested map and looks up `['player']`/`['coach']` inside it — so `UserWorkspaces.has(workspace)` was unconditionally `false` for every account, for every workspace, regardless of how many times onboarding completion ran. `route_guards.dart`'s `_destinationForUser` therefore always returned `InOnboarding(workspace)`, never `InApp(workspace)`: **every account that ever completed onboarding was silently routed back into onboarding forever**, even though the write itself reported success and the rest of the profile data (name, age, height, weight, position, etc.) persisted correctly. This is exactly the class of "backend mismatch" this phase's brief calls out ("verify every Firestore write matches BACKEND_SPECIFICATION.md exactly... verify routing after onboarding") — not a spec deviation to document, a genuine code defect to fix, since `BACKEND_SPECIFICATION.md` and `AppUser`'s own model already agreed on a nested `workspaces` map; only the write call disagreed with both.
- **Verification:** Rebuilt (`flutter build web --release`), then re-ran the full Player onboarding flow end-to-end through the app's real UI against `vikzar-prod`. Confirmed via authenticated REST GET that the resulting document now contains a genuinely nested `workspaces: { player: { teamId: null } }` map (the account's earlier, pre-fix `workspaces.player` literal field remains in the document as harmless orphaned data from before the fix — this is a test/verification account, not a real user). Confirmed the app then navigated automatically from the "You're all set." screen straight to Player Home (no manual `context.go` needed, per `onboarding_complete_screen.dart`'s existing design — `route_guards.dart` reacting to the corrected Firestore data was sufficient on its own). Confirmed a subsequent full page reload restored directly to Player Home without re-showing onboarding.
- **Status:** Accepted — fixed in code this phase.
- **Date:** 2026-07-20

**Documented in full in:** [`user_repository_impl.dart`](lib/shared/repositories/user_repository_impl.dart).

### ADR-059: Training Status Revised to a 4-Value Enum (Fully Available / Individual Training / Return to Play / Unavailable)

- **Decision ID:** ADR-059
- **Decision:** `TrainingStatus` (`shared/models/player_profile.dart`) is revised from ADR-057's 3-value set (`fullTraining` / `returningFromBreak` / `notCurrentlyTraining`) to 4 values: `fullyAvailable` / `individualTraining` / `returnToPlay` / `unavailable`. This is a Phase 9 product-requirement revision, not a reversal of ADR-057's reasoning — the non-medical framing and profile-only scope both stand; only the option set and labels change, to match the brief's explicit, named requirement and to give the field real coach-facing consumers (Player Home's Today's Status, Coach Home's Today's Squad, the Team roster's status chips, and Player Detail).
- **Reason:** ADR-057 itself flagged that nothing read `trainingStatus` — it existed but had no consumer. Phase 9's brief names Training Status as load-bearing product information (squad management, availability planning) and specifies these exact four values. The onboarding question (`player_profile_screen.dart`) is updated to the same four values; no new question or step is added.
- **Alternatives Considered:** Keeping the 3-value set and layering the new consumers on top of it — rejected because the brief's Player Profile section names the 4 values exactly ("Implement them exactly," per the brief), and the 3-value set doesn't distinguish "returning but still restricted" (Individual Training) from "fully sidelined" (Unavailable), a distinction Coach Home's squad counts need.
- **Status:** Accepted.
- **Date:** 2026-07-22

**Documented in full in:** [`player_profile.dart`](lib/shared/models/player_profile.dart), [`player_profile_screen.dart`](lib/features/onboarding/presentation/screens/player/player_profile_screen.dart).

### ADR-060: Injury Detail Reintroduced — Conditionally, Profile-Only, Never at Onboarding

- **Decision ID:** ADR-060
- **Decision:** A player's injury detail (predefined `InjuryType` — ACL, Meniscus, Hamstring, Ankle, Groin, Calf, Hip, Quadriceps, Other, multi-select — and `RecoveryTimeframe` — Under 2 weeks / 2–4 weeks / 1–2 months / 2–3 months / 3+ months, single-select) is reintroduced on the Player Profile edit sheet, shown only when `trainingStatus != null && trainingStatus != TrainingStatus.fullyAvailable`. It is never asked during onboarding.
- **Reason:** This differs from what ADR-057 removed in three load-bearing ways, per the phase brief's explicit direction: (1) it is Profile-only, never a mandatory onboarding gate; (2) it is conditional on a real signal the player already set, not asked unconditionally of every player; (3) it now has a genuine consumer — a coach viewing the Team roster or Player Detail can see *why* a player is unavailable and roughly *when* they're expected back, which is operational squad-management information, not a clinical diagnosis. Framed throughout as training-availability planning.
- **Alternatives Considered:** A free-text "Previous Injuries" field (the plan's first draft) — rejected by explicit user direction in favor of predefined options plus a recovery-timeframe selector, keeping the field structured and non-diagnostic rather than an open text box a player could fill with anything.
- **Status:** Accepted.
- **Date:** 2026-07-22

**Documented in full in:** [`player_profile.dart`](lib/shared/models/player_profile.dart), [`edit_profile_sheet.dart`](lib/features/profile/presentation/widgets/edit_profile_sheet.dart), [`profile_screen.dart`](lib/features/profile/presentation/screens/profile_screen.dart), [`player_detail_screen.dart`](lib/features/team/presentation/screens/player_detail_screen.dart).

### ADR-061: Player Activity and Recent Team Activity Are Backed by NotificationRepository Only — No New Activity Feed Invented

- **Decision ID:** ADR-061
- **Decision:** Player Home's "Recent Activity," the new Player Activity screen (`sessions/presentation/screens/player_activity_screen.dart`, filling `/player/timeline`), and Coach Home's "Recent Team Activity" are all backed by the existing, real (currently near-empty) `NotificationRepository` stream — the same one `NotificationCenterScreen` already used. No new Firestore collection or cross-collection aggregation is introduced to simulate a richer "football activity feed."
- **Reason:** There is no Firestore collection that is "the football activity feed" yet — no ETL/AI pipeline exists to populate one (BACKEND_SPECIFICATION.md), and inventing a cross-collection aggregation would be new architecture, which the phase brief explicitly prohibits ("Do NOT invent product decisions"). Reusing `NotificationRepository` shows genuine, honestly-labeled data — the empty state says activity will appear "once your training data starts flowing," not a football-specific claim ("no training sessions yet") this data source can't actually back.
- **Known limitation, stated honestly rather than worked around:** a coach cannot read a specific other player's `users/{uid}/notifications` subcollection — Security Rules (`firestore.rules`) scope it to self-only, and this is correct: a player's notifications are not coach-visible data. Player Detail's "Recent Activity" section is therefore a permanent, genuine empty state (`section_empty_state.dart`), not a reuse of this pattern — it is not expected to ever show data under the current schema, and that is documented in `player_detail_screen.dart` rather than silently left unexplained.
- **Alternatives Considered:** A denormalized per-team "activity" collection a Cloud Function would populate — out of scope (no Cloud Functions exist yet; would be new backend scope this phase explicitly avoids).
- **Status:** Accepted.
- **Date:** 2026-07-22

**Documented in full in:** [`player_home_screen.dart`](lib/features/player_home/presentation/screens/player_home_screen.dart), [`player_activity_screen.dart`](lib/features/sessions/presentation/screens/player_activity_screen.dart), [`coach_home_screen.dart`](lib/features/coach_home/presentation/screens/coach_home_screen.dart), [`player_detail_screen.dart`](lib/features/team/presentation/screens/player_detail_screen.dart).

### ADR-062: Today's Status and Today's Squad Are Driven by Real `trainingStatus` — Squad Aggregation Is an Accepted N-Read MVP Tradeoff

- **Decision ID:** ADR-062
- **Decision:** Player Home's "Today's Status" reads the signed-in player's own `playerProfile.trainingStatus` directly. Coach Home's "Today's Squad" and the Team screen's per-player status chips are driven by `squadSummaryProvider`/`teamRosterEntriesProvider` (`coach_home/presentation/controllers/squad_summary_controller.dart`, `team/presentation/controllers/team_roster_controller.dart`), which combine `TeamRepository.watchRoster` with one `watchUserProvider(uid)` read per roster member to read each player's own real status. Neither ever fabricates a count or status.
- **Reason:** No denormalized status field exists on `TeamMember`, and no Cloud Function writes one — building one is new backend scope, out of this phase. Reading each player's own document individually is the same self-service-over-Cloud-Function shape ADR-051 already accepted for team/workspace state, applied here to squad status. `teamRosterEntriesProvider` is the single place this aggregation happens; `squadSummaryProvider` builds on it rather than re-deriving the same per-member reads, avoiding the duplicated-architecture the phase brief explicitly warns against.
- **Known tradeoff:** N+1 reads (one roster stream plus one per member) scale to a typical single-team roster size, not to very large multi-team rosters — acceptable for this MVP, the same accepted shape as every other ADR-051-pattern read in this codebase. A member whose own read is still loading or has failed is counted as "no data" rather than blocking the whole summary — the same honest treatment as a player who genuinely hasn't set a status yet, never an error state masquerading as a real count.
- **Alternatives Considered:** A Cloud Function that denormalizes `trainingStatus` onto `TeamMember` on write — the architecturally cleaner long-term answer, deferred: it requires a Cloud Functions deployment, which does not exist yet in this codebase (BACKEND_SPECIFICATION.md's Cloud Functions are still specified, not implemented).
- **Status:** Accepted.
- **Date:** 2026-07-22

**Documented in full in:** [`squad_summary_controller.dart`](lib/features/coach_home/presentation/controllers/squad_summary_controller.dart), [`team_roster_controller.dart`](lib/features/team/presentation/controllers/team_roster_controller.dart), [`player_home_screen.dart`](lib/features/player_home/presentation/screens/player_home_screen.dart), [`coach_home_screen.dart`](lib/features/coach_home/presentation/screens/coach_home_screen.dart).

### ADR-063: Mineral Blue as the Systematic Information/Intelligence Colour Across the Product

- **Decision ID:** ADR-063
- **Decision:** Every informational, connection, readiness, timeline, or status-communicating element added or rebuilt this phase uses Mineral Blue (`colorScheme.secondary`) consistently: `VikzarStatusChip`'s default colour, Training Status chips (all four values), Pod Status, Today's Squad counts, Team roster status chips, Player Activity/Recent Team Activity timeline accents, and the Notification Preview icon. Oxide Rose (`colorScheme.primary`) stays the action/CTA colour — every button, primary CTA, active nav/tab state, and selected-segment fill — unchanged from its existing role. Alert severity is the one place a third role applies: `info` uses Mineral Blue, `warning` uses Oxide Rose ("attention without alarm" — `brand_colors.dart`'s own description of the colour), and `critical` uses Alert Crimson, per DESIGN_SPECIFICATION.md §8's exclusive reservation of that colour for Critical risk states.
- **Reason:** Explicit user direction when reviewing the phase plan: apply Mineral Blue systematically as the information/intelligence colour across the whole product, not case-by-case per screen as the first draft proposed. `VikzarStatusChip` (new this phase) encodes this as its default so every future status/information surface inherits the correct colour without each call site having to choose.
- **Alternatives Considered:** Deciding Mineral Blue vs. Oxide Rose per screen/component as each was built (the rejected first-draft plan) — replaced because it risks inconsistency and re-litigating the same colour decision repeatedly.
- **Status:** Accepted.
- **Date:** 2026-07-22

**Documented in full in:** [`vikzar_status_chip.dart`](lib/design_system/components/vikzar_status_chip.dart), [`alerts_screen.dart`](lib/features/alerts/presentation/screens/alerts_screen.dart).

### ADR-064: Real Alerts Feature Built on Already-Specified, Already-Secured Schema

- **Decision ID:** ADR-064
- **Decision:** `/coach/alerts` (previously a shared `ComingSoonScreen`) is now a real, minimal Alerts feature: `Alert` domain model, `AlertRepository`/`AlertRepositoryImpl` reading the `alerts` collection, `alertsControllerProvider`, and `AlertsScreen` with an All/Unacknowledged filter — reading the coach's own team's alerts, newest first, honestly empty today ("No alerts. Your team is clear." — the exact copy DESIGN_SPECIFICATION.md §19.4 already specified). Acknowledging an alert writes only `acknowledged`/`acknowledgedBy`/`acknowledgedAt`, the single client write `firestore.rules` permits against this collection.
- **Reason:** The `alerts` collection, its Security Rules (`firestore.rules`), and its composite indexes (`firestore.indexes.json`) already existed and were already unused before this phase — building the presentation layer against them is completing the product, not adding new backend scope. Alert creation stays Cloud Function-only (`allow create: if false`); no client-side alert-creation path is added, matching the schema's existing, intentional design.
- **Alternatives Considered:** Leaving `/coach/alerts` as `ComingSoonScreen` for another phase — rejected because the brief explicitly names Alerts as in-scope ("build the real experience, empty today, future-ready") and the backend groundwork was already fully in place with nothing blocking it.
- **Status:** Accepted.
- **Date:** 2026-07-22

**Documented in full in:** [`alert.dart`](lib/features/alerts/domain/models/alert.dart), [`alert_repository_impl.dart`](lib/features/alerts/data/repositories/alert_repository_impl.dart), [`alerts_screen.dart`](lib/features/alerts/presentation/screens/alerts_screen.dart).

### ADR-065: Universal Pod Requires No Schema Change — Verified, Not Changed

- **Decision ID:** ADR-065
- **Decision:** No Flutter code or Firestore schema change was made for "Universal Pod" this phase. `devices/{deviceId}.type` (`smart_pod` / `emg_band`) plus `ownerId` (BACKEND_SPECIFICATION.md §7) already fully describe "one physical Pod assigned to a player" — which shinguard, compression sleeve, or compression shorts the Pod is physically mounted in is a real-world fact no product screen shows or needs, and is therefore correctly absent from the schema.
- **Reason:** The phase brief asked to verify the architecture supports Universal Pod assignment without changing the data model, and to update documentation only if clarification was needed. Verification confirmed the existing schema is already sufficient — no `devices` document field, screen, or UI ever needs to encode a mounting location, since a coach or player only ever needs to know *which Pod* is assigned to *which player*, both of which the existing fields already answer.
- **Alternatives Considered:** Adding a `mountingLocation` field to `devices/{deviceId}` — rejected as unneeded speculative schema, since no screen this phase (or named in the brief) reads or writes such a value.
- **Status:** Accepted.
- **Date:** 2026-07-22

**Documented in full in:** [`BACKEND_SPECIFICATION.md`](BACKEND_SPECIFICATION.md) §7.

### ADR-066: vikzar-ai Aligns to vikzar-app's Already-Approved Firebase Integration Contract — Cloud Functions, Never Direct Firestore Writes

- **Decision ID:** ADR-066
- **Decision:** `vikzar-ai`'s `FirebaseSynchronizer`/`FirebaseTransport` (the "laptop" pipeline's Firebase integration point) is revised to call the 5 HTTPS Callable Cloud Functions this phase built (`functions/` — ADR-067) with their exact §21 payloads, instead of writing directly to ad-hoc Firestore paths (`live/`, `players/`, `reports/`, `analytics/`) via a generic `write(updates)` call. The new transport (`vikzar-ai/app/api/firebase_callable_transport.py`) authenticates as the scoped "ingestion principal" (§3) using a Firebase ID token obtained via refresh-token exchange over plain HTTPS — it deliberately does **not** use the `firebase-admin` SDK, since that would grant the field-deployed laptop unrestricted Firestore access, exactly the trust model §0 rejects.
- **Reason:** This is the platform-lock pass's central architectural finding. `vikzar-app`'s BACKEND_SPECIFICATION.md §0/§17/§21 already specifies, in detail, why the laptop must never hold direct Firestore write access (it's field-deployed, more exposed than a cloud service) and exactly which 5 Callable functions it calls instead — already deployed as Security Rules, already what this session's own Alerts feature reads from. `vikzar-ai`'s prior `FirebaseTransport` design was never committed to git, never connected to real credentials, and never exercised against anything real — correcting its unbuilt interface to match an already-approved spec, before it's ever built for real, is not a rewrite of working code. One genuine design decision arose from this: `vikzar-ai`'s `RiskAssessment` output (fatigue/workload/asymmetry/muscle-balance sub-scores, confidence, contributing factors, recommendations) is richer than the original §21 contract captured — resolved by additive-only optional fields on `ingestLiveTick.metrics` and `submitAlert` (§21.4/§21.6), never by dropping data to fit.
- **Known, honestly-documented gaps this alignment surfaced** (not silently worked around): `vikzar-ai` has no `type`/`deviceIds` fields anywhere in its session-start request schema, so `sync_session` cannot call `startSession`/`completeSession` without fabricating them — it now reports `SyncStatus.DISABLED` honestly instead. `vikzar-ai` has no team concept anywhere in its schemas, so every outgoing call omits `teamId` (an already-optional field, per §21's "omit for an individual session"). `vikzar-ai` has no impact-event concept in its ETL/feature/model output, so `ingestLiveTick.metrics.cumulativeImpacts` (a required §21.4 field) is sent as an explicitly documented placeholder `0`, not a claim that zero impacts occurred.
- **Alternatives Considered:** Reshaping `vikzar-app`'s already-deployed schema to match `vikzar-ai`'s ad-hoc paths instead — rejected: `vikzar-app`'s design is the one that's actually security-reviewed, deployed, and load-bearing (a real Alerts feature already reads `alerts/{alertId}` exactly as spec'd); `vikzar-ai`'s was never exercised against anything. Giving `vikzar-ai` `firebase-admin` credentials directly — rejected outright, since it recreates the exact broad-credential exposure §0 was written to avoid.
- **Status:** Accepted.
- **Date:** 2026-07-22

**Documented in full in:** `vikzar-ai/app/api/firebase.py`, `vikzar-ai/app/api/firebase_callable_transport.py`, `vikzar-ai/app/api/ingestion_contracts.py`.

### ADR-067: Real Cloud Functions Built for the Laptop Ingestion Contract (§17/§21) — Not Deployed

- **Decision ID:** ADR-067
- **Decision:** New `functions/` (Node.js + TypeScript, Firebase Functions v2 SDK) implements all 11 functions BACKEND_SPECIFICATION.md §17 specifies: 5 HTTPS Callable (`startSession`, `ingestLiveTick`, `completeSession`, `submitAlert`, `submitReport`), 4 Firestore-triggered (`fanOutLiveMonitoring`, `onSessionCompleted`, `onAlertCreated`, `onReportCreated`), 2 scheduled (`deviceHeartbeatMonitor`, `weeklySummaryAggregator`). Every Callable function validates the caller's `ingestor: true` custom claim and `teamId`/`orgId` scope (§0/§3) before writing anything. `firebase.json` is wired to build this directory; nothing is deployed this pass (deploying requires the project owner's Firebase CLI access, the same category as ADR-050).
- **Reason:** The `alerts`/`reports`/`sessions`/`teams.liveMonitoring`/`users.careerStats` collections, their Security Rules, and their indexes have existed since Phase 8B/9+10, entirely unused because nothing ever wrote to them — the client can't (Security Rules forbid it) and nothing else existed to. Building these functions is completing an already-specified, already-secured contract, not new architecture.
- **`onAlertCreated`'s one documented, unresolved gap**: §18's notification table names a `type: "low_battery"` rule notifying "the device's `ownerId`" — but `alerts/{alertId}` (§1.10) has no `deviceId` field to resolve an owner from. The function implements every other §18 row correctly and falls back to its general severity-based recipient rule for low-battery alerts rather than guessing a device owner; closing this needs a schema decision (adding `deviceId` to the alert schema), out of scope for this pass.
- **Status:** Accepted.
- **Date:** 2026-07-22

**Documented in full in:** [`functions/src/index.ts`](functions/src/index.ts) and its `callable/`, `triggers/`, `scheduled/`, `contracts/`, `lib/` subdirectories; 60 passing Jest tests.

### ADR-068: Provider `autoDispose` Added to Every Firestore-Backed `.family` Provider

- **Decision ID:** ADR-068
- **Decision:** `watchUserProvider`, `teamRosterProvider`, `teamProvider`, `teamRosterEntriesProvider`, and `squadSummaryProvider` — every `.family` provider backed by a live Firestore read — now use Riverpod's `.autoDispose`.
- **Reason:** Found during this phase's edge-case audit (Section 12 of the platform-lock brief): without `autoDispose`, every distinct argument ever passed to a `.family` provider (e.g. every roster member's uid a coach's Team screen has ever shown) keeps its Firestore listener open for the app's entire process lifetime, even after nothing displays it — unbounded listener/memory growth and wasted Firestore reads, a direct scalability concern (Section 14) at any roster size beyond a handful of players. `autoDispose` closes each listener once nothing is watching it, and Riverpod recreates it fresh on next use — transparent to every call site; no consumer code changed.
- **Alternatives Considered:** Leaving providers non-`autoDispose` and manually invalidating them on navigation — rejected as strictly worse: more code, easier to forget a call site, and Riverpod's own built-in mechanism already exists for exactly this.
- **Status:** Accepted.
- **Date:** 2026-07-22

**Documented in full in:** [`user_repository_impl.dart`](lib/shared/repositories/user_repository_impl.dart), [`team_roster_controller.dart`](lib/features/team/presentation/controllers/team_roster_controller.dart), [`squad_summary_controller.dart`](lib/features/coach_home/presentation/controllers/squad_summary_controller.dart).

### ADR-069: Football-Natural Terminology Pass — "Pro"/"Semi-Pro"/"Role"/"Club"

- **Decision ID:** ADR-069
- **Decision:** `PlayingLevel`/`CoachingLevel`'s display labels change from "Professional"/"Semi Professional" to "Pro"/"Semi-Pro"; Coach Profile's "Coaching Title/Role" becomes "Role"; "Club/Organization" becomes "Club"; Profile's "Application Version" becomes "App Version". Every enum's persisted `.name` (the Firestore value) is unchanged — this is display text only.
- **Reason:** Matches the platform-lock brief's explicit examples exactly ("Professional → Pro," "Semi Professional → Semi-Pro") and its broader instruction to replace corporate-sounding terminology with wording naturally used inside football clubs. "Organization" and "Application Version" were the two other clearly corporate-register terms found in a repo-wide audit of onboarding/profile copy; "Club" and "App Version" are how a coach or player would actually say them.
- **Status:** Accepted.
- **Date:** 2026-07-22

**Documented in full in:** [`player_profile.dart`](lib/shared/models/player_profile.dart), [`coach_profile.dart`](lib/shared/models/coach_profile.dart), [`profile_screen.dart`](lib/features/profile/presentation/screens/profile_screen.dart), [`edit_profile_sheet.dart`](lib/features/profile/presentation/widgets/edit_profile_sheet.dart), [`coach_profile_screen.dart`](lib/features/onboarding/presentation/screens/coach/coach_profile_screen.dart).

### ADR-070: Universal Pod — Lower-Leg Mounting Only for the ACL Risk Use Case (Refines ADR-065)

- **Decision ID:** ADR-070
- **Decision:** Extends, and does not contradict, ADR-065 — that ADR verified no *Firestore/Flutter* schema change is needed for Universal Pod mounting flexibility, which still stands. This ADR records a deeper, `vikzar-ai`-side finding from this phase's cross-repo research (`vikzar-ai/docs/research/UNIVERSAL_POD_MOUNTING.md`): the hardware's FSR sensor (ground-contact-force sensing — foot strike, landing, push-off) is physically meaningless mounted anywhere but near the foot/lower leg, and the product's ACL-risk framing and trained model are built on lower-limb/tibial mechanics. **Recommendation**: the ACL-risk product use case should be scoped to shin-guard or compression-sleeve mounting only (anatomically equivalent lower-leg placement); compression-shorts (hip) mounting, if supported at all, is a separate, not-yet-validated use case and must never be silently fed into the same risk pipeline as if interchangeable.
- **Reason:** A hip-mounted Pod cannot produce FSR ground-contact data at all, and produces IMU data describing entirely different body-segment kinematics than what the model was (or will be) trained on — feeding it in anyway would be a silent distribution shift producing a real number that describes something the model was never validated against, which is exactly the kind of fabricated-looking-but-invalid output this whole platform-lock pass was explicitly told to avoid.
- **What this does not do**: it does not add a `mountLocation` field to `vikzar-ai`'s `HardwareProvenance` (a locked ETL→AI boundary schema requiring explicit sign-off, per that research doc's own scope) or change any Flutter/Firestore field (ADR-065's conclusion there is unaffected — no screen needs to know or show mounting location).
- **Status:** Accepted.
- **Date:** 2026-07-22

**Documented in full in:** `vikzar-ai/docs/research/UNIVERSAL_POD_MOUNTING.md`, `vikzar-ai/docs/research/SENSOR_SPECIFICATIONS.md`.

### ADR-071: Phase 11 — Device Telemetry Write Gap Fixed; Additive BLE Device/Battery/Capture-Phase Schema

- **Decision ID:** ADR-071
- **Decision:** Two changes, both additive, neither touches a locked/deployed field:
  1. **Bug fix**: `ingestLiveTick` now upserts `devices/{deviceId}.lastSeenAt`/`.lastKnownBattery`/`.lastKnownRssi`/`.connectivityStatus` for every device present in that tick's `deviceBattery`/`deviceRssi` maps. §1.7 already *documented* these as Cloud-Function-written, but no function ever actually wrote them — `deviceHeartbeatMonitor`'s disconnect check reads `lastSeenAt`, which was therefore always `null`, so the check could never fire. `deviceHeartbeatMonitor` itself now also marks a timed-out device `connectivityStatus: "disconnected"` and skips re-alerting a device already flagged, fixing an unbounded-repeat-alert issue in the same pass.
  2. **New additive optional fields**: `devices/{deviceId}.mountLocation` (`shin_guard`/`compression_sleeve`/`thigh_band`, coach-settable) and `.laterality` (`left`/`right`, coach-settable) close two previously-documented-but-unimplemented gaps (ADR-070's Universal Pod research recommendation, and the Bluetooth architecture doc's "two Pods per player need distinct logical IDs" gap). `devices/{deviceId}.connectivityStatus` (`online`/`offline`/`low_battery`/`charging`/`disconnected`/`unknown`) is a new real-time telemetry field, explicitly distinct from the existing `status` (administrative/inventory lifecycle — unchanged). `sessions/{id}/live/current.deviceRssi` and `.capturePhase` (`recording`/`paused`/`uploading`) mirror `deviceBattery`'s existing optional pattern.
- **Reason:** Section 2/3/4 of this phase's brief asked for a Firestore ownership/completeness audit and a production-ready BLE device/battery contract. Reading every Cloud Function's write path directly (not just the spec prose) surfaced the telemetry write gap as a real, confirmed bug — not a hypothetical one — that would have silently prevented the device-disconnect alert from ever firing during a real pilot session.
- **What this does not do:** does not touch `vikzar-ai`'s `HardwareProvenance` schema (ADR-070's locked ETL→AI boundary is unaffected — this is purely the Firestore/coach-management side); does not change or redefine the locked, deployed `sessions.status` enum (`live`/`completed`/`completed_with_gaps`/`aborted`) — `capturePhase` is a separate, optional, laptop-console concept that coexists with it; does not fabricate RSSI or charging-state data — those wire fields exist and validate correctly but nothing currently populates them, honestly left unset rather than invented.
- **Status:** Accepted.
- **Date:** 2026-07-22

**Documented in full in:** `BACKEND_SPECIFICATION.md` §1.7, §1.9, §21.4; `functions/src/contracts/types.ts`; `functions/src/callable/ingestLiveTick.ts`; `functions/src/scheduled/deviceHeartbeatMonitor.ts`.

### ADR-072: Phase 13 — Keep the `workspaces` Model; Reject Collapsing to a Single `role` Enum

- **Decision ID:** ADR-072
- **Decision:** The Phase 13 brief's first draft asked for "every authenticated user has exactly one role." The final, locked brief corrected this itself to the account's actual model: one Firebase Auth account, one `users/{uid}` document, one-or-more `workspaces` (`player`/`coach`), one `defaultWorkspace` — matching ADR-031 exactly, not replacing it. This ADR records that the two drafts were reconciled *before* any code was written, and that the existing `workspaces` model was correct all along.
- **Reason:** ADR-031's dual-workspace model already satisfied every real requirement behind "exactly one role, backend-verified, chosen immediately after auth": Workspace Selection already asks Player/Coach right after authentication; `workspaces.{type}`/`defaultWorkspace` are already server-persisted Firestore fields (`user_repository_impl.dart`), never local-only; routing was already split into two independent `StatefulShellRoute` trees with zero `if (role == coach)` branching. Collapsing to a single-role enum would have deleted real, working, tested dual-workspace switching (`workspace_switch_sheet.dart`) and directly contradicted the brief's own "existing players may upgrade later, both flows should coexist" — an upgrade only makes sense as *adding* a workspace.
- **What Phase 13 actually changed under this heading:** closed the one real Security Rules gap that undermined "the backend always owns this state" (see ADR-073's `users/{uid}` create-allowlist fix) and added a "Switch Workspace" row directly on the Profile screen (previously only reachable via the top-bar ProfileBadge sheet).
- **Status:** Accepted.
- **Date:** 2026-07-23

### ADR-073: Phase 13 — Firestore Rules Security Fixes

- **Decision ID:** ADR-073
- **Decision:** Four fixes, all in `firestore.rules`, following a full line-by-line adversarial audit of all 12 pre-existing collections (result: 2 exploitable gaps, 2 data-integrity-only hardening items — no other collection had a genuine issue):
  1. **`users/{uid}` create** — previously `if isSelf(uid)` with no field allowlist at all, letting a signing-up client self-write `careerStats` (documented Cloud-Function-only) or an arbitrary `primaryOrgId`. Now uses the same allowlist as `update`, plus requires the embedded `uid` field to match the document ID.
  2. **`devices/{deviceId}` update** — previously only checked the coach was authorized for the device's *current* team, letting a coach of Team A reassign a device into Team B, which they don't coach. Now requires authorization on both ends. Fixing this surfaced a related pre-existing bug: `isCoachOfTeam(null)` (called for a pooled/unassigned device) called `get()` on an invalid path and always denied — pooled devices could never actually be claimed by any coach. `isCoachOfTeam` is now null-safe, and the update rule explicitly allows a null current/target team (pool claim/release).
  3. **`teams/{teamId}/members` self-join create** — allowlisted to the exact fields Join Team writes (`uid`/`displayName`/`role`/`status`/`joinedAt`); previously unrestricted, though not exploitable (nothing read the extra fields for authorization).
  4. **`alerts` update** — `acknowledgedBy`, if present, must now equal the caller's own uid; previously a coach could stamp a different coach's uid as the acknowledger.
- **Reason:** Direct request from Phase 13 §6/§7, which specifically named the `users` and `devices` gaps as "already identified and must be fixed" — confirmed independently via the audit, then fixed exactly as found, not assumed.
- **Status:** Accepted.
- **Date:** 2026-07-23

**Documented in full in:** `firestore.rules`; `SECURITY_THREAT_MODEL.md`.

### ADR-074: Phase 13 — Cloud Functions Hardening (teamId Derivation, Range/Length Validation, Rate Limiting, maxInstances)

- **Decision ID:** ADR-074
- **Decision:**
  1. **Real gap, fixed**: `ingestLiveTick`/`submitAlert`/`submitReport` previously trusted the ingestion principal's *claimed* `teamId` directly. They now fetch the referenced `sessions/{sessionId}` document first and derive `teamId` from the stored value, matching `completeSession`'s already-correct pattern — a principal scoped to Team A that knew/guessed a Team-B `sessionId` could previously mislabel or misroute data.
  2. **Validation hardening**: `lib/validation.ts` gained `requireNumberInRange`/`optionalNumberInRange` (documented 0.0–1.0 fields: `riskScore`, `confidence`, `dataCompleteness`, `overallRiskScore`; non-negative-only where no documented upper bound exists, e.g. `currentLoad`, `score`/`contribution` in `ContributingFactor` — deliberately *not* assumed to be 0–1, since §21.6's own example uses raw values like 41/12.3), `requireBoundedString`/`optionalBoundedString` (length caps on free-text fields), and `requireExactShape` (rejects unknown top-level/nested-object fields — every `parse*Payload` now calls this first).
  3. **Rate limiting**: `lib/rateLimit.ts`'s `enforceRateLimit`, a Firestore-doc-backed fixed-window counter (`_rateLimits/{action}_{principalId}`, Cloud-Function-only per rules), applied to `ingestLiveTick` (20/sec/principal) and `createPlannedSession` (10/min/coach) — the two highest-frequency/cost endpoints. Deliberately not applied everywhere: the other laptop Callables are inherently low-frequency (once per session), and general-purpose Auth/Callable-flood protection belongs at the Firebase App Check / GCP Console level (documented, not hand-rolled — see ADR-076).
  4. **Budget guard**: `setGlobalOptions({ maxInstances: 20 })` in `functions/src/index.ts` — a real, code-doable ceiling against a runaway trigger loop.
- **Reason:** Direct requests from Phase 13 §7 ("never trust frontend values"), §8 (validation), §10 (rate limiting), §14 (budget protection) — each backed by a specific, confirmed gap found by reading every function directly, not a generic checklist.
- **Status:** Accepted.
- **Date:** 2026-07-23

**Documented in full in:** `functions/src/lib/validation.ts`, `functions/src/lib/rateLimit.ts`, `functions/src/index.ts`, `functions/src/callable/{ingestLiveTick,submitAlert,submitReport}.ts`; `SECURITY_THREAT_MODEL.md`.

### ADR-075: Phase 13 — `plannedSessions` Collection and Coach Workspace Remap (5 Tabs → 4)

- **Decision ID:** ADR-075
- **Decision:** Two connected changes:
  1. **New `plannedSessions/{plannedSessionId}` collection** — a coach-scheduled training/match slot, deliberately distinct from the laptop-authored `sessions/{sessionId}` (§1.8), which represents a real hardware capture and remains exclusively laptop-authored via `startSession`. Created only via `createPlannedSession`, a **Coach-callable** Cloud Function (a new category — every prior Callable was laptop-ingestion-only) authorized by `lib/coachAuth.ts`'s `requireCoachOfTeam`, which derives authorization from `teams/{teamId}.coachIds` in Firestore, never from a client-claimed `teamId`/role. `onPlannedSessionCreated` fans out `session_scheduled` notifications (an additive `NotificationType`) to the team's active roster.
  2. **Coach bottom-nav remapped** from Home/Live/Team/Alerts/Profile to Dashboard/Players/Sessions/Profile. Live dropped entirely (100% `ComingSoonScreen` placeholder, nothing real lost). Alerts dropped as a standalone tab but its screen/controller/repository/acknowledge-flow are preserved, reached from a new, real "Active Alerts" card on the Dashboard. Team renamed to Players (identical screen/content). Sessions is genuinely new: "Upcoming Sessions" is real (`plannedSessions`); "Session History" is an honest empty state, since it would read from real hardware captures that don't exist yet — no fake "create session" form was built against the locked `sessions` collection, which a coach client cannot legitimately write to.
- **Reason:** Direct request from Phase 13 §2/§5, including the explicit architecture: "Coach → Callable Cloud Function → Backend Validation → Firestore → Cloud Functions → Players Updated" — implemented exactly as specified, as a new collection rather than repurposing the locked `sessions` schema (which would have corrupted its `pipelineVersion`/`generatedBy` invariants, only meaningful for a real capture).
- **Status:** Accepted.
- **Date:** 2026-07-23

**Documented in full in:** `BACKEND_SPECIFICATION.md` (pending §1.13/§17 update), `functions/src/callable/createPlannedSession.ts`, `functions/src/triggers/onPlannedSessionCreated.ts`, `lib/features/sessions/`, `lib/routing/app_router.dart`, `lib/routing/shells/app_shell_scaffold.dart`.

### ADR-076: Phase 13 — Firebase App Check (Client-Side Wired, Not Yet Enforced) and Admin-Claim Pattern for Coach Approval

- **Decision ID:** ADR-076
- **Decision:** Two additive, deliberately incomplete pieces, both honestly documented as such:
  1. **App Check**: `lib/services/firebase/app_check_service.dart` activates the App Check SDK on every platform (debug provider in debug builds, Play Integrity/App Attest in release; Web only if a reCAPTCHA v3 site key is supplied via `--dart-define`, since none is committed to this repo). `functions/src/lib/appCheck.ts` documents the exact rollout order but does **not** set `enforceAppCheck: true` on any function yet — doing so before every real client sends tokens (and before the project owner registers this app with each attestation provider in their respective Consoles) would instantly break every existing install, including the laptop ingestion pipeline, which needs its own separate App Check registration path.
  2. **`approveCoachRequest`**: the backend half of Become-a-Coach approval (§3's "if approved: workspaces.coach = true"). Gated by a new `admin: true` custom claim (`lib/adminAuth.ts`), mirroring the existing `ingestor: true` pattern exactly. Sets `workspaces.coach = {teamIds: []}` on the requesting user and `coachRequests/{id}.status = 'approved'` — never touches `defaultWorkspace` (approval adds a workspace, per ADR-031/ADR-072, never silently switches which one is primary). No admin UI was built this phase (none is specified anywhere in the brief); provisioning the admin principal's custom claim is a project-owner Console/Admin-SDK action, the same category as ADR-050's Firebase project connection and the ingestion principal's own provisioning (§3).
- **Reason:** Direct requests from §9 (App Check) and §3 (coach approval) — implemented as far as code alone can go, with the remaining Console-dependent steps named explicitly rather than silently left undone.
- **Status:** Accepted.
- **Date:** 2026-07-23

**Documented in full in:** `lib/services/firebase/app_check_service.dart`, `functions/src/lib/appCheck.ts`, `functions/src/lib/adminAuth.ts`, `functions/src/callable/approveCoachRequest.ts`.
