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
- **Status:** Accepted — blocked on the project owner's manual action.
- **Date:** 2026-07-20

**Documented in full in:** [`firebase_options_placeholder.dart`](lib/firebase_options_placeholder.dart), [`bootstrap.dart`](lib/app/bootstrap.dart).
