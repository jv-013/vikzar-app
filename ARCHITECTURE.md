# Vikzar Engineering Architecture

**Status:** Foundation architecture — Phase 1 of [ROADMAP.md](ROADMAP.md), revised in Phase 1.6 to align with the approved laptop-centric MVP architecture (§7, §14; [ADR-030](DECISIONS.md#adr-030-laptop-centric-ble-etl-and-ml-pipeline-for-mvp)).

This document is the engineering blueprint for the Vikzar application. It is the technical counterpart to [SPECIFICATION.md](SPECIFICATION.md): the specification defines *what* the product does, this document defines *how* it is built. Every future implementation phase must follow the decisions recorded here unless a new decision explicitly supersedes one, recorded in [DECISIONS.md](DECISIONS.md).

This document does not contain Flutter code, UI, or widgets. It defines architecture only, per the scope of Phase 1.

Every decision below is evaluated against [PRODUCT_PRINCIPLES.md](PRODUCT_PRINCIPLES.md), in particular: simplicity over feature bloat (1), long-term scalability without overengineering the MVP (7), and long-term maintainability (10).

Each decision below has a corresponding condensed entry in [DECISIONS.md](DECISIONS.md) (ADR-005 onward). This document holds the full reasoning; DECISIONS.md holds the traceable log.

---

## Technology Stack Summary

For quick reference. Full reasoning for each is in the numbered sections below.

| Concern | Choice |
|---|---|
| Application architecture | Pragmatic layered architecture (presentation / domain / data), feature-first |
| State management | Riverpod |
| Navigation | go_router |
| Dependency injection | Riverpod providers (no separate DI framework) |
| Data access pattern | Repository pattern, interfaces in domain layer |
| BLE integration | **MVP: laptop-side responsibility, external to Flutter** (see BACKEND_SPECIFICATION.md). Flutter has no BLE plugin/dependency at MVP. Direct phone-to-wearable BLE is a documented future capability (§7, Future Evolution). |
| Backend platform | Firebase (confirmed by product direction) |
| Authentication | Firebase Authentication |
| Primary database | Cloud Firestore |
| Binary/large data storage | Firebase Storage |
| Server-side logic | Cloud Functions (minimal; validates and ingests already-computed laptop output, never performs computation) |
| Push notifications | Firebase Cloud Messaging |
| AI insight generation | **MVP: laptop-side pipeline** (ETL → feature extraction → ML → Risk Engine), co-located with BLE handling. Firebase only ingests and synchronizes finished results. |
| Offline support | Firestore built-in persistence for Flutter's structured data/permitted writes; laptop-side buffering of live session data is a separate concern (BACKEND_SPECIFICATION.md §19) |
| Crash/error reporting | Firebase Crashlytics |
| Analytics | Firebase Analytics (minimal event set) |
| UI foundation | Material 3, token-driven custom theme |
| Testing | Unit/widget/integration pyramid, Firebase Local Emulator Suite |
| CI/CD | Staged pipeline (analyze → test → build → distribute → gated deploy); specific provider is an open question |

---

## 1. Overall Application Architecture

**Problem:** Vikzar must support seven platforms from one codebase, handle real-time data (BLE + cloud), and remain maintainable for years by a small team, without the ceremony of an enterprise architecture that a product at this stage doesn't need.

**Options Considered:**
1. Strict Clean Architecture — presentation / domain (with explicit use-case classes) / data layers, full dependency inversion at every boundary.
2. Classic MVC.
3. Pragmatic layered architecture — presentation (UI + controllers) / domain (models + repository interfaces) / data (repository implementations + data sources), feature-first, without a dedicated use-case class per operation.

**Pros / Cons:**
- Strict Clean Architecture: excellent testability and boundary discipline, but a use-case class per operation is significant boilerplate for a small MVP team; slows early velocity (conflicts with Principle 7).
- Classic MVC: fast to start, but tends to accumulate logic in controllers/views over time, poor long-term maintainability for a multi-year, multi-platform product (conflicts with Principle 10).
- Pragmatic layered architecture: most of Clean Architecture's testability and separation benefits (repository interfaces, no Firebase/BLE types leaking into UI) without a use-case class for every single operation. Controllers call repositories directly.

**Final Decision:** Pragmatic layered architecture: **Presentation → Domain → Data**, organized feature-first.

- **Presentation layer:** screens, widgets, Riverpod controllers/state notifiers. No direct Firebase/BLE SDK usage.
- **Domain layer:** plain Dart models and repository *interfaces*. No dependency on Firebase, BLE plugins, or Flutter UI.
- **Data layer:** repository *implementations* and data sources (Firestore, Firebase Storage, BLE service, local cache). Implements domain interfaces.

**Reasoning:** Keeps business logic testable and independent of Firebase/BLE specifics (important given both are volatile, platform-sensitive dependencies), without the overhead of a use-case class per operation, which would be disproportionate for an MVP team. Satisfies Principle 7 and 10 simultaneously.

**Impact:** Every feature module (auth, devices, sessions, monitoring, profile, team, insights, notifications) is structured in these three layers. This is the foundation the folder structure (§2) implements directly.

---

## 2. Folder Structure

**Problem:** Need a folder structure that scales to many features across many platforms without becoming unnavigable, and that maps cleanly onto the layered architecture in §1.

**Options Considered:**
1. Layer-first (`lib/presentation/`, `lib/domain/`, `lib/data/` at the top level, features nested inside each).
2. Feature-first (`lib/features/<feature>/` containing its own presentation/domain/data subfolders).
3. Flat structure with no enforced grouping.

**Pros / Cons:**
- Layer-first: makes the architecture visually obvious, but as feature count grows, working on one feature requires jumping between three distant top-level folders — poor day-to-day ergonomics and harder to reason about feature boundaries or eventually extract a feature.
- Feature-first: each feature is self-contained and easy to locate, reason about, and (if ever needed) remove or extract; layering is preserved *within* each feature.
- Flat: fastest initially, degrades quickly, explicitly the kind of structure that becomes unmaintainable at multi-year scale.

**Final Decision:** Feature-first structure.

```
lib/
  app/                      # App bootstrap, root widget, DI/provider scope wiring
  core/                     # Cross-feature primitives: error types, extensions,
                             # connectivity, result/failure types, shared constants
  theme/                    # Design tokens, ThemeData construction (see §21, §22)
  routing/                  # go_router configuration, route guards (see §4)
  services/                 # Cross-cutting infrastructure services:
                             # ble_service, firebase wrappers, notification_service,
                             # logger, analytics
  features/
    auth/
      data/                 # AuthRepositoryImpl, Firebase Auth data source
      domain/                # User model, AuthRepository interface
      presentation/         # Screens, controllers, feature-local widgets
    devices/                # Device viewing & management (assignment, battery, status — data
                             # originates from the laptop pipeline; see BACKEND_SPECIFICATION.md)
    sessions/               # Live sensor streaming & session history
    monitoring/             # Live Team Monitoring (coach)
    profile/                # Player profile
    team/                   # Team management (coach)
    insights/               # AI-powered injury insights
    notifications/          # Notification center
  shared_widgets/           # Reusable presentation-layer widgets used by 2+ features
test/                       # Mirrors lib/ structure 1:1
```

**Reasoning:** Each feature is independently navigable and independently testable; the three-layer split from §1 is preserved inside every feature rather than across the whole app. `core/`, `theme/`, `routing/`, and `services/` hold genuinely cross-cutting code, kept intentionally small to avoid becoming a dumping ground.

**Impact:** All future feature phases (Phases 4–11 of the roadmap) create a new folder under `features/` following this exact internal structure. New cross-cutting infrastructure must justify why it belongs in `core/`/`services/` rather than a feature.

---

## 3. State Management Strategy

**Problem:** Vikzar is stream-heavy (BLE sensor data, Firestore realtime listeners, live team monitoring across multiple players simultaneously) and must remain testable and consistent across seven platforms.

**Options Considered:**
1. Riverpod.
2. BLoC / Cubit.
3. Provider (predecessor to Riverpod).
4. GetX.

**Pros / Cons:**
- Riverpod: first-class, ergonomic support for `Stream`-based providers (a near-exact fit for BLE characteristic streams and Firestore snapshots), compile-time safety, testable without `BuildContext`, doubles as the DI mechanism (see §5), actively maintained.
- BLoC: excellent discipline and separation for very large teams, but the event/state boilerplate per feature is heavier than this team size and MVP timeline warrant.
- Provider: superseded by Riverpod by the same author; fewer footguns avoided (e.g. `ProviderNotFoundException` class of bugs) if using Riverpod directly.
- GetX: fast to write, but its magic (implicit global state, service locator conventions baked in) trades away the compile-time safety and testability that Principle 10 (multi-year maintainability) requires; widely flagged in the Flutter community for degrading maintainability at scale.

**Final Decision:** Riverpod, used for both state management and dependency injection.

**Reasoning:** The dominant technical characteristic of this app is *live streaming data* (BLE + Firestore), and Riverpod's `StreamProvider`/`AsyncNotifier` primitives map directly onto that without adapter boilerplate. It avoids introducing a second DI framework (see §5), and its testability (providers can be overridden in tests without a running widget tree) supports Principle 10.

**Impact:** All controllers/state in the presentation layer are Riverpod providers. Repository and service instances are also exposed as providers (§5, §6). Team members must follow Riverpod conventions (e.g. `Notifier`/`AsyncNotifier` over legacy `StateNotifier` where applicable) — exact conventions to be documented as a short contributor guide when implementation begins.

---

## 4. Navigation Architecture

**Problem:** Navigation must support two structurally different role-based experiences (Player, Coach), adapt its chrome (bottom nav vs. rail vs. sidebar) across form factors without duplicating route logic, and guard routes based on auth/role state.

**Options Considered:**
1. go_router.
2. Imperative `Navigator` 1.0.
3. auto_route (codegen-based).

**Pros / Cons:**
- go_router: declarative, URL-based (future Web-compatible per ADR-002's Web-compatibility requirement), first-class support for nested/shell routes (needed for role-based shells) and `redirect` logic (needed for auth guarding), maintained by the Flutter team itself.
- Imperative Navigator 1.0: simplest to start, but auth guarding and deep-linking become manual and error-prone, and it does not naturally express shell/nested navigation for adaptive chrome.
- auto_route: similar capabilities to go_router via code generation, but adds a build_runner dependency and generated-code layer for a benefit go_router already provides without codegen.

**Final Decision:** go_router, with two role-based shell routes (Player shell, Coach shell), each containing that role's feature routes as children.

**Reasoning:** Declarative routing with `redirect` cleanly expresses "unauthenticated → auth flow" and "authenticated but wrong role → role home" without ad hoc navigation calls scattered through the app. Shell routes let the *navigation chrome* (bottom nav bar on phone → nav rail on tablet → sidebar on desktop) adapt responsively (§20) while the underlying route tree stays identical across platforms — one route tree, adaptive presentation.

**Impact:** Route guarding (auth state, role) is centralized in `routing/`, not duplicated per screen. Adding a new top-level feature means adding a route to the appropriate shell, not restructuring navigation.

---

## 5. Dependency Injection Strategy

**Problem:** Repositories, services, and controllers need their dependencies (e.g. a repository needs a Firestore instance; a controller needs a repository) provided in a consistent, testable, swappable way.

**Options Considered:**
1. Riverpod providers as the DI mechanism.
2. `get_it` service locator.
3. Manual constructor injection wired by hand at the app root.

**Pros / Cons:**
- Riverpod-as-DI: one system for both state and dependency graph — no need to learn or maintain two frameworks; dependencies are overridable in tests the same way state is.
- `get_it`: mature and widely used, but running it *alongside* Riverpod means two separate mechanisms solving overlapping problems, adding cognitive overhead for no functional gain given Riverpod already covers this.
- Manual wiring: no dependency, fully explicit, but does not scale as the dependency graph grows across a multi-year, multi-feature app — becomes its own maintenance burden.

**Final Decision:** Riverpod providers serve as the sole dependency injection mechanism. No second DI framework.

**Reasoning:** Directly serves Principle 1 (simplicity) — one mechanism, not two, for closely related problems (state + dependencies). Riverpod's provider-override mechanism gives the same test-substitution benefit `get_it` or manual wiring would provide.

**Impact:** Every repository and service (§6, §7) is exposed as a `Provider` (or `FutureProvider`/family variant as needed). Widgets and controllers obtain dependencies via `ref.watch`/`ref.read`, never via direct instantiation or a global locator.

---

## 6. Repository Pattern

**Problem:** The domain and presentation layers must not depend directly on Firebase or BLE SDKs — both are volatile, platform-sensitive, and this is health-adjacent data that benefits from a clear, testable data-access seam.

**Options Considered:**
1. Repository interfaces in the domain layer, implementations in the data layer (standard repository pattern).
2. Direct Firebase/BLE SDK calls from controllers, no abstraction.
3. A generic/shared repository base class handling all Firestore CRUD generically.

**Pros / Cons:**
- Repository pattern (interfaces + implementations): decouples business logic from Firebase/BLE specifics; enables unit testing with fakes instead of the network/hardware; allows swapping an implementation later (e.g., a data source change) without touching presentation code.
- Direct SDK calls: fastest to write initially, but ties every controller to Firebase/BLE APIs directly, makes testing require the Firebase emulator or real hardware even for simple logic tests, and leaks vendor specifics throughout the app — conflicts with Principle 10.
- Generic repository base class: reduces boilerplate for simple CRUD, but Vikzar's actual data access is not uniform CRUD (live streams, health-adjacent access rules, raw-vs-summary data routing per §10) — a generic abstraction would leak or be bypassed constantly, becoming a false abstraction.

**Final Decision:** One repository interface + implementation per feature-relevant aggregate (e.g. `AuthRepository`, `DeviceRepository`, `SessionRepository`, `TeamRepository`, `InsightRepository`, `NotificationRepository`). Interfaces live in each feature's `domain/`, implementations in `data/`, exposed to the rest of the app via Riverpod providers (§5).

**Reasoning:** Directly supports Principle 10 (the Firebase/BLE dependency is the most likely thing to need adaptation over a multi-year lifespan) and Principle 7 (this is proportionate abstraction, not speculative — it is applied only at genuine external-system boundaries, not internally between layers of pure logic).

**Impact:** No feature's presentation or domain code imports `cloud_firestore`, `firebase_storage`, or a BLE plugin package directly. Only `data/` implementation files do.

---

## 7. BLE Architecture

**Status: revised in Phase 1.6.** This section originally (Phase 1) designed a Flutter-side `BleService`. That design was superseded by [DECISIONS.md ADR-030](DECISIONS.md#adr-030-laptop-centric-ble-etl-and-ml-pipeline-for-mvp) once the approved system architecture was clarified: **all Bluetooth communication, ETL, feature extraction, machine learning inference, and risk prediction are performed by a laptop-based pipeline, external to this Flutter codebase, for the MVP.** The Flutter application does not connect to Smart Pods or EMG Thigh Bands directly during the MVP. It consumes only already-processed data, synchronized via Firebase, exactly as specified in [BACKEND_SPECIFICATION.md](BACKEND_SPECIFICATION.md). The original Flutter-side design is preserved below, under "Future Evolution," as a deliberately deferred (not discarded) pattern.

**Problem:** Where should Bluetooth connectivity and sensor-data processing happen for the MVP, given that Firebase must never perform ETL, feature extraction, machine learning, or risk prediction (a non-negotiable constraint established in [BACKEND_SPECIFICATION.md §0](BACKEND_SPECIFICATION.md#0-system-actors-and-trust-boundaries)), and given that this computation must happen *somewhere* before Live Team Monitoring or session history can show anything meaningful?

**Options Considered:**
1. **Laptop-centric (approved):** A laptop, external to the Flutter app, owns the entire Bluetooth-to-Firebase pipeline (BLE connection → ETL → feature extraction → ML inference → Risk Engine), and submits only finished results to Firebase via the Cloud Function ingestion contract in [BACKEND_SPECIFICATION.md §17](BACKEND_SPECIFICATION.md#17-cloud-function-responsibilities) and [§21](BACKEND_SPECIFICATION.md#21-upload-contract-for-the-laptop). The Flutter app has no BLE dependency at all for MVP.
2. **Flutter-side `BleService`** (the original Phase 1 design): the Flutter app itself connects to hardware over BLE, and some unspecified cloud-side compute performs ETL/ML behind a Cloud Function trigger.
3. **Hybrid:** both paths exist simultaneously at MVP (laptop for supervised team sessions, phone BLE for unsupervised solo sessions).

**Pros / Cons:**
- Laptop-centric: matches the explicitly approved MVP architecture (Sensors → Bluetooth → Laptop → ETL → ML → Risk Engine → Firebase → Flutter); a laptop's BLE central role is materially more capable of holding many simultaneous peripheral connections reliably than a phone, which matters directly for Live Team Monitoring (one laptop pitchside connecting to an entire squad's devices at once); keeps the Flutter app thin and free of the single most platform-fragile dependency (BLE plugin behavior varies by OS) across all seven target platforms; leaves zero ambiguity about where the "never performs ML" constraint is enforced, since Flutter simply has no path to raw sensor data at all.
- Flutter-side `BleService`: was a reasonable design under the (now corrected) Phase 1 assumption that the app itself streamed sensor data; it does not match the approved MVP architecture and would require re-deciding where ETL/ML runs, reopening a question this phase closes.
- Hybrid: doubles the number of live data-origination paths the backend must trust and validate (§3 of BACKEND_SPECIFICATION.md's ingestion-principal model), doubles the surface needing ETL/ML/risk-prediction logic (once on the laptop, once wherever the solo path runs), and was not what was approved for MVP. Rejected for MVP as unnecessary complexity (Principle 7); documented instead as a candidate for the Future Evolution path below, since it does not require re-architecting the backend to add later.

**Final Decision:** Laptop-centric, for MVP. The Flutter application has **no BLE plugin, no `BleService`, and no `DeviceProtocol` adapters** in its MVP dependency graph. Its only relationship to hardware is indirect: reading `devices/{deviceId}` documents (assignment, battery, status) that the laptop pipeline keeps updated via Cloud Functions, per [BACKEND_SPECIFICATION.md §7](BACKEND_SPECIFICATION.md#7-device-ownership-model) and [§22](BACKEND_SPECIFICATION.md#22-flutter-read-contract). All BLE connectivity, ETL, feature extraction, ML inference, and Risk Engine responsibilities belong to the laptop pipeline, which is a separate system outside this Flutter codebase's architecture and is specified in [BACKEND_SPECIFICATION.md](BACKEND_SPECIFICATION.md), not here.

**Reasoning:** This resolves, in the laptop's favor, the exact conflict flagged in [BACKEND_SPECIFICATION.md's original Open Questions](BACKEND_SPECIFICATION.md#open-questions) between this document's Phase 1 sketch and the backend contract's assumed system diagram. Concentrating all sensor-processing risk on one purpose-built machine (rather than distributing it across every player's phone/tablet, each with different OS-level BLE behavior) is the more maintainable, more testable, and more centrally-auditable choice for a safety product, and it removes what was previously flagged as "the architecture's single largest technical risk" (§ Risks) from the Flutter application's scope entirely for MVP.

**Impact:** [ARCHITECTURE.md §12](#12-cloud-functions-responsibilities) and [§14](#14-ai-analysis-pipeline) are revised accordingly (this same phase) to describe Cloud Functions as validating and ingesting already-computed laptop output, never orchestrating computation themselves. [SPECIFICATION.md](SPECIFICATION.md) removes "BLE Device Connection" from the Flutter MVP feature list and reclassifies it as a future capability, per [ROADMAP.md](ROADMAP.md)'s "Out of Scope for This Roadmap" section. See "Future Evolution" at the end of this document for how direct phone-to-wearable BLE can be added later without any change to the backend architecture described here or in BACKEND_SPECIFICATION.md.

---

## 8. Cloud Architecture

**Problem:** Vikzar needs a cloud backend for auth, structured data, large binary data, server-side logic, and push delivery — built and maintained by a small team, at MVP budget and velocity.

**Options Considered:**
1. Firebase (Auth, Firestore, Storage, Cloud Functions, Cloud Messaging) as an integrated platform.
2. A custom backend (e.g. a REST/GraphQL API on a self-managed or bespoke cloud service) with a separate managed database.
3. A different BaaS platform (e.g. Supabase).

**Pros / Cons:**
- Firebase: this phase's product direction explicitly names Firestore, Firebase Storage, and Cloud Functions, so this option reflects a decision already made at the product level, not merely an architectural preference. Independently, it offers realtime listeners that map directly onto Live Team Monitoring and live session streaming, integrated Auth/rules-based security, no separate backend infrastructure to build or operate (serves Principle 10 for a small team), and mature Flutter SDK support across the target platforms.
- Custom backend: maximum control and no vendor lock-in, but requires building and operating infrastructure (hosting, scaling, auth, realtime transport) that Firebase provides out of the box — a poor fit for Principle 1/7 at MVP stage, and unnecessary given no requirement has been identified that Firebase cannot meet.
- Supabase: comparable BaaS capabilities (Postgres-based), but was not the platform named in product direction, and switching would contradict the explicit Firestore/Storage/Cloud Functions direction given.

**Final Decision:** Firebase as the complete backend platform: **Firebase Authentication, Cloud Firestore, Firebase Storage, Cloud Functions, Firebase Cloud Messaging**, with **Firebase Crashlytics** and **Firebase Analytics** added for logging/analytics (§17, §21) to avoid introducing additional vendors for adjacent, commonly-bundled concerns.

**Reasoning:** Confirms and formalizes the product-level direction; a single integrated platform minimizes operational surface area for a small team (Principle 10) while its realtime primitives are a strong technical fit for Vikzar's live-monitoring core (Principle 3).

**Impact:** All data-layer implementations (§6) are Firebase-backed. Vendor lock-in to Google Cloud is an accepted, explicit tradeoff (see Risks). Firestore's query/join limitations must be designed around at the data-model level (§10), not worked around with ad hoc client logic.

---

## 9. Authentication Architecture

**Problem:** Players and Coaches need to authenticate, and the app needs to know a user's role in order to route and authorize them correctly.

**Options Considered:**
1. Firebase Authentication, with role stored as a field in a Firestore user profile document.
2. Firebase Authentication, with role stored in Auth custom claims (set via a Cloud Function).
3. A custom authentication service independent of Firebase.

**Pros / Cons:**
- Firebase Auth + Firestore-stored role: simplest to implement and reason about at MVP; the app already reads the user's Firestore profile on login for other reasons (name, team, etc.), so role comes along with it at no extra cost; downside is that Firestore Security Rules checking role require an extra document read within the rule (a well-documented, standard Firestore pattern, not a real limitation at this scale).
- Firebase Auth + custom claims: claims are directly available on the auth token, which is marginally more efficient inside security rules and removes trust in a client-readable document for authorization decisions — but requires a Cloud Function to set claims on role change and a client-side token refresh to pick them up, adding a moving part with no corresponding MVP-stage benefit.
- Custom auth service: rejected outright given Firebase is the confirmed platform (§8); would duplicate what Firebase Auth already provides.

**Final Decision:** Firebase Authentication for identity. Workspace membership (Player/Coach) is stored as a field on the user's Firestore profile document (`users/{uid}.workspaces` — revised from a single `role` enum to a structured multi-workspace object at the Phase 2 freeze review, per [DECISIONS.md ADR-031](DECISIONS.md#adr-031-single-application-with-player-and-coach-workspace-switching); see [BACKEND_SPECIFICATION.md §1.5](BACKEND_SPECIFICATION.md#1-complete-firestore-schema) for the exact shape), read on sign-in and exposed via a Riverpod `StreamProvider` watching `authStateChanges()` combined with the profile document. This provider drives `go_router` redirects (§4).

**Reasoning:** Matches MVP scope (Principle 1, 7): the simpler mechanism is sufficient because Firestore Security Rules can read the user's own profile document cheaply, and role changes are expected to be infrequent, non-latency-sensitive events. Custom claims are recorded below as a documented future hardening path, not dismissed.

**Impact:** Authorization checks in Firestore/Storage Security Rules (§19) reference `get(/databases/$(database)/documents/users/$(request.auth.uid)).data.workspaces` (or equivalent) rather than a custom auth-token claim. If a future phase identifies a concrete need for token-level trust (e.g. very high-frequency rule evaluation at scale), migrating to custom claims is a contained, additive change — noted here so it isn't rediscovered from scratch later.

**Open item:** Which sign-in methods are offered at MVP (email/password only vs. also Google/Apple sign-in) is not decided by this document — see Open Questions.

---

## 10. Firestore Data Model

**Problem:** Define a Firestore structure that supports Player/Coach access patterns (own data, team data), Live Team Monitoring's realtime needs, and session history, while respecting Firestore's actual constraints (no joins, document size limits, cost scales with reads/writes, poor fit for high-frequency raw time-series writes).

**Options Considered:**
1. Structured, purpose-fit collections: separate collections for users, teams, sessions, devices, insights, notifications; session *summaries* in Firestore, raw high-frequency sensor data routed to Firebase Storage.
2. Store everything, including raw per-sample sensor data, directly in Firestore documents/subcollections.
3. A single denormalized "everything" document per user containing nested session/team data.

**Pros / Cons:**
- Structured collections + summary/raw split: keeps Firestore documents small and Firestore's per-document write-rate and size limits are never at risk from raw sensor data; Storage is well-suited to large sequential blobs; realtime listeners on session *summary* documents are cheap and exactly what Live Team Monitoring needs (it needs current status/metrics per player, not every raw sample, in the UI layer).
- Everything in Firestore, including raw samples: BLE sensor data during a live session can be high-frequency; writing every sample as Firestore documents risks hitting per-document write-rate limits and unnecessary cost, and raw time-series data is not naturally query-shaped data Firestore is designed for.
- Single denormalized "everything" document: fails immediately under Firestore's 1 MiB document size limit as session/team history accumulates, and defeats granular Security Rules (Player vs Coach access needs to be enforced per-resource, not inside one giant blob).

**Final Decision:** Structured, purpose-fit collections:

- `users/{uid}` — profile fields, `workspaces` (per-workspace team association(s); an account may hold a Player workspace, a Coach workspace, or both), `defaultWorkspace`.
- `teams/{teamId}` — team name, coach reference; `teams/{teamId}/members/{uid}` subcollection for roster.
- `sessions/{sessionId}` — `playerId`, `teamId` (nullable for non-team sessions), `type` (training/match), `status` (live/completed), `startedAt`, `endedAt`, and *summary* metrics only (aggregated, small).
- Raw, high-frequency sensor data for a session is written to **Firebase Storage** (§11), referenced from the session document by path — not stored as Firestore documents.
- `devices/{deviceId}` — pairing metadata, owner reference, device type, last-connected timestamp.
- `insights/{insightId}` — reference to `sessionId`/`playerId`, generated content, severity, generation timestamp, source/model version.
- `users/{uid}/notifications/{notificationId}` — in-app notification records (subcollection, per Player/Coach recipient).

**Reasoning:** Aligns each data shape with the store best suited to it (structured/queryable → Firestore; large sequential blob → Storage), which is a direct consequence of §8's platform choice and its known constraints, not a separate speculative decision. Subcollections (team members, notifications) keep parent documents small and access rules scoped naturally.

**Impact:** This is the schema all Firestore-backed repositories (§6) implement against. Exact field-level schema (types, required/optional fields, indexes) is deferred to the implementation of each feature phase, since inventing full field lists now — before a single screen is designed — would be exactly the kind of premature detail this document is meant to avoid; the *shape* (collections, relationships, summary/raw split) is what's being fixed here.

---

## 11. Firebase Storage Usage

**Problem:** Some Vikzar data is large, binary, or high-frequency and does not belong in Firestore documents (§10).

**Options Considered:**
1. Firebase Storage for raw session sensor exports and user-facing images (avatars), namespaced by owner.
2. Store all binary data as Firestore document fields (base64-encoded).
3. A separate, non-Firebase object storage provider.

**Pros / Cons:**
- Firebase Storage: purpose-built for exactly this (large files, byte streams), integrates with the same Security Rules model and Auth identity as the rest of the chosen platform (§8), no second vendor.
- Base64-in-Firestore: violates Firestore's 1 MiB document limit almost immediately for any real sensor session, and is a well-known anti-pattern.
- Separate non-Firebase storage: contradicts the confirmed single-platform direction (§8) without a demonstrated need it uniquely serves.

**Final Decision:** Firebase Storage holds: (a) raw/full-resolution session sensor data exports (referenced from the corresponding `sessions/{sessionId}` Firestore document), and (b) user-facing images such as profile avatars. Storage paths are namespaced by owner/session (e.g. `sessions/{sessionId}/raw`, `users/{uid}/avatar`).

**Reasoning:** Direct consequence of §8 and §10 — keeping this decision consistent with the rest of the platform choice rather than introducing a second storage vendor for no identified benefit.

**Impact:** Storage Security Rules (§19) must mirror the same Player/Coach access logic as Firestore rules. The raw data format itself (binary/JSON/CSV) is an implementation detail deferred to the Live Sensor Streaming phase (Roadmap Phase 6), not decided here.

---

## 12. Cloud Functions Responsibilities

**Problem:** Some logic must run server-side (trust boundary, trigger-driven work) rather than on-device, but Cloud Functions usage should be deliberate, not a dumping ground for logic that could live client-side.

**Options Considered:**
1. Minimal, trigger-driven Cloud Functions scoped to work that genuinely requires server-side execution.
2. Route all business logic through Cloud Functions (a "thin client" approach).
3. No Cloud Functions; handle everything client-side plus Security Rules.

**Pros / Cons:**
- Minimal, trigger-driven: keeps the client capable and responsive (most logic stays client-side, close to the UI it serves) while reserving server-side execution for what actually needs it — trust, cross-user side effects, or external service orchestration.
- "Thin client" (everything server-side): adds latency and operational complexity to interactions that don't need it, and works against Principle 7 (overengineering relative to MVP needs).
- No Cloud Functions at all: cannot provide a trusted server-side entry point to validate and ingest the laptop pipeline's AI-generated insights (§14, Spec §7.8), nor trigger push notifications server-side — both need execution the client cannot itself perform (a client cannot validate a laptop's ingestion scope, nor dispatch FCM to *other* users' devices, e.g. a coach's, from a player's session).

**Final Decision:** Cloud Functions are used only for:
1. **Validating and ingesting already-computed data submitted by the laptop pipeline** (session lifecycle, live monitoring ticks, alerts, reports) via a fixed set of HTTPS Callable functions, and fanning out derived/denormalized views such as live team monitoring — §14, and specified exactly in [BACKEND_SPECIFICATION.md §17](BACKEND_SPECIFICATION.md#17-cloud-function-responsibilities).
2. Dispatching push notifications via FCM in response to relevant Firestore writes (e.g. new alert, new report, team invite) — §13.
3. Server-side validation/enforcement of invariants a client cannot be trusted to enforce itself (e.g. team membership or role changes with cross-user effects).
4. Scheduled maintenance/aggregation of already-computed values (e.g. rolling up existing session summaries into a weekly report, or checking a device heartbeat timeout) — arithmetic and timeout-checking only, never new signal analysis, per the constraint in [BACKEND_SPECIFICATION.md §0](BACKEND_SPECIFICATION.md#0-system-actors-and-trust-boundaries).

**Revision note (Phase 1.6):** Item 1 originally read "triggering the AI insight pipeline," which implied Cloud Functions might kick off further computation behind the scenes. [ADR-030](DECISIONS.md#adr-030-laptop-centric-ble-etl-and-ml-pipeline-for-mvp) closes that ambiguity: Cloud Functions never trigger or perform computation — all computation happens on the laptop before a Cloud Function is ever called. Cloud Functions only validate and persist results that already exist.

**Reasoning:** Each responsibility above is something that *specifically requires* server-side trust or cross-user orchestration — the test applied is "could this safely and correctly happen on the client instead?"; if yes, it stays client-side per Principle 7. None of them involve Cloud Functions performing ETL, feature extraction, ML inference, or risk prediction, consistent with the non-negotiable constraint in BACKEND_SPECIFICATION.md §0.

**Impact:** Cloud Functions codebase stays small and auditable by design. Feature phases must justify any new Cloud Function against this four-item list rather than defaulting to "put it in a function."

---

## 13. Notification Architecture

**Problem:** Players and Coaches need timely notifications (e.g. new insight available, live session alerts, team invites) delivered both as OS-level push and as an in-app, persistent record.

**Options Considered:**
1. Firebase Cloud Messaging (push) triggered by Cloud Functions, backed by a Firestore `notifications` subcollection for in-app persistence/read state.
2. Push notifications only, no in-app record (ephemeral).
3. In-app notification center only, no OS push.

**Pros / Cons:**
- FCM + Firestore subcollection: covers both the moment-of-event alert (push) and the ability to review notification history later (in-app), and reuses the already-chosen platform (§8) rather than adding a push vendor.
- Push-only: loses any notification a user didn't see/act on in the moment — a poor fit for safety-relevant alerts, which Vikzar's core purpose makes unacceptable.
- In-app-only: fails the "timely" requirement — a coach not currently in the app would miss a live alert entirely.

**Final Decision:** Firebase Cloud Messaging for push delivery, triggered by Cloud Functions (§12) on relevant Firestore writes. A `users/{uid}/notifications` Firestore subcollection (§10) is the durable, in-app, read-state-tracked record. Foreground presentation on each platform uses standard OS/local-notification handling as appropriate per platform.

**Reasoning:** Push and in-app records serve different, both-necessary purposes (immediacy vs. durability/review) — this isn't two systems for one job, it's the standard pairing for reliable notification delivery, and it's consistent with the already-confirmed platform.

**Impact:** The `notifications` feature module (§2) owns rendering the in-app record; `services/notification_service` owns FCM token registration and foreground handling. Exact notification types/copy are deferred to Roadmap Phase 11.

---

## 14. AI Analysis Pipeline

**Status: revised in Phase 1.6.** This section originally left the AI pipeline's compute location unspecified ("a hosted model endpoint, a managed ML platform, or a third-party API"), correctly deferring a then-undiscussed decision. [ADR-030](DECISIONS.md#adr-030-laptop-centric-ble-etl-and-ml-pipeline-for-mvp) resolves that question for MVP: the AI pipeline runs entirely on the same laptop that performs BLE/ETL (§7), not on any cloud-hosted compute. The wording "generated in the cloud" in [SPECIFICATION.md §7.8](SPECIFICATION.md#7-mvp-feature-set) has been corrected accordingly — see that document.

**Problem:** Where does injury-risk analysis actually run for MVP, given Firebase must never perform ETL, feature extraction, ML inference, or risk prediction, and given §7 already establishes that raw sensor data never leaves the laptop that received it over Bluetooth?

**Options Considered:**
1. **Laptop-based pipeline (approved):** the same laptop performing BLE/ETL (§7) also performs feature extraction, ML inference, and Risk Engine scoring, and submits only finished alerts/reports/session summaries to Firebase.
2. A Cloud Function-orchestrated pipeline calling an external hosted model or managed ML platform (the original Phase 1 sketch).
3. On-device inference bundled into the Flutter app.

**Pros / Cons:**
- Laptop-based pipeline: co-locates ML with the ETL step that already runs on the same machine (§7), avoiding a redundant network hop for raw sensor data that would otherwise need to leave the laptop just to reach a cloud model; leaves no ambiguity about "what runs behind the trigger," since nothing does — the Cloud Function only ever receives finished output; matches the approved MVP architecture diagram exactly (Laptop → ETL → ML → Risk Engine → Firebase).
- Cloud Function-orchestrated external model: was reasonable when the compute location was still undecided, but now conflicts with the approved architecture, and would mean raw or intermediate sensor data leaving the laptop and transiting Firebase/Cloud Functions — a boundary [BACKEND_SPECIFICATION.md §0](BACKEND_SPECIFICATION.md#0-system-actors-and-trust-boundaries) explicitly forbids ("Firebase never performs ETL, feature extraction, machine learning, or ACL/injury risk prediction").
- On-device inference (Flutter): rejected for the same reason as in the original Phase 1 analysis — adds ML runtime complexity across seven platforms for no stated benefit, and was never the approved design.

**Final Decision:** The AI/Risk Engine pipeline runs entirely on the laptop, alongside BLE/ETL (§7). The Flutter application's role is unchanged in *shape* from the original design — it consumes results — but the mechanism is now precise rather than open: it subscribes to `alerts/{alertId}` and `reports/{reportId}` documents (and `sessions/{sessionId}.summaryMetrics`) via realtime Firestore listeners, populated by the laptop through the Cloud Function ingestion contract (`submitAlert`, `submitReport`, `completeSession`) specified exactly in [BACKEND_SPECIFICATION.md §12–§13](BACKEND_SPECIFICATION.md#12-alert-model) and [§17](BACKEND_SPECIFICATION.md#17-cloud-function-responsibilities), triggering a notification (§13) on arrival.

**Reasoning:** This is a direct consequence of §7's laptop-centric decision — once BLE and ETL are confirmed to run on the laptop, keeping ML and the Risk Engine on the same machine (rather than shipping partially-processed data onward to a separate cloud compute step) is the simpler, more defensible design, and it is what the approved architecture diagram specifies.

**Impact:** The `insights`-equivalent feature module (now realized as the `alerts` and `reports` features per [BACKEND_SPECIFICATION.md §1](BACKEND_SPECIFICATION.md#1-complete-firestore-schema)) depends only on `AlertRepository`/`ReportRepository` interfaces and the Firestore shapes in BACKEND_SPECIFICATION.md — never on any AI provider SDK, since no AI provider SDK exists anywhere in the Flutter or Firebase layers. The specific ML techniques/frameworks used by the laptop pipeline are that pipeline's own concern, outside this Flutter application's architecture.

---

## 15. Offline Strategy

**Status: revised in Phase 1.6.** The original analysis assumed the Flutter app itself buffered in-progress BLE session data locally. Under the laptop-centric architecture (§7), the Flutter app never receives BLE data at all, so it has nothing of that kind to buffer — that responsibility now belongs entirely to the laptop pipeline, specified in [BACKEND_SPECIFICATION.md §19](BACKEND_SPECIFICATION.md#19-offline-synchronization-strategy). This section is narrowed to what remains a genuine Flutter-side concern.

**Problem:** Network connectivity cannot be assumed to be continuous for a Player or Coach using the Flutter app, and the app must remain usable (reading previously-synced data, queuing the small set of permitted client writes) when offline.

**Options Considered:**
1. Rely on Firestore's built-in offline persistence for structured data and its permitted client writes.
2. Build a custom offline-first sync engine with conflict resolution for the Flutter app.
3. Require connectivity for all Flutter functionality (no offline handling).

**Pros / Cons:**
- Firestore built-in persistence: Firestore's SDK already provides local caching and automatic write-queueing at essentially no engineering cost, and matches the Flutter app's actual write surface, which per [BACKEND_SPECIFICATION.md §15](BACKEND_SPECIFICATION.md#15-security-rules-strategy) is now deliberately small (profile edits, alert acknowledgement, notification read-state) — none of it safety-computation data, all of it well-suited to Firestore's standard offline queueing.
- Custom sync engine: solves a much broader problem than the Flutter app actually has, now an even clearer case of overengineering than in the original analysis, since the app no longer originates any session/live/alert/report data itself.
- No offline handling: a Player or Coach loses the ability to review previously-synced history offline, a real but minor usability cost, not a safety-data-loss risk (that risk now lives entirely with the laptop pipeline's own offline resilience, per BACKEND_SPECIFICATION.md §19).

**Final Decision:** Use Firestore's built-in offline persistence for structured/queryable data and for the Flutter app's small set of permitted client writes. No custom sync engine, no custom conflict resolution, no offline authentication, and no client-side session-data buffering of any kind — that responsibility does not exist in the Flutter app under the approved architecture.

**Reasoning:** Solves the Flutter app's actual, now-narrower offline concern using mechanisms already provided by the chosen platform, rather than building offline infrastructure for a live-session-buffering problem the app no longer has (Principle 7).

**Impact:** No feature module needs a local buffering/reconciliation responsibility of the kind originally assigned to `SessionRepository`. Roadmap Phase 6 (Live Sensor Streaming) is correspondingly narrowed to *displaying* laptop-originated live data via Firestore listeners, not capturing or buffering it.

---

## 16. Error Handling

**Problem:** Errors originate from several volatile sources (network, Firebase, BLE/hardware) and must be surfaced to Players and Coaches in a way that stays calm and trustworthy (Principle 8) rather than as raw technical failures — this is especially important given the product's safety-adjacent purpose.

**Options Considered:**
1. Typed failure/result handling: repository methods return a typed success/failure result rather than throwing across layers; presentation maps failure types to calm, user-appropriate messaging.
2. Let exceptions propagate freely and catch them ad hoc in the UI.
3. A single generic "something went wrong" catch-all with no differentiation.

**Pros / Cons:**
- Typed failure/result handling: forces each call site to consciously handle failure (rather than an uncaught exception surfacing a raw stack trace to a user), and lets the same failure type (e.g. `BleConnectionFailure`) be handled consistently everywhere it's relevant.
- Ad hoc exception catching: inconsistent handling across the app is likely at multi-feature scale, and raw exception messages reaching the UI directly conflicts with Principle 8.
- Single generic catch-all: fails to distinguish genuinely different situations a user needs to respond to differently (e.g. "your device disconnected" vs. "you're offline" vs. "sign-in expired") — poor UX for what should be a trustworthy, precise product.

**Final Decision:** Repository and service methods return a typed result (a small `Result<T, Failure>`-style construct) rather than throwing across architectural layers. A shared `Failure` hierarchy in `core/` (e.g. `NetworkFailure`, `AuthFailure`, `BleFailure`, `PermissionFailure`, `UnknownFailure`) is mapped, in the presentation layer, to calm, plain-language user messaging appropriate to each case. Unexpected/unhandled exceptions are still caught at a top-level boundary and reported (§17), never shown raw to the user.

**Reasoning:** Directly serves Principle 8 (the application must feel calm and trustworthy, including when something goes wrong) and Principle 10 (consistent error handling is a maintainability property, not a cosmetic one).

**Impact:** Every repository interface in the domain layer (§6) is written against this failure model from the start, rather than each feature inventing its own error-handling convention independently.

---

## 17. Logging Strategy

**Problem:** The team needs visibility into production issues, but Vikzar handles health-adjacent player data, so logging must be deliberate about what it captures.

**Options Considered:**
1. A thin `AppLogger` abstraction (console output in development, Firebase Crashlytics in production for crash/non-fatal reporting).
2. Direct, unabstracted `print`/platform logging calls throughout the codebase.
3. A third-party dedicated logging/observability service.

**Pros / Cons:**
- `AppLogger` abstraction + Crashlytics: gives a single seam to control what is logged and where (important for keeping health-adjacent data out of logs), reuses the already-adopted platform (§8) rather than adding another vendor, and Crashlytics integrates directly with Flutter's error reporting hooks.
- Unabstracted print/platform calls: no production visibility at all once the app is installed on a user's device, and no consistent point to enforce "don't log sensitive data."
- Third-party observability service: capability roughly equivalent to Crashlytics for this stage, at the cost of a new vendor relationship not justified by any gap Crashlytics has for MVP needs.

**Final Decision:** A small `AppLogger` interface in `services/`, with a development-time console implementation and a production implementation backed by Firebase Crashlytics (non-fatal error + crash reporting). Logging must not include raw sensor/health values or other PII in production log output.

**Reasoning:** Keeps a single vendor family for the whole observability surface (Crashlytics, sitting alongside Analytics — §18) and creates one enforced seam for the privacy constraint that actually matters here (Principle 2's spirit extended to data handling).

**Impact:** Feature code logs through `AppLogger`, never through direct platform print/logging calls, so the "no sensitive data in logs" rule has one place to be enforced and reviewed.

---

## 18. Analytics Strategy

**Problem:** The team needs basic product usage visibility (are people completing onboarding, pairing devices, starting sessions) without over-instrumenting the app or exposing sensitive data through an analytics pipeline.

**Options Considered:**
1. Firebase Analytics, with a small, deliberate set of key events.
2. Exhaustive event tracking (every tap, every screen interaction).
3. No analytics at MVP.

**Pros / Cons:**
- Firebase Analytics, minimal events: answers the actual questions the team needs answered at MVP (funnel completion, core feature adoption) without instrumentation overhead, and reuses the adopted platform (§8).
- Exhaustive tracking: directly conflicts with Principle 1 (simplicity) and creates ongoing maintenance burden (every UI change risks breaking an analytics call) disproportionate to MVP-stage value.
- No analytics: leaves the team unable to tell whether onboarding (Principle 5) is actually short/frictionless in practice, or whether Live Team Monitoring is being used — undermines the ability to validate the product principles against real usage.

**Final Decision:** Firebase Analytics, instrumented for a small, purposeful event set (e.g. onboarding completed, device paired, session started, insight viewed) — not exhaustive interaction tracking. No sensor/health metric values are ever sent as analytics event data; analytics tracks behavior/usage only, kept strictly separate from the health-adjacent data held in Firestore/Storage.

**Reasoning:** Matches instrumentation to actual decision-making need (Principle 1), and enforces a firm privacy line between "how the product is used" and "what the product measured about a player's body," which must never blur together.

**Impact:** New analytics events require a stated reason (what decision they inform) before being added, not added by default alongside every new screen.

---

## 19. Security Architecture

**Problem:** Vikzar holds health-adjacent player data. Access must be strictly scoped (a Player sees their own data; a Coach sees only their own team's players' data) and enforced at the platform level, not just hidden in the UI.

**Options Considered:**
1. Firestore/Storage Security Rules as the primary, server-enforced access control layer, role read from the user's Firestore profile (§9), with Cloud Functions handling privileged operations Rules cannot safely express.
2. Enforce access control only in client code (UI-level restriction).
3. A custom backend authorization service in front of Firebase.

**Pros / Cons:**
- Security Rules as primary enforcement: Rules are evaluated server-side on every read/write regardless of client behavior, which is the only trustworthy enforcement point given the client itself cannot be trusted (a modified or compromised client must not be able to read another player's data); this is exactly what the chosen platform (§8) provides for this purpose.
- Client-only enforcement: trivially bypassed (a user could read another player's data by calling the Firebase SDK directly with different arguments) — unacceptable for health-adjacent data.
- Custom authorization backend in front of Firebase: reintroduces the backend-infrastructure burden §8 specifically avoided, without a gap in Firebase's own Rules system that would justify it.

**Final Decision:** Firestore and Storage Security Rules are the primary, mandatory enforcement layer: a Player may read/write only their own resources; a Coach may read (and, where applicable, write) resources belonging to players on a team they coach, verified against `teams/{teamId}/members` and the requester's own `users/{uid}.workspaces`. Cloud Functions (§12) handle the narrow set of operations Rules cannot themselves safely enforce (e.g. cross-resource invariants). Client-side restriction (hiding UI a user shouldn't act on) is a UX layer on top of this, never a substitute for it.

**Reasoning:** This is not a discretionary architectural preference — it's the minimum required to make "a Coach can only see their own team" actually true rather than merely displayed that way, given health-adjacent data is involved (Principle 2's implication extended to data access, not just physical safety).

**Impact:** Security Rules must be written and reviewed alongside the data model (§10), not bolted on afterward. Compliance-specific requirements (see Open Questions) may impose additional constraints on top of this baseline once identified.

---

## 20. Responsive Layout Strategy

**Problem:** Per ADR-002, Vikzar is one Flutter codebase across phone, tablet, and desktop, and coach workflows must genuinely take advantage of larger displays rather than a stretched phone layout.

**Options Considered:**
1. Breakpoint-based adaptive layout: a single widget tree per screen that rearranges (navigation chrome, content density, column layout) based on available width, using Flutter's layout primitives (`LayoutBuilder`/`MediaQuery`) against defined breakpoints (compact/medium/expanded).
2. Separate screen implementations per platform/form-factor.
3. One fixed layout, scaled uniformly across all screen sizes.

**Pros / Cons:**
- Breakpoint-based adaptive layout: one implementation per feature to maintain (Principle 10), consistent with go_router's shell-based navigation (§4) adapting its own chrome the same way; Material 3's adaptive components (e.g. `NavigationRail`) are designed for exactly this pattern.
- Separate screens per platform: directly duplicates logic and UI per platform, the opposite of ADR-002's single-codebase rationale, and multiplies long-term maintenance cost.
- Fixed layout, uniformly scaled: fails the explicit requirement that coach workflows "naturally scale to tablets and desktop where larger displays provide a better experience" (Spec §6) — scaling a phone layout up doesn't create a better desktop experience, it creates a large phone screen.

**Final Decision:** Breakpoint-based adaptive layout using compact/medium/expanded breakpoints, applied consistently across the app. Coach-facing screens with the most to gain from width (Live Team Monitoring above all) are designed expanded-first, then adapted down; Player-facing screens are designed compact-first, then adapted up. Exact breakpoint values and per-breakpoint behavior are defined in Roadmap Phase 2 (Design Foundations), not here.

**Reasoning:** Directly implements ADR-002 and Spec §6 at the layout-mechanics level, and assigns each major screen a "design-first" direction (coach screens expanded-first, player screens compact-first) so Phase 2 has a concrete starting point rather than designing every screen from an arbitrary default.

**Impact:** No feature should be built with a single fixed-width assumption. This is a constraint on every future screen, not an optional enhancement layered on afterward.

---

## 21. Design System Strategy

**Problem:** Vikzar must feel premium, calm, modern, and trustworthy (Principle 8) while being built efficiently by a small team across seven platforms.

**Options Considered:**
1. Material 3 as the component/interaction foundation, customized via design tokens to Vikzar's own visual identity.
2. A fully custom design system built from scratch (no Material dependency).
3. Material 3 used entirely as-is, with no customization.

**Pros / Cons:**
- Material 3 + custom tokens: inherits adaptive-ready components (e.g. `NavigationRail`, responsive scaffolding patterns) that directly support §20 for free, while full theming control via `ThemeData` and design tokens means the visual result does not need to look "default Material" — the premium/trustworthy feel is achieved through tokens, not by fighting the framework.
- Fully custom design system: maximum visual control, but means building and maintaining adaptive component behavior (navigation chrome switching, accessibility semantics, etc.) that Material 3 already provides — a significant, ongoing cost disproportionate to MVP needs (Principle 7).
- Material 3 as-is: fastest, but risks the product feeling generic rather than deliberately premium/trustworthy, which Principle 8 rules out as sufficient.

**Final Decision:** Material 3 as the structural/component and adaptive-behavior foundation, with Vikzar's own design tokens (color, typography, spacing, elevation) driving `ThemeData` so the visual identity is distinctly Vikzar's, not default Material. Actual token values (palette, type scale) are defined in Roadmap Phase 2 (Design Foundations) — this document establishes the mechanism, not the values.

**Reasoning:** Gets adaptive component behavior "for free" from a mature framework layer (serving §20 and Principle 7) while keeping full control over the brand-critical visual outcome (serving Principle 8).

**Impact:** Phase 2 works within this mechanism (tokens → `ThemeData`), not from a blank slate or a separate custom widget library.

---

## 22. Theme Architecture

**Problem:** Styling must be consistent and centrally controlled so the app is easy to re-theme or extend (e.g. dark mode, future rebranding) without hunting down hardcoded values across features.

**Options Considered:**
1. Centralized token classes (`AppColors`, `AppTypography`, `AppSpacing`, etc.) generating light/dark `ThemeData`, exposed reactively via a Riverpod provider.
2. Hardcoded colors/styles inline within each feature's widgets.
3. Centralized theme, but light mode only at MVP (no dark mode support built into the architecture).

**Pros / Cons:**
- Centralized, token-driven, reactive theme: single source of truth for all visual styling; theme mode (light/dark/system) becomes a state change rather than a rebuild-everything effort; no feature-level widget hardcodes values that would drift from the design system over time.
- Hardcoded inline styling: fast initially, but guarantees visual drift across features over a multi-year lifespan (Principle 10) and makes any future rebrand or dark-mode addition a full-app sweep instead of a token change.
- Centralized but light-mode-only: saves a small amount of upfront work but means dark mode later is a retrofit across every feature rather than a token addition — cheap to avoid now, costly to bolt on later.

**Final Decision:** Centralized token classes generate both light and dark `ThemeData` from the start (even if only one is polished/shipped first — the mechanism supports both), exposed via a Riverpod provider so theme mode is reactive. Feature widgets reference theme tokens exclusively; no hardcoded `Color`/`TextStyle` literals in feature code.

**Reasoning:** The marginal cost of building the token mechanism to support both light and dark from day one is small compared to retrofitting it later across every feature already built — a clear long-term-maintainability win (Principle 10) that doesn't meaningfully expand MVP scope (Principle 7).

**Impact:** Code review for any feature should flag hardcoded styling values as a defect, not a style nitpick — it undermines the mechanism this section establishes.

---

## 23. Future Scalability Strategy

**Problem:** The architecture must not paint the product into a corner (Principle 7) as new hardware, roles, or capabilities are added post-MVP, without building speculative infrastructure now for needs that aren't confirmed.

**Options Considered:**
1. Rely on the extension points already designed into §1–§22 (repository pattern, BLE protocol adapters, feature-first folders, Firestore's role-field model) rather than adding separate, dedicated "scalability infrastructure."
2. Proactively build for anticipated future needs now (e.g. multi-tenant infra, a generalized plugin system, on-device ML, multi-region data residency).
3. Design only for exactly the MVP feature set, with no explicit consideration of what comes after.

**Pros / Cons:**
- Rely on existing extension points: every genuinely likely near-term extension (new hardware device, new role, new feature module, new data source) already has a designated, low-cost extension mechanism from the decisions above — no additional scaffolding is needed to accommodate them.
- Proactively build for anticipated future needs: this is precisely the overengineering Principle 7 warns against — most speculative infrastructure built before a real requirement exists turns out wrong in ways that cost more to unwind than building it later correctly would have.
- No consideration of what comes after: risks accidentally making foreseeable, low-cost-to-anticipate changes (e.g. a third hardware device) expensive by not having an extension point — worse than the chosen option for no MVP-speed benefit, since the extension points below cost nothing extra to have specified.

**Final Decision:** Scalability is achieved through the extension points already built into this architecture, not a separate initiative:
- New hardware device → new `DeviceProtocol` implementation (§7).
- New user role (e.g. clinician) → extends the existing `workspaces` field model (§9, §10) with a third workspace key; Security Rules (§19) extended, not redesigned.
- New feature → new `features/<name>/` module (§2), following the same three-layer structure.
- New/changed data source → new repository implementation behind an unchanged interface (§6).

Explicitly **not** built now: multi-region/multi-tenant infrastructure, a generalized plugin system, on-device ML, or offline conflict resolution beyond §15 — none has a confirmed requirement yet.

**Reasoning:** This directly balances Principle 7's two halves — scalable without overengineering — by showing that scalability was achieved as a side effect of clean architecture decisions already made for other reasons, rather than through dedicated speculative infrastructure.

**Impact:** When a genuinely new scalability requirement is confirmed post-MVP, it should be evaluated against whether an existing extension point already covers it before any new infrastructure is proposed.

---

## 24. Testing Strategy

**Problem:** A multi-platform, stream-heavy, safety-relevant application needs meaningful test coverage, but an MVP-stage team cannot sustain an exhaustive end-to-end suite across seven platforms.

**Options Considered:**
1. A test pyramid: unit tests (domain logic, repository implementations against fakes/emulator) as the largest layer, widget tests for key presentation components, a small number of integration tests for critical flows using the Firebase Local Emulator Suite.
2. Heavy end-to-end/integration testing across all platforms as the primary strategy.
3. Minimal-to-no automated testing at MVP, relying on manual QA.

**Pros / Cons:**
- Test pyramid with emulator suite: unit tests are fast, cheap, and cover the majority of business logic (especially valuable given the repository pattern from §6 makes logic testable without real Firebase/BLE); the Firebase Local Emulator Suite allows realistic Firestore/Auth/Functions testing without touching production data; a small, deliberate set of integration tests covers the flows where correctness matters most.
- Heavy e2e-first strategy: e2e suites are slow, flaky across seven platforms, and expensive to maintain — disproportionate cost for an MVP team (Principle 7), even though the underlying flows (auth, live monitoring) matter.
- Minimal/no automated testing: unacceptable given Live Team Monitoring's safety relevance (Principle 2, 3) — a regression in that flow reaching production is a materially worse outcome here than in a typical consumer app.

**Final Decision:** A test pyramid weighted toward unit tests, using the Firebase Local Emulator Suite (not production Firebase) for Firestore/Auth/Functions-dependent tests. No BLE-fake is needed for MVP, since the Flutter app has no BLE dependency (§7); test data for laptop-originated collections is seeded directly into the emulator, following the payload shapes in [BACKEND_SPECIFICATION.md §21](BACKEND_SPECIFICATION.md#21-upload-contract-for-the-laptop). At minimum, the Live Team Monitoring flow and the Authentication flow each receive at least one integration-level test, given their safety/gatekeeping significance.

**Reasoning:** Matches test investment to both engineering economics (unit tests are cheap and catch the most bugs per unit effort) and product risk (the one feature explicitly called out as safety-critical, Principle 3, gets guaranteed coverage beyond unit level, not left to the general pyramid alone).

**Impact:** Every repository interface (§6) being testable against fakes is a testing-strategy requirement, not just an architecture nicety — it's what makes the unit-test-heavy pyramid actually achievable.

---

## 25. CI/CD Strategy

**Problem:** Changes need automated verification before merge, and multi-platform builds need a repeatable release process, without adding delivery infrastructure disproportionate to team size at MVP.

**Options Considered:**
1. A staged pipeline: static analysis + tests on every change; multi-platform builds on merge/release; internal distribution via Firebase App Distribution; backend changes (Security Rules, Cloud Functions) deployed via a separate, deliberate, gated step rather than automatically on every merge.
2. Fully automatic continuous deployment straight to production on every merge, including backend.
3. No CI/CD automation; manual builds and manual backend deploys.

**Pros / Cons:**
- Staged pipeline with a gated backend-deploy step: catches regressions before merge (analysis + tests), gives repeatable multi-platform builds, and treats backend changes (which affect *all* users' data access immediately, per §19) with appropriately more caution than a client build — a deliberate promotion step rather than blind automation.
- Fully automatic continuous deployment including backend: Security Rules or Cloud Functions changes reaching production automatically on every merge is a meaningfully higher-risk pattern than client app deployment, given rules mistakes can affect data access correctness (§19) immediately and broadly — too aggressive for the risk profile of this specific system.
- No automation: leaves regressions to be caught only manually, unsustainable as the codebase and team grow, and contradicts Principle 10.

**Final Decision:** A staged pipeline: (1) static analysis (`flutter analyze`) and formatting checks, (2) unit/widget test suite, on every change; (3) multi-platform build artifacts produced on merge to the main branch or on release tagging; (4) internal test distribution via Firebase App Distribution (same platform family as §8, avoiding a new vendor); (5) Firestore/Storage Security Rules and Cloud Functions deployment as a separate, explicitly triggered release step — never automatic on every merge, given the risk profile noted above.

**Reasoning:** Matches automation aggressiveness to actual risk: client build/test automation is safe to run continuously; backend deployment affecting live data access is not, and is treated accordingly.

**Impact:** The specific CI provider/tool (e.g. GitHub Actions vs. an alternative) is not decided here — it depends on where the repository will be hosted, which is not yet established (this repository is not yet under version control). See Open Questions.

---

## Architecture Summary

Vikzar is architected as a single Flutter codebase using a pragmatic three-layer (presentation/domain/data) structure organized feature-first, with Riverpod serving as both state management and dependency injection, and go_router providing adaptive, role-based navigation. Firebase — confirmed by product direction — supplies the entire backend: Authentication, Firestore (structured data), Storage (large/raw data), Cloud Functions (minimal; validates and ingests already-computed data, never performs computation), Cloud Messaging (notifications), Crashlytics (error reporting), and Analytics (minimal usage tracking). For MVP, all Bluetooth connectivity, ETL, feature extraction, machine learning inference, and risk prediction are performed by a laptop-based pipeline external to this Flutter codebase (§7, §14; [ADR-030](DECISIONS.md#adr-030-laptop-centric-ble-etl-and-ml-pipeline-for-mvp)) — the Flutter application has no BLE dependency and consumes only already-processed data via Firestore, exactly as specified in [BACKEND_SPECIFICATION.md](BACKEND_SPECIFICATION.md). Firestore's data model deliberately separates small, queryable structured data from large/high-frequency raw sensor data (routed to Storage), and Security Rules — not client-side logic — are the enforced boundary between what a Player and a Coach can each access. Layout is adaptive by breakpoint rather than platform-forked, built on Material 3 with Vikzar-specific design tokens. Testing follows a unit-test-heavy pyramid using the Firebase Local Emulator Suite, with mandatory integration coverage for the two flows with the highest safety/trust stakes (Authentication, Live Team Monitoring). Delivery automation covers client build/test aggressively but treats backend (Rules/Functions) deployment as a separate, deliberately gated step given its immediate, broad effect on data access.

Every decision above was selected by weighing Principle 1 (simplicity), Principle 7 (scalable without overengineering), and Principle 10 (multi-year maintainability) against the concrete, MVP-scoped needs of this specific product — not against a generic "best practice" checklist.

## Risks

- **The laptop pipeline is now a single point of failure for all sensor data capture.** Since MVP concentrates BLE, ETL, feature extraction, ML inference, and risk prediction on one machine per team/session (§7), that laptop's own hardware/OS/BLE-stack reliability is a risk to the *entire* system's data capture for a session, not just one feature. This risk is outside this document's engineering scope (the laptop pipeline is a separate system, specified only at its Firebase-facing contract in BACKEND_SPECIFICATION.md), but is recorded here because it replaces the previously-scoped "desktop BLE support" risk below as the architecture's primary hardware-dependent risk for MVP.
- **BLE support maturity on desktop platforms is no longer an MVP-stage Flutter risk**, since the Flutter app has no BLE dependency at MVP (§7). It re-emerges as a risk only if/when the Future Evolution path (direct phone-to-wearable BLE) is implemented post-MVP.
- **Firestore query/aggregation limitations.** No native joins and limited aggregation may require denormalization or additional Cloud Functions work as features (especially cross-team coach views or history reporting) grow in complexity.
- **Vendor lock-in to Google Cloud/Firebase.** Accepted deliberately for MVP velocity and small-team maintainability (§8); revisiting this later would be a substantial migration, not a small change.
- **Cost scaling with usage.** Firestore/Storage/Functions costs scale with reads/writes/invocations; the live-monitoring, once-per-second nature of live tick ingestion (BACKEND_SPECIFICATION.md §21) means cost monitoring matters earlier than it would for a typical CRUD app.

## Assumptions

- Firebase (Auth, Firestore, Storage, Cloud Functions, Cloud Messaging) is confirmed by explicit product direction; Crashlytics and Firebase Analytics are this document's own recommendation to avoid introducing additional vendors for adjacent, commonly-paired concerns, and should be treated as proposed rather than as firmly settled as the core Firebase services.
- Riverpod and go_router are architectural recommendations made under this phase's mandate to design the architecture — not yet independently discussed/confirmed at the product level. The Flutter-side BLE plugin question from Phase 1 no longer applies to MVP (§7) and is deferred to the Future Evolution path below.
- This repository is not yet under version control; any assumption about a specific git hosting provider (and therefore CI/CD tooling, §25) is deferred rather than guessed.
- No regulatory/compliance regime (e.g. HIPAA, GDPR, or a sport-specific data standard) has been specified; the security architecture (§19) is designed to general least-privilege best practice, not to a named compliance framework.
- The laptop pipeline's internal engineering (its own BLE stack, ETL implementation, ML framework, and Risk Engine) is a separate system's concern, out of scope for this Flutter application architecture document; this document and BACKEND_SPECIFICATION.md together define only its Firebase-facing contract.

## Open Questions

To be resolved before the corresponding roadmap phase begins:

1. **Sign-in methods offered at MVP** — email/password only, or also social providers (Google/Apple) — before Roadmap Phase 4.
2. **Regulatory/compliance requirements** — whether HIPAA, GDPR, or another regime applies to Vikzar's health-adjacent data, which may impose additional constraints on §19 (Security Architecture) and data retention — should be answered by product/legal input before production readiness (Roadmap Phase 13), ideally sooner.
3. **Version control and CI/CD provider** — this repository is not yet under version control; the choice of git host determines available CI/CD tooling for §25.
4. **Firebase Crashlytics and Analytics adoption** — proposed in this document (§17, §18) but not yet explicitly confirmed at the product level the way core Firebase services (§8) were.
5. **Session data raw format** — the exact binary/JSON/CSV shape of raw sensor exports to Storage (§11) is deferred to Roadmap Phase 6, and belongs to the laptop pipeline's own specification.
6. **When (not if) to prioritize the Future Evolution path** (direct phone-to-wearable BLE, below) — no timeline is set; it is a documented capability, not a scheduled roadmap phase, pending a future product decision.

Resolved this phase: the BLE plugin selection and AI model/provider open questions from Phase 1 are resolved at the architecture level — both now belong entirely to the laptop pipeline, outside this document's scope, per [ADR-030](DECISIONS.md#adr-030-laptop-centric-ble-etl-and-ml-pipeline-for-mvp).

## Future Evolution

This section exists so that deferring direct phone-to-wearable BLE out of MVP scope (§7) is a documented, deliberate extension point — not a dead end requiring a future rearchitecture.

**What could change later:** a Player could pair their phone or tablet directly with their own Smart Pod and/or EMG Thigh Band, for unsupervised solo sessions where no laptop is present (e.g. individual practice away from the team).

**Why the backend architecture does not need to change to support this:** [BACKEND_SPECIFICATION.md](BACKEND_SPECIFICATION.md)'s ingestion contract (§17, §21) is expressed in terms of an **ingestion principal** calling a fixed set of Cloud Functions (`startSession`, `ingestLiveTick`, `completeSession`, `submitAlert`, `submitReport`) — it does not, and was not designed to, assume the caller is specifically a laptop. A future Flutter-side ingestion path would call exactly the same Cloud Functions, subject to the same validation and the same Firestore schema (§1), with two additive changes and no redesign:

1. **A new class of ingestion principal** — today's laptop-scoped `{ ingestor: true, orgId, teamIds }` claim (BACKEND_SPECIFICATION.md §3) would be joined by a player-scoped equivalent (e.g. `{ ingestor: true, playerId: <self> }`), authorizing a phone to submit data only for its own signed-in player, never for a team. This is a new, narrower claim shape, not a change to any existing collection or function signature.
2. **On-device ETL/ML, or a lighter-weight equivalent** — the non-negotiable constraint that Firebase never performs ETL/ML (BACKEND_SPECIFICATION.md §0) would still apply; a phone-based path would need its own feature-extraction/risk-scoring logic (potentially a lighter model than the laptop's, given phone compute constraints) before calling `ingestLiveTick`/`completeSession`, mirroring what the laptop does today. This is new Flutter-side + on-device ML engineering, not a backend change.

**What would be reintroduced in the Flutter codebase:** the original Phase 1 design for a Flutter-side `BleService` and per-device `DeviceProtocol` adapters (SmartPodProtocol, EmgBandProtocol) — described in full in the version-controlled history of this document's §7 — remains a valid design for that future work and does not need to be redesigned from scratch; it was deferred, not discarded. The `DeviceRepository`/`SessionRepository` repository interfaces (§6) would gain a second implementation (on-device BLE-backed) alongside the MVP's Firestore-listener-only implementation, selected by which mode a session is running in — an additive change under the repository pattern already in place, not a rearchitecture of it.

**What stays exactly the same:** the entire Firestore schema, Security Rules strategy, Storage hierarchy, Cloud Function responsibilities, alert/report models, and Flutter read contract in [BACKEND_SPECIFICATION.md](BACKEND_SPECIFICATION.md) — a session captured via direct phone BLE and a session captured via the laptop pipeline would be indistinguishable to every screen in §22's read contract, both producing the same `sessions`/`alerts`/`reports` shapes. This is the specific design property (§21's ingestion contract is principal-agnostic, not laptop-specific) that makes this evolution possible without a backend redesign.

## Document Control

| Field | Value |
|---|---|
| Owner | Lead Flutter Architect |
| Status | Foundation — living document |
| Related documents | [SPECIFICATION.md](SPECIFICATION.md), [BACKEND_SPECIFICATION.md](BACKEND_SPECIFICATION.md), [DECISIONS.md](DECISIONS.md), [ROADMAP.md](ROADMAP.md), [PRODUCT_PRINCIPLES.md](PRODUCT_PRINCIPLES.md) |

This document is updated, not rewritten, as later phases resolve open questions or add detail. A change that reverses a decision recorded here must be logged as a new ADR in [DECISIONS.md](DECISIONS.md) referencing the section it supersedes.
