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
