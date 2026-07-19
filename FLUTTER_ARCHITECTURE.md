# Vikzar Flutter Engineering Architecture

**Status:** Frozen — Phase 3 (Flutter Engineering Architecture).

**Owner:** Lead Flutter Architect

This document is the buildable, folder-and-file-level engineering specification for the Vikzar Flutter codebase. It sits below [ARCHITECTURE.md](ARCHITECTURE.md) in altitude: that document decided *what* the architecture is (layered, feature-first, Riverpod, go_router, Firebase, repository pattern — ADR-005 through ADR-029) and *why*. This document defines exactly *how that architecture is organized in code* — the folder tree, the provider conventions, the testing pyramid's concrete test types, the environment strategy, and every other implementation-adjacent decision needed before a single line of Flutter code is written.

**This document contains no Flutter code, no widgets, no Dart, and no project scaffolding.** No `pubspec.yaml`, no `flutter create`, no generated files. It is architecture and project structure only, per this phase's scope.

**Source of truth acknowledged:** this document was written after, and is fully consistent with, [README.md](README.md), [SPECIFICATION.md](SPECIFICATION.md), [ARCHITECTURE.md](ARCHITECTURE.md), [BACKEND_SPECIFICATION.md](BACKEND_SPECIFICATION.md), [DESIGN_SPECIFICATION.md](DESIGN_SPECIFICATION.md), [DECISIONS.md](DECISIONS.md), [ROADMAP.md](ROADMAP.md), and [CHANGELOG.md](CHANGELOG.md). Nothing below contradicts a frozen decision in any of them. Two places where this phase's brief used language that could be read as reintroducing something already frozen are explicitly reconciled, not silently resolved — see the callouts in [§1](#1-overall-flutter-architecture) and [§2](#2-folder-structure).

**Per this phase's instruction, no ADR in [DECISIONS.md](DECISIONS.md) is modified by this document.** New engineering decisions this phase makes are listed as **Proposed ADRs** in [§20](#20-architecture-decisions), pending separate approval before being recorded.

---

## Table of Contents

1. [Overall Flutter Architecture](#1-overall-flutter-architecture)
2. [Folder Structure](#2-folder-structure)
3. [Feature Organization](#3-feature-organization)
4. [Navigation](#4-navigation)
5. [State Management](#5-state-management)
6. [Dependency Injection](#6-dependency-injection)
7. [Repository Pattern](#7-repository-pattern)
8. [Networking](#8-networking)
9. [Offline Behaviour](#9-offline-behaviour)
10. [Design System Implementation](#10-design-system-implementation)
11. [Firebase Integration](#11-firebase-integration)
12. [Error Handling](#12-error-handling)
13. [Logging](#13-logging)
14. [Configuration](#14-configuration)
15. [Testing Strategy](#15-testing-strategy)
16. [Performance](#16-performance)
17. [Accessibility](#17-accessibility)
18. [Desktop, Tablet, Phone](#18-desktop-tablet-phone)
19. [Future Expansion](#19-future-expansion)
20. [Architecture Decisions](#20-architecture-decisions)
- [Assumptions](#assumptions)
- [Open Questions](#open-questions)
- [Document Control](#document-control)

---

## 1. Overall Flutter Architecture

**Frozen inputs (not re-decided here):** pragmatic layered architecture — presentation → domain → data — feature-first, per [DECISIONS.md ADR-005](DECISIONS.md#adr-005-overall-application-architecture--pragmatic-layered-architecture) and [ADR-006](DECISIONS.md#adr-006-folder-structure--feature-first). Riverpod for state and dependency injection ([ADR-007](DECISIONS.md#adr-007-state-management--riverpod), [ADR-009](DECISIONS.md#adr-009-dependency-injection--riverpod-providers-only)). go_router for navigation ([ADR-008](DECISIONS.md#adr-008-navigation-architecture--go_router)). Repository pattern at every external-system boundary ([ADR-010](DECISIONS.md#adr-010-repository-pattern-for-all-external-data-access)). No BLE, no on-device ETL/ML — the Flutter app is a pure Firestore-driven presentation and (narrow, permitted) write client, per [ADR-030](DECISIONS.md#adr-030-laptop-centric-ble-etl-and-ml-pipeline-for-mvp).

### Dependency Direction

```
presentation  ──depends on──▶  domain  ◀──implements──  data
   (screens,                 (models,                  (repository
    widgets,                  repository                impls,
    controllers)              interfaces)                datasources)
```

Domain is the stable center: it depends on nothing else in the app (no Flutter imports, no Firebase imports — plain Dart only). Presentation depends only on domain abstractions (repository interfaces, domain models) via Riverpod providers, never on a concrete data-layer class. Data implements the domain's interfaces and is the only layer permitted to import Firebase or platform SDKs. This is unchanged from [ARCHITECTURE.md §1](ARCHITECTURE.md#1-overall-application-architecture) — this section makes it a checkable, enforced rule (see [§15](#15-testing-strategy), Architecture tests).

### Application Boundaries

The Flutter application's boundary stops at Firestore, Firebase Storage, Firebase Auth, and a narrow set of Cloud Functions ([§8](#8-networking)). Everything upstream of that — Bluetooth, ETL, feature extraction, ML inference, the Risk Engine — is the laptop pipeline, entirely outside this codebase, per [ADR-030](DECISIONS.md#adr-030-laptop-centric-ble-etl-and-ml-pipeline-for-mvp). No folder, service, or dependency described below exists to talk to a wearable device.

### Reconciliation — the "application" layer

This phase's brief illustrates feature organization as `presentation / application / domain / data`. Read literally, a mandatory fourth `application` layer with a use-case class per operation is exactly what [ADR-005](DECISIONS.md#adr-005-overall-application-architecture--pragmatic-layered-architecture) evaluated and rejected as disproportionate boilerplate for this team's size and MVP scope. Per this phase's own instruction — *if an engineering decision conflicts with the frozen specification, the specification wins* — the three-layer model stands. "Application-level" orchestration (coordinating more than one repository for a single user action) is handled by the presentation layer's controllers (Riverpod `AsyncNotifier`s) in the common case. An **optional** `application/` sub-folder may exist *within a specific feature* only when a controller would otherwise become genuinely bloated coordinating multiple repositories — it is a pressure-relief valve for one feature, not a mandatory layer every feature carries. See [§3](#3-feature-organization) for exactly when this applies, and the current MVP feature list (none require it yet).

---

## 2. Folder Structure

### Reconciliation — flat folder names vs. feature-first

This phase's brief lists `repositories`, `models`, `widgets`, `utils`, `extensions` alongside `app`, `core`, `design_system`, `features`, `shared`, `services` as folders to include. Read as a flat, top-level list (`lib/repositories/`, `lib/models/`, containing *every* repository/model in the app), this would be a layer-first structure — exactly what [ADR-006](DECISIONS.md#adr-006-folder-structure--feature-first) rejected in favor of feature-first. The reconciliation: every one of those folder *names* exists in the tree below, but only ever **nested** — inside each feature (feature-local repositories/models), or inside `shared/` and `core/` (genuinely cross-feature ones). There is no `lib/repositories/` or `lib/models/` containing the whole app's data layer. This preserves ADR-006 while satisfying the letter of the request: every named folder type is present, explained, and has an unambiguous location.

### Complete `lib/` Tree

```
lib/
├── app/                          # App bootstrap: root widget, ProviderScope wiring,
│                                  # global observers. Nothing feature-specific lives here.
│   ├── app.dart                  # MaterialApp.router + theme + routerConfig wiring
│   ├── bootstrap.dart            # Firebase.initializeApp, Crashlytics/FCM setup,
│   │                              # environment selection (§14), runApp
│   └── provider_observers.dart   # A single ProviderObserver for debug-build logging
│                                  # (see §13) — not business logic
│
├── core/                         # Cross-feature primitives with zero Flutter/Firebase
│   │                              # dependency (except `extensions/` on Flutter types).
│   │                              # Anything here must be usable by every layer.
│   ├── errors/                   # The Failure hierarchy (ARCHITECTURE.md §16):
│   │                              # NetworkFailure, AuthFailure, BleFailure (retained
│   │                              # for parity even though unused at MVP — see §19),
│   │                              # PermissionFailure, CloudFailure, UnknownFailure
│   ├── result/                   # Result<T, Failure> — the typed success/failure
│   │                              # construct every repository method returns
│   ├── constants/                # App-wide non-visual constants (route names,
│   │                              # collection name strings, config keys)
│   ├── extensions/                # Dart/Flutter extension methods used app-wide
│   │                              # (e.g. DateTime formatting, BuildContext helpers)
│   ├── utils/                    # Pure-Dart utility functions with no other home
│   │                              # (validators, id generation helpers)
│   └── connectivity/              # A single connectivity-state provider (online/
│                                  # offline), consumed by the offline UI pattern (§9)
│
├── design_system/                # DESIGN_SPECIFICATION.md made real (§10 elaborates)
│   ├── tokens/                   # Raw constants: spacing.dart, radius.dart,
│   │                              # elevation.dart, motion.dart, type_scale.dart —
│   │                              # one file per DESIGN_SPECIFICATION.md token table
│   ├── theme/                    # AppColorScheme, AppTextTheme, AppTheme
│   │                              # (light() / dark()), the Alert Crimson
│   │                              # ThemeExtension (§10)
│   └── components/               # One widget class per DESIGN_SPECIFICATION.md §18
│                                  # component: VikzarButton, VikzarCard, ListRow,
│                                  # StatusChip, RiskRing, etc. Features never
│                                  # redefine these — only compose them.
│
├── routing/                      # go_router configuration (§4 elaborates)
│   ├── app_router.dart           # The single GoRouter instance
│   ├── route_guards.dart         # Auth + active-workspace redirect logic
│   └── shells/                   # PlayerShellScaffold, CoachShellScaffold — the
│                                  # adaptive nav chrome wrappers (§18)
│
├── services/                     # Thin wrappers around Firebase/platform SDKs.
│   │                              # No business logic — services expose typed methods,
│   │                              # never raw Firebase types, to the data layer above them.
│   ├── firebase/                 # auth_service.dart, firestore_service.dart,
│   │                              # storage_service.dart, functions_service.dart,
│   │                              # messaging_service.dart
│   ├── logging/                  # AppLogger interface + Debug/Release implementations
│   ├── analytics/                # AnalyticsService (§11)
│   └── local_storage/            # ActiveWorkspaceStore — the one piece of genuinely
│                                  # local, device-only state (ADR-031, §5)
│
├── shared/                       # Code used by two or more features — promoted out
│   │                              # of a single feature only when actually reused,
│   │                              # never speculatively.
│   ├── models/                   # e.g. RiskLevel, WorkspaceType, UserSummary —
│   │                              # domain concepts more than one feature needs
│   ├── repositories/              # e.g. UserRepository — read by Auth, Onboarding,
│   │                              # both Home screens, and Settings
│   └── widgets/                  # Feature-spanning composite widgets not generic
│                                  # enough for design_system/components (rare)
│
├── features/                     # One folder per feature, per §3
│   ├── auth/
│   ├── onboarding/
│   ├── workspace/                # Workspace selection + the switcher sheet
│   ├── player_home/
│   ├── coach_home/
│   ├── sessions/                 # Timeline, History, Session Detail (shared screen)
│   ├── live_monitoring/
│   ├── team/                     # Roster, Team History, Player Detail
│   ├── alerts/
│   ├── devices/                  # Pod Connection (read-only), Device Management
│   ├── notifications/
│   └── profile/                  # Profile, Settings (both workspaces)
│
├── main_development.dart         # Flavor entry points (§14)
├── main_staging.dart
└── main_production.dart
```

### Why Each Top-Level Folder Exists

| Folder | Reason it exists as its own top-level folder |
|---|---|
| `app/` | Isolates one-time bootstrap concerns from everything else — a new contributor should be able to find "how does the app start" in one small folder, not scattered across the tree. |
| `core/` | Holds the handful of things genuinely needed by *every* layer (errors, results, extensions) — kept deliberately small so it doesn't become a dumping ground (per [ARCHITECTURE.md §2](ARCHITECTURE.md#2-folder-structure)'s original intent). |
| `design_system/` | [DESIGN_SPECIFICATION.md](DESIGN_SPECIFICATION.md) is a frozen, standalone specification; giving it a matching standalone folder makes the mapping from spec to code traceable, and guarantees no feature can define its own competing button/card/colour. |
| `routing/` | Navigation is a cross-feature concern (it references every feature's screens) — it cannot live inside any one feature without creating a circular dependency, so it gets its own folder above the feature layer. |
| `services/` | The *only* place Firebase/platform SDK packages are imported outside `features/*/data`. Concentrating this makes "what touches Firebase directly" a one-folder audit, not a codebase-wide search. |
| `shared/` | Explicitly for things promoted *after* a second feature needs them — this folder existing is itself a discipline device: nothing starts here, things arrive here. |
| `features/` | The feature-first core of the architecture ([ADR-006](DECISIONS.md#adr-006-folder-structure--feature-first)) — each feature is independently navigable, testable, and (in principle) removable. |

---

## 3. Feature Organization

Every feature in `features/<name>/` follows the same internal shape:

```
features/<name>/
├── presentation/
│   ├── screens/         # One file per screen (per DESIGN_SPECIFICATION.md §16/§19)
│   ├── widgets/         # Widgets used only within this feature (not promoted to
│   │                      shared/ or design_system/ unless a second feature needs them)
│   └── controllers/     # Riverpod Notifier/AsyncNotifier classes — this feature's state
├── application/         # OPTIONAL — see §1's reconciliation. Absent unless a
│                          # controller genuinely needs to orchestrate 3+ repositories
│                          # for one user action. No MVP feature requires this yet.
├── domain/
│   ├── models/          # Plain Dart models specific to this feature
│   └── repositories/     # Abstract repository interfaces this feature depends on
└── data/
    ├── repositories/     # Concrete implementations of this feature's domain interfaces
    └── datasources/      # Firestore/Storage/Functions-specific access — the only
                           # files in this feature permitted to import Firebase packages
```

### Layer Responsibilities

| Layer | Responsibility | May Depend On | Must Never Depend On |
|---|---|---|---|
| `presentation/screens`, `widgets` | Render UI, delegate all logic to controllers | `presentation/controllers`, `design_system/`, `shared/widgets` | `data/`, Firebase packages directly, other features' `presentation/` |
| `presentation/controllers` | Hold and mutate this screen's state; call repository methods; map `Result`/`Failure` to `AsyncValue` | `domain/repositories` (interfaces), `shared/repositories`, `core/` | `data/` (concrete implementations), Firebase packages directly |
| `application/` (optional) | Orchestrate multiple repositories for one complex action, keeping a controller thin | `domain/repositories` (multiple) | `presentation/`, `data/` |
| `domain/models` | Represent this feature's concepts as plain Dart | Nothing (no Flutter, no Firebase) | Everything else |
| `domain/repositories` | Define the contract a datasource must fulfill | `domain/models`, `core/errors`, `core/result` | Flutter, Firebase |
| `data/repositories` | Implement the domain contract; translate datasource output/exceptions into domain models/`Failure`s | `domain/repositories` (implements), `data/datasources` | `presentation/` |
| `data/datasources` | The only files touching `cloud_firestore`, `firebase_storage`, etc. directly, for this feature | `services/firebase/*` | Everything above `data/` |

### Worked Example — `features/sessions/`

Concretely, not as code: `sessions/domain/repositories/session_repository.dart` declares an abstract `SessionRepository` with methods like "watch a player's session history" and "get one session's detail," returning `Stream<Result<List<Session>, Failure>>` / `Future<Result<Session, Failure>>`. `sessions/data/datasources/session_firestore_datasource.dart` is the only file that calls `FirebaseFirestore.instance.collection('sessions')...`, per [BACKEND_SPECIFICATION.md §22](BACKEND_SPECIFICATION.md#22-flutter-read-contract)'s exact query shapes. `sessions/data/repositories/session_repository_impl.dart` implements the interface using that datasource, catching Firebase exceptions and mapping them to `Failure`s. `sessions/presentation/controllers/session_history_controller.dart` is an `AsyncNotifier` that watches the repository's stream and exposes `AsyncValue<List<Session>>` to the screen. `sessions/presentation/screens/session_history_screen.dart` watches that controller and renders `List Row`/`Session Card` components from `design_system/components` — it never imports `cloud_firestore`, and could not, even by mistake, without an architecture test failing ([§15](#15-testing-strategy)).

---

## 4. Navigation

Builds on [ADR-008](DECISIONS.md#adr-008-navigation-architecture--go_router) and [DESIGN_SPECIFICATION.md §13](DESIGN_SPECIFICATION.md#13-navigation-architecture).

### Router Shape

One `GoRouter` instance (`routing/app_router.dart`), root-level `redirect` callback driven by two Riverpod-held pieces of state: authentication status (`authStateProvider`, a `StreamProvider` over `FirebaseAuth.authStateChanges()` combined with the `users/{uid}` profile) and the active workspace (`activeWorkspaceProvider`, **local device state**, per [ADR-031](DECISIONS.md#adr-031-single-application-with-player-and-coach-workspace-switching) — never a Firestore field).

**Revised at Phase 7** to reflect what is actually built, replacing the aspirational table this section originally held (written before Phase 4's bootstrap or Phase 5/6's identity/onboarding work existed). Onboarding's route shape was itself revised at Phase 6 (a real per-workspace subtree, `/onboarding/{workspace}/**`, not the flat `/onboarding/*` sketched originally — see [DECISIONS.md ADR-046](DECISIONS.md#adr-046-onboarding-is-router-gated-as-a-subtree-with-local-per-workspace-completion-tracking)):

```
GoRouter
├── /splash                              (initial route; resolves auth + workspace, then redirects)
├── /auth                                (Email + 6-digit code — DESIGN_SPECIFICATION.md §19.1, revised Phase 6)
├── /workspace-selection                  (Workspace Selection — onboarding only)
├── /onboarding/{workspace}/level         ┐
├── /onboarding/{workspace}/profile       │ one subtree per workspace, gated as a unit —
├── /onboarding/{workspace}/permissions   │ DECISIONS.md ADR-046
├── /onboarding/player/connect-pod        │
├── /onboarding/coach/team                │
└── /onboarding/{workspace}/complete      ┘ ("Get Started" hands off to Home, Phase 7)
```

```
StatefulShellRoute.indexedStack (Player)   — AppShellScaffold(workspace: player), per DESIGN_SPECIFICATION.md §13/§14
├── /player/home
├── /player/timeline                       (placeholder screen — full build is a future phase)
├── /player/history                        (placeholder screen — full build is a future phase)
└── /player/profile                        (placeholder screen — full build is a future phase)

StatefulShellRoute.indexedStack (Coach)    — AppShellScaffold(workspace: coach), per DESIGN_SPECIFICATION.md §13/§15
├── /coach/home
├── /coach/live                            (placeholder screen — full build is a future phase)
├── /coach/team                            (placeholder screen — full build is a future phase)
├── /coach/alerts                          (placeholder screen — full build is a future phase)
└── /coach/profile                         (placeholder screen — full build is a future phase)

Pushed from either shell (not bottom-nav branches themselves):
├── /{workspace}/settings
├── /{workspace}/notifications
└── /{workspace}/become-a-coach/{step}     (Player-only; a request flow, not a grant — DECISIONS.md ADR-049)
```

A single `AppShellScaffold(workspace:)` (not a separate `PlayerShellScaffold`/`CoachShellScaffold` pair) builds the bottom nav from a per-workspace item list — "one consistent design language across both workspaces... the item sets differ, the visual system does not" (DESIGN_SPECIFICATION.md §13) is best expressed as one parameterized widget, not two near-duplicate ones. `StatefulShellRoute.indexedStack` (not a plain `ShellRoute`) preserves each tab's scroll position/state when switching bottom-nav destinations, go_router's standard mechanism for this.

Timeline/History/Live Monitoring/Team/Alerts are placeholder screens at Phase 7 — wired into the shell and genuinely navigable (the point of building the shell at all), but not built out to DESIGN_SPECIFICATION.md §19.2/§19.3's full wireframe depth; that is explicitly future-phase work (Roadmap Phases 6–11), out of Phase 7's "Player Home, Coach Home, Application Shell" scope.

### Redirect Logic (`route_guards.dart`)

| Condition | Redirect To |
|---|---|
| Not authenticated, not already on `/auth` | `/auth` |
| Authenticated, `workspaces` map is empty, not already in `/onboarding/*` | `/onboarding/workspace` (defensive — should not occur post-onboarding in normal use) |
| Authenticated, has at least one workspace, currently on `/splash`, `/auth`, or any `/onboarding/*` route | The active workspace's home (`/player/home` or `/coach/home`) |
| Authenticated, on a route belonging to a workspace the account does not hold (e.g. deep-linked to `/coach/*` with no Coach workspace) | The account's one held workspace's home |

### Nested Navigation

Each `ShellRoute` owns its workspace's bottom nav / rail / sidebar chrome (the `PlayerShellScaffold` / `CoachShellScaffold` widgets in `routing/shells/`, which are the adaptive-chrome wrapper described in [§18](#18-desktop-tablet-phone)). Sub-tabs within a screen (Sessions/Analysis, Roster/History) are **not** separate routes — they are local widget state (a segment control selection) within one route's screen, consistent with [DESIGN_SPECIFICATION.md §18](DESIGN_SPECIFICATION.md#18-component-library)'s Segment Control component, keeping the route tree flat and matching the "no unnecessary screens" principle.

### Authentication Flow

`/splash` is not a visual dead end — it is the route where the app waits for `authStateProvider` and `activeWorkspaceProvider`'s local-storage read to resolve, then the `redirect` callback above fires immediately. This matches [DESIGN_SPECIFICATION.md §19.1](DESIGN_SPECIFICATION.md#191-onboarding-flow)'s Splash description exactly (three destinations: last-used workspace's Home, `defaultWorkspace`'s Home, or `/auth`).

### Workspace Switching

Switching is **not** a `go()` call to a new route in the everyday sense of "navigating somewhere." It is: (1) the Workspace Switcher sheet updates `activeWorkspaceProvider` (local state, instant, no Firestore write, per ADR-031); (2) the router's `refreshListenable` (a `GoRouterRefreshStream` or Riverpod-to-Listenable bridge watching `activeWorkspaceProvider`) fires; (3) the `redirect` callback re-evaluates and, since the current route belongs to the now-inactive workspace, redirects to the new active workspace's home route. The 200ms cross-fade specified in [DESIGN_SPECIFICATION.md §12](DESIGN_SPECIFICATION.md#12-motion-principles) is implemented as the page transition for exactly this redirect (a custom `pageBuilder` using a fade transition, not go_router's default platform transition, for this one redirect case).

### Future Deep Linking

Every route above is already a real URL path, not an opaque route name — this is a direct consequence of go_router's design and was part of [ADR-008](DECISIONS.md#adr-008-navigation-architecture--go_router)'s original Web-compatibility rationale. `/coach/team/player/:playerId` and `/player/history/session/:sessionId` are already deep-linkable in principle (e.g., from a push notification's payload, per [BACKEND_SPECIFICATION.md §18](BACKEND_SPECIFICATION.md#18-notification-triggers)) — wiring an incoming FCM notification's data payload to a `context.go(path)` call is additive, not a routing rearchitecture, when notification tap-through is implemented.

---

## 5. State Management

Elaborates [ADR-007](DECISIONS.md#adr-007-state-management--riverpod). All providers are defined with modern Riverpod (`Notifier`/`AsyncNotifier`, not the legacy `StateNotifier`), per code-review convention to be documented alongside the eventual `analysis_options.yaml`.

### Provider Hierarchy

| Scope | Lifetime | Examples | Disposal |
|---|---|---|---|
| **Global** | App lifetime | `authStateProvider`, `activeWorkspaceProvider`, `themeModeProvider`, `connectivityProvider` | Never disposed — kept alive for the whole session |
| **Feature-scoped** | Screen/controller lifetime | `sessionHistoryControllerProvider`, `liveMonitoringControllerProvider` | `.autoDispose` — torn down when no widget is watching, critical for [§16](#16-performance)'s memory rule on live listeners |
| **Family (parameterized)** | Per-argument lifetime | `sessionDetailProvider(sessionId)`, `playerDetailProvider(playerId)` | `.autoDispose.family` — a new instance per ID, disposed when that detail screen is left |

### When to Use Each Provider Type

| Type | Use When | Vikzar Example |
|---|---|---|
| `StreamProvider` | Exposing a Firestore realtime listener directly, no further client-side mutation needed from the UI | Live Team Monitoring's `teams/{teamId}/liveMonitoring` collection ([BACKEND_SPECIFICATION.md §1.4](BACKEND_SPECIFICATION.md#1-complete-firestore-schema)); Notifications badge count |
| `AsyncNotifier` | A controller managing async, *mutable* state — the data comes from an async source **and** the UI can trigger actions that change it | Alert Inbox (loads alerts, and the user can acknowledge one — a state-changing action); Session Detail (loads, and may trigger a "view full report" fetch) |
| `Notifier` | Synchronous, simple local UI state not backed by an async source | Onboarding form field selections before submission; which segment-control tab is active |
| `FutureProvider` | A one-shot async read with no further mutation from the UI | A single computed/derived value fetched once per screen load with no user-triggered refresh path |
| `StateProvider` | The most trivial ephemeral UI state only, where a full `Notifier` would be pure ceremony | A search query string (see [DESIGN_SPECIFICATION.md §18](DESIGN_SPECIFICATION.md#18-component-library)'s Search component, not on any MVP screen today) — used sparingly and only for genuinely trivial cases; default to `Notifier` otherwise |

This app is dominated by `StreamProvider` and `AsyncNotifier` — a direct reflection of [ADR-007](DECISIONS.md#adr-007-state-management--riverpod)'s original reasoning that Riverpod was chosen *because* the app is stream-heavy (BLE-adjacent live data via Firestore, not BLE itself, per ADR-030).

### How State Flows

```
Widget  ──ref.watch──▶  Controller (AsyncNotifier/StreamProvider)
                              │
                         ref.watch (domain interface)
                              ▼
                        Repository Provider
                     (Provider<XRepository>, bound
                      to the concrete data/ impl)
                              │
                       calls, returns Stream/Future<Result<T, Failure>>
                              ▼
                          Datasource
                    (the only place touching Firebase)
```

A widget never watches a repository or datasource directly — always a controller. A controller never imports a concrete repository implementation — always the domain interface, resolved by Riverpod's provider binding (see [§6](#6-dependency-injection)).

---

## 6. Dependency Injection

Elaborates [ADR-009](DECISIONS.md#adr-009-dependency-injection--riverpod-providers-only). Riverpod providers **are** the DI mechanism — no `get_it`, no service locator, no second framework, per this phase's explicit constraint.

### Dependency Flow

```
services/firebase/*        (wrapped Firebase SDK singletons, exposed as Providers)
        │
        ▼
features/*/data/datasources   (Provider, depends on a services/ provider)
        │
        ▼
features/*/data/repositories  (Provider<XRepositoryImpl>, depends on a datasource provider)
        │
        ▼
features/*/domain/repositories (the interface — bound via
                                  Provider<XRepository> = xRepositoryImplProvider)
        │
        ▼
features/*/presentation/controllers  (ref.watch(xRepositoryProvider))
        │
        ▼
features/*/presentation/screens, widgets
```

The binding step — `final xRepositoryProvider = Provider<XRepository>((ref) => XRepositoryImpl(ref.watch(xDatasourceProvider)))` — is where dependency inversion actually happens: a controller depends on `XRepository` (the interface, from `domain/`), and Riverpod resolves which concrete implementation satisfies it. Swapping an implementation (e.g., for a test) means overriding one provider, not touching the controller.

### No Global Singletons, With One Documented Exception

Per this phase's instruction ("no global singletons except where genuinely required"): the one exception is the underlying Firebase SDK instances themselves (`FirebaseAuth.instance`, `FirebaseFirestore.instance`, etc.) — these are inherently singleton by the SDK's own design and cannot be meaningfully "de-singletoned." They are wrapped **exactly once**, in `services/firebase/*`, exposed as Riverpod `Provider`s — no other file in the codebase calls `.instance` directly. This makes the singleton-ness invisible above the `services/` layer and fully overridable in tests.

### Testing Payoff

Every provider in the chain above can be overridden via `ProviderScope(overrides: [...])` in a widget test or `ProviderContainer(overrides: [...])` in a unit test — this is the concrete benefit of using Riverpod as the DI layer rather than constructing dependencies by hand, and is what makes [§15](#15-testing-strategy)'s unit-test-heavy pyramid achievable.

---

## 7. Repository Pattern

Elaborates [ADR-010](DECISIONS.md#adr-010-repository-pattern-for-all-external-data-access) into the enforced rule this phase asks for.

```
UI (widget)
   │  watches
   ▼
Controller (presentation/controllers — Riverpod Notifier/AsyncNotifier)
   │  calls a method on
   ▼
Repository (domain/repositories interface, resolved to data/repositories impl)
   │  calls a method on
   ▼
Datasource (data/datasources — the only Firebase-import boundary)
   │  calls
   ▼
Firebase (Firestore / Storage / Auth / Functions, via services/firebase/*)
```

**No widget, and no controller, ever imports `cloud_firestore`, `firebase_storage`, `firebase_auth`, or `cloud_functions` directly.** This is not a style preference left to code review alone — it is mechanically enforced by an architecture test ([§15](#15-testing-strategy)) that fails the build if any file outside `features/*/data/datasources/` or `services/firebase/` imports a Firebase package.

Each repository interface corresponds to one of [BACKEND_SPECIFICATION.md §1](BACKEND_SPECIFICATION.md#1-complete-firestore-schema)'s collections or a closely related group: `AuthRepository`, `UserRepository` (shared, per [§2](#2-folder-structure)), `SessionRepository`, `DeviceRepository`, `TeamRepository`, `AlertRepository`, `ReportRepository`, `NotificationRepository`, `LiveMonitoringRepository`. Method signatures on each interface mirror [BACKEND_SPECIFICATION.md §22](BACKEND_SPECIFICATION.md#22-flutter-read-contract)'s exact per-screen query shapes — the read contract document is the source of truth for what each repository method must return.

---

## 8. Networking

The Flutter app's network surface is entirely Firebase, per [ADR-012](DECISIONS.md#adr-012-cloud-architecture--firebase-as-the-complete-backend-platform); there is no general-purpose HTTP client at MVP.

| Concern | Where | Notes |
|---|---|---|
| **Firestore** | `services/firebase/firestore_service.dart` (thin — exposes the `FirebaseFirestore` instance + typed collection-reference helpers) + per-feature `data/datasources` | The vast majority of the app's data access. Query shapes fixed by [BACKEND_SPECIFICATION.md §22](BACKEND_SPECIFICATION.md#22-flutter-read-contract) and indexes by [§14](BACKEND_SPECIFICATION.md#14-firestore-indexes). |
| **Firebase Storage** | `services/firebase/storage_service.dart` | Used by exactly one MVP path: avatar upload/read, per [BACKEND_SPECIFICATION.md §16](BACKEND_SPECIFICATION.md#16-cloud-storage-folder-hierarchy)'s client-writable scope. Everything else in Storage is Cloud-Function-written and Flutter-read-only. |
| **Firebase Authentication** | `services/firebase/auth_service.dart` + `features/auth/data` | Sign-in/sign-up, session state exposed via `authStateProvider`. |
| **Cloud Functions (Callable)** | `services/firebase/functions_service.dart` | Flutter calls exactly two Callable Functions at MVP: the join-team and create-team functions that write `users/{uid}.workspaces`/`defaultWorkspace` (per the [DECISIONS.md ADR-031](DECISIONS.md#adr-031-single-application-with-player-and-coach-workspace-switching) data-model resolution — these are the only client-initiated, Cloud-Function-mediated writes at MVP). Flutter never calls the laptop's ingestion functions ([BACKEND_SPECIFICATION.md §17](BACKEND_SPECIFICATION.md#17-cloud-function-responsibilities)) — those are laptop-only. |
| **Firebase Cloud Messaging** | `services/firebase/messaging_service.dart` | Token registration (writes to `users/{uid}.fcmTokens`) and foreground message handling, wired at `app/bootstrap.dart`. |
| **Future REST endpoints** | Would live in a new `services/network/` folder (e.g. a `Dio`-based client), sitting *alongside* `services/firebase/` at the same layer | No REST endpoint exists or is planned at MVP. The repository pattern already insulates this: a repository doesn't know or care whether its datasource is Firestore or REST, so adding one is additive to `services/` and one feature's `data/datasources`, never a rearchitecture. |

### Timeout Strategy

| Call Type | Timeout | Reasoning |
|---|---|---|
| Firestore `get()` (one-shot read) | 10s | Generous enough for poor connectivity, short enough that a hung UI state is never mistaken for "working" |
| Firestore listener (`snapshots()`) | No timeout (long-lived) | Listeners are expected to persist; connectivity state is surfaced separately via [§9](#9-offline-behaviour)'s indicator, not a timeout |
| Callable Cloud Function | 30s | Accounts for Cloud Functions cold-start latency, which one-shot Firestore reads don't incur |
| Storage upload (avatar) | Adaptive, scaled to file size, with a hard ceiling of 60s | Avatars are small but mobile upload conditions vary; a hard ceiling prevents an indefinitely stuck upload state |

### Error Handling and Retry

Datasources catch raw `FirebaseException`/`FirebaseAuthException`/platform exceptions and map them to the [ARCHITECTURE.md §16](ARCHITECTURE.md#16-error-handling) `Failure` hierarchy — no raw Firebase exception type ever crosses the `data/repositories` boundary. Transient failures (`unavailable`, network-adjacent codes) are retried with exponential backoff (three attempts, starting at 500ms) **at the datasource level**, invisible to the controller unless all retries are exhausted. Non-transient failures (`permission-denied`, `not-found`) are **never retried** — they fail immediately and surface a specific, calm `Failure` to the controller, per [§12](#12-error-handling).

---

## 9. Offline Behaviour

Elaborates [ARCHITECTURE.md §15](ARCHITECTURE.md#15-offline-strategy) (revised) and [BACKEND_SPECIFICATION.md §19](BACKEND_SPECIFICATION.md#19-offline-synchronization-strategy) at the Flutter code level. **Reiterating the hard boundary this phase's brief names explicitly: the laptop remains the processing engine; Flutter only ever visualizes cloud data. No offline behavior described here involves the app computing anything from stale local data — it only involves reading/writing already-computed data while disconnected.**

| Concern | Implementation |
|---|---|
| **Local caching** | Firestore's built-in offline persistence, enabled explicitly at `app/bootstrap.dart` via `FirebaseFirestore.instance.settings` (persistence is on by default on mobile but must be explicitly enabled for desktop targets — a genuine platform difference worth calling out here). No custom cache layer. |
| **Synchronization** | Automatic, SDK-managed. No feature-level code queues or reconciles writes — this would duplicate what Firestore already does, exactly the overbuilding [ADR-019](DECISIONS.md#adr-019-offline-strategy--firestore-built-in-persistence--local-session-buffering) rejected. |
| **Retry** | SDK-level automatic retry for queued writes (the two Cloud-Function-mediated calls, [§8](#8-networking)); no custom retry queue in the app. |
| **Offline viewing** | `StreamProvider`s continue emitting cached snapshots while offline (`QuerySnapshot.metadata.isFromCache`). `connectivity/` in `core/` exposes a simple online/offline signal; a small, non-blocking "showing saved data" indicator is a **recommended addition to `design_system/components`**, flagged here as new ground this document doesn't design in detail (it is a design-system, not an engineering-architecture, decision) — see [Open Questions](#open-questions). |
| **Workspace switching offline** | Fully functional offline, since the active workspace is local device state (`ActiveWorkspaceStore`, [§6](#6-dependency-injection)), never a Firestore read — only the *data within* the newly active workspace may be stale/cached until reconnection. |

---

## 10. Design System Implementation

How [DESIGN_SPECIFICATION.md](DESIGN_SPECIFICATION.md) becomes Flutter code, folder by folder within `design_system/` ([§2](#2-folder-structure)).

| DESIGN_SPECIFICATION.md Section | `design_system/` Implementation |
|---|---|
| §5 Typography System | `tokens/type_scale.dart` (the 8-step scale as constants) → `theme/text_theme.dart` maps it onto Flutter's `TextTheme` (Display→`displayLarge`, Headline→`headlineMedium`, etc., per Material 3's role names) |
| §6 Spacing System | `tokens/spacing.dart` — a `SpacingTokens` class of `double` constants (`space4` through `space96`), imported wherever a `SizedBox`/`Padding` value is needed. No feature file ever hardcodes a spacing number. |
| §7 Grid System | Implemented in `core/utils/breakpoint.dart` ([§18](#18-desktop-tablet-phone)), not `design_system/` itself — grid is a layout concern consumed by the adaptive shell wrappers |
| §8 Colour Usage Rules | `theme/color_scheme.dart` maps the five brand colours + approved Alert Crimson exception onto Flutter's `ColorScheme` where a role exists (primary = Mineral Blue, error = Oxide Rose) and a **custom `ThemeExtension<VikzarColors>`** for roles Material's `ColorScheme` has no slot for (Alert Crimson, the Graphite Ink/Plum Black elevation-overlay pair) — a `ThemeExtension` is the correct Flutter mechanism for exactly this "we need more roles than Material ships" situation, not a second, competing colour system |
| §9 Elevation Rules | `tokens/elevation.dart` — since Vikzar's dark-theme elevation model (white-overlay percentages) doesn't match Material 3's default surface-tint elevation, this is implemented as a custom `ThemeExtension<VikzarElevation>` exposing the 5 levels' overlay/shadow values directly, applied manually by `design_system/components` widgets rather than relying on Material's built-in `elevation` property producing the wrong visual result |
| §10 Corner Radius Rules | `tokens/radius.dart` — a `RadiusTokens` class (`BorderRadius` constants: `xs`, `sm`, `md`, `lg`, `pill`) |
| §11 Iconography Rules | The Material Symbols Outlined package, plus a `VikzarIcons` class for the four bespoke glyphs ([DESIGN_SPECIFICATION.md §11](DESIGN_SPECIFICATION.md#11-iconography-rules)) — loaded as an icon font or SVG set depending on what's ultimately commissioned (open question in that document, unresolved by this one) |
| §12 Motion Principles | `tokens/motion.dart` — `Duration`/`Curve` constants (`standardDuration = 200ms`, `criticalEntranceDuration = 150ms`, etc.); every `AnimatedSwitcher`/`AnimatedCrossFade`/custom transition in the app references these, never an inline `Duration(milliseconds: ...)` literal |
| §18 Component Library | Each named component (Buttons, Cards, List Row, Status Chips, Charts, Dialogs, Bottom Sheets, Snackbars, Loading Indicators, Empty/Error/Permission Screens) becomes exactly one widget class in `design_system/components/` |

`AppTheme.light()` and `AppTheme.dark()` in `theme/app_theme.dart` compose all of the above into two `ThemeData` objects, `useMaterial3: true` (per [ADR-025](DECISIONS.md#adr-025-design-system-strategy--material-3-with-custom-tokens)), attached to `MaterialApp.router` in `app/app.dart`, switched by `themeModeProvider`.

---

## 11. Firebase Integration

| Service | Belongs In | Used By |
|---|---|---|
| Authentication | `services/firebase/auth_service.dart`, `features/auth/` | Everything, indirectly, via `authStateProvider` |
| Firestore | `services/firebase/firestore_service.dart`, every feature's `data/datasources` | Nearly every feature — the primary data source |
| Storage | `services/firebase/storage_service.dart` | `features/profile/` (avatar) only, at MVP |
| Cloud Functions | `services/firebase/functions_service.dart` | `features/workspace/` (join/create team) only, at MVP |
| Cloud Messaging | `services/firebase/messaging_service.dart`, wired at `app/bootstrap.dart` | `features/notifications/` (token registration), app-wide (foreground handling) |
| Crashlytics | `services/logging/`, wired at `app/bootstrap.dart` | App-wide, via `AppLogger`'s release implementation ([§13](#13-logging)) |
| Analytics | `services/analytics/` | Called explicitly from specific controller actions only (per [ARCHITECTURE.md §18](ARCHITECTURE.md#18-analytics-strategy)'s minimal event set) — never from `build()` methods or generically from every screen |

No implementation detail beyond folder placement is specified here, per this phase's "do not implement" scope — exact method signatures are a Phase 4+ (feature implementation) concern.

---

## 12. Error Handling

Elaborates [ARCHITECTURE.md §16](ARCHITECTURE.md#16-error-handling) into a concrete strategy.

The `Failure` hierarchy (`core/errors/`) is the single currency of error information above the data layer:

| Failure Type | Raised When | Controller-Level Handling |
|---|---|---|
| `NetworkFailure` | Connectivity lost mid-operation | Calm message: "You're offline. Showing your last saved data." — paired with [§9](#9-offline-behaviour)'s offline indicator, never a blocking dialog |
| `AuthFailure` | Invalid credentials, expired session | Specific inline message on the Auth screen, or (if session expiry mid-use) a silent redirect to `/auth` via the router's redirect logic ([§4](#4-navigation)) |
| `PermissionFailure` | A Firestore/Storage Security Rule denies a read/write the UI attempted | Calm explanation + (where relevant) a link into device Settings — never a raw "permission-denied" string |
| `CloudFailure` | A Callable Cloud Function call fails (e.g., invalid team invite code) | Specific inline form error at the point of the action, not a generic app-wide dialog |
| `UnknownFailure` | Anything not classified above | Generic calm message ("Something went wrong. Please try again.") **and** automatic Crashlytics reporting with context — never a raw stack trace shown to the user |

A `FailureMessageMapper` (in `core/errors/`) is the single place `Failure → user-facing string` translation happens, so message tone is centrally controlled and consistent with [DESIGN_SPECIFICATION.md](DESIGN_SPECIFICATION.md)'s calm, trustworthy voice — no controller writes its own ad hoc error string.

**Top-level boundary:** `ErrorWidget.builder` is overridden at `app/bootstrap.dart` to render a calm, on-brand full-screen error state (using `design_system/components`' Error Screen) instead of Flutter's default red error screen, in every build mode — an unhandled widget-build exception should never show a user a stack trace, even in a bug.

---

## 13. Logging

Elaborates [ADR-021](DECISIONS.md#adr-021-logging-strategy--applogger-abstraction-with-firebase-crashlytics).

| Build | Implementation | Behavior |
|---|---|---|
| Debug/Profile | `DebugLogger` (`services/logging/`) | Verbose console output; a debug-only `ProviderObserver` (`app/provider_observers.dart`) logs every provider state transition for local debugging |
| Release | `ReleaseLogger` (`services/logging/`) | No console output (avoids leaking data via device logs); routes through Crashlytics' non-fatal `recordError` for anything logged at warning level or above |
| Crash reporting | Crashlytics, wired at `app/bootstrap.dart` | Catches both `FlutterError.onError` (framework errors) and `PlatformDispatcher.instance.onError` (uncaught async errors) — both wired before `runApp()` |
| Developer diagnostics | **Recommended, optional, not required for MVP** — a debug-flavor-only in-app panel showing recent logs, current provider states, active workspace, and connectivity, reachable only in the `development` flavor ([§14](#14-configuration)) | Flagged explicitly as optional per this document's own instruction to flag rather than silently add scope |

Both implementations satisfy the single `AppLogger` interface from `services/logging/app_logger.dart` — feature code calls `ref.watch(loggerProvider)` and never knows which implementation is active, per [§6](#6-dependency-injection)'s DI pattern. No sensitive/health data is ever passed to a log call, per [ARCHITECTURE.md §17](ARCHITECTURE.md#17-logging-strategy)'s constraint — enforced by code-review discipline (no automated check for this is proposed, since it can't be mechanically detected the way an import-boundary can).

---

## 14. Configuration

### Environment Strategy

Three Flutter flavors, one entry point each:

| Flavor | Entry Point | Firebase Project | Purpose |
|---|---|---|---|
| Development | `main_development.dart` | A dedicated dev Firebase project, entirely separate data from staging/production | Local development, connected to the Firebase Local Emulator Suite where possible ([ARCHITECTURE.md §24](ARCHITECTURE.md#24-testing-strategy)) |
| Staging | `main_staging.dart` | A dedicated staging Firebase project | Pre-release verification against real (non-emulated) Firebase infrastructure, with data that must never be treated as real player data |
| Production | `main_production.dart` | The production Firebase project | Real users, real player-safety data |

Each entry point calls a shared `bootstrap(Environment env)` function (`app/bootstrap.dart`) that selects the environment-appropriate `FirebaseOptions` (via `firebase_options_development.dart` / `_staging.dart` / `_production.dart`, generated per environment by the FlutterFire CLI when Phase 4 scaffolding begins — not generated by this document). This directly supports [BACKEND_SPECIFICATION.md](BACKEND_SPECIFICATION.md)'s organization/ingestion-principal model, which assumes environment-isolated Firebase projects.

### Secrets and API Keys

Firebase's client-side configuration (the values in `firebase_options.dart`) is not a traditional secret — it is safe to ship in a client binary; access control is enforced by Firestore/Storage Security Rules ([BACKEND_SPECIFICATION.md §15](BACKEND_SPECIFICATION.md#15-security-rules-strategy)), not by hiding the config. No other secret is identified as needed by the Flutter app at MVP — the laptop's ingestion-principal credential ([BACKEND_SPECIFICATION.md §3](BACKEND_SPECIFICATION.md#3-authentication-mapping)) is explicitly not a Flutter concern. If a genuine client-side secret is ever needed, it is passed via `--dart-define` at build time, never hardcoded or committed — this is a standing rule, not a currently-active need.

This section is a direct input to the still-open CI/CD provider question ([ADR-029](DECISIONS.md#adr-029-cicd-strategy--staged-pipeline-with-gated-backend-deployment)) — whichever CI provider is chosen must be able to build all three flavors and inject their respective `firebase_options` files, a requirement to confirm when that decision is made.

---

## 15. Testing Strategy

Elaborates [ADR-028](DECISIONS.md#adr-028-testing-strategy--unit-heavy-pyramid-with-mandatory-safety-flow-coverage) with the additional test categories this phase asks for.

| Test Type | Scope | Tooling | Notes |
|---|---|---|---|
| **Unit** | `domain/`, `data/repositories` logic, `Failure` mapping, `FailureMessageMapper` | `package:test`, fakes for repository interfaces | The largest layer of the pyramid, per ADR-028 — cheap, fast, and enabled by the repository pattern's testability |
| **Widget** | Individual `design_system/components` and feature widgets in isolation | `flutter_test`, `WidgetTester.pump` | Verifies structure, interaction, and state-driven rendering, with `ProviderScope` overrides ([§6](#6-dependency-injection)) supplying fake controllers |
| **Golden** | `design_system/components` only, across light/dark theme and at each of the three breakpoints ([§7](#7-repository-pattern)/[§18](#18-desktop-tablet-phone)) | `golden_toolkit` (or Flutter's built-in `matchesGoldenFile`) | Protects [DESIGN_SPECIFICATION.md](DESIGN_SPECIFICATION.md)'s frozen visual language from silent drift — a component's pixels changing unintentionally fails CI, not just a human review |
| **Integration** | Authentication and Live Team Monitoring flows (mandatory, per ADR-028) | `integration_test` package, against the Firebase Local Emulator Suite | Full app, real (emulated) Firebase, no mocks — the two flows named because of their safety/gatekeeping significance |
| **Architecture tests** | Enforces the dependency-direction rule from [§1](#1-overall-flutter-architecture) and [§7](#7-repository-pattern) mechanically | A custom Dart script (or `import_lint`/`custom_lint` rule) run in CI that fails if: any file outside `features/*/data/datasources` or `services/firebase/` imports a Firebase package; any `domain/` file imports `package:flutter/*` or a Firebase package; any `presentation/` file imports a concrete `data/repositories` class instead of the `domain/repositories` interface | This is new ground beyond ADR-028 — it turns "no widget should ever access Firebase directly" from a code-review convention into a build-breaking check |
| **Repository tests** | Each `data/repositories` implementation, against real (emulated) Firestore semantics | Firebase Local Emulator Suite | Verifies actual query/write behavior, not mocked behavior that could silently diverge from real Firestore |
| **Navigation tests** | `route_guards.dart`'s redirect logic, for every auth/workspace state combination in [§4](#4-navigation)'s table | go_router's testing utilities (`GoRouter` + a test `Navigator` observer) | Verifies each row of the redirect table actually redirects correctly, including the workspace-switch redirect |

---

## 16. Performance

| Concern | Strategy |
|---|---|
| **Lazy loading** | go_router builds screens lazily by default (no eager import of every feature at app root); no additional lazy-loading mechanism needed for a mobile/desktop app of this size |
| **Image strategy** | Avatars are the *only* client-facing image at MVP, per [DESIGN_SPECIFICATION.md §4](DESIGN_SPECIFICATION.md#4-visual-language) ("no lifestyle photography in-product"). Cached network image loading (memory + disk cache) for Storage-hosted avatar URLs, requested at a size appropriate to its display context (list-row-size vs. profile-header-size), never full resolution for a thumbnail |
| **List performance** | `ListView.builder` (never `ListView(children: [...])`) for every potentially unbounded list: Session History, Timeline, Roster, Alert Inbox. **Recommended addition, flagged, not yet confirmed:** cursor-based pagination for Session History and Alert Inbox once a real account accumulates enough history that a single unbounded query becomes a real cost — [BACKEND_SPECIFICATION.md §22](BACKEND_SPECIFICATION.md#22-flutter-read-contract) doesn't specify a page size, so this needs confirming before Phase 4 implements those screens (see [Open Questions](#open-questions)) |
| **Memory** | Live-data `StreamProvider`s (Live Team Monitoring above all) use `.autoDispose`, so Firestore listeners are torn down the moment a coach navigates away — a long coaching session should never accumulate orphaned listeners |
| **Animations** | Strictly the durations/curves in `design_system/tokens/motion.dart` ([§10](#10-design-system-implementation)) — no custom physics-based or bespoke animation beyond [DESIGN_SPECIFICATION.md §12](DESIGN_SPECIFICATION.md#12-motion-principles)'s specification; `MediaQuery.disableAnimationsOf(context)` (the reduce-motion OS signal) is respected by every animated transition, per that document's §20 accessibility requirement |

---

## 17. Accessibility

Code-level support for [DESIGN_SPECIFICATION.md §20](DESIGN_SPECIFICATION.md#20-accessibility), which is the source of the actual requirements — this section is *how the architecture makes them achievable*, not a restatement of *what* they are.

| Requirement | Architectural Support |
|---|---|
| Dynamic text (up to 130%) | No fixed-height containers wrap text anywhere in `design_system/components`; every text-containing component is tested (widget tests, [§15](#15-testing-strategy)) at 130% `TextScaler` for truncation/overflow |
| Screen readers | Every `design_system/components` widget ships explicit `Semantics` labels rather than relying on default widget semantics — necessary because several components (the Risk Ring/Gauge, Status Chips) are custom-painted or composite and would otherwise expose nothing meaningful to VoiceOver/TalkBack |
| Contrast | Enforced structurally: since `theme/color_scheme.dart` is the *only* place colour values exist ([§10](#10-design-system-implementation)), no feature file can introduce an unverified colour combination — contrast is a property of the token system, verified once in [DESIGN_SPECIFICATION.md §20](DESIGN_SPECIFICATION.md#20-accessibility), not per-screen |
| Keyboard navigation (desktop) | `FocusTraversalGroup` ordering matches visual/reading order in every screen; every interactive `design_system/components` widget implements the themed focus-ring decoration specified in that document's §20, via `FocusNode` + `Focus` widget composition |
| Desktop support | No separate accessibility implementation for desktop — the same `Semantics` and focus infrastructure serves screen readers, switch control, and keyboard navigation across every platform, per [§18](#18-desktop-tablet-phone)'s no-fork principle |

---

## 18. Desktop, Tablet, Phone

Elaborates [ARCHITECTURE.md §20](ARCHITECTURE.md#20-responsive-layout-strategy) and [DESIGN_SPECIFICATION.md §7](DESIGN_SPECIFICATION.md#7-grid-system)/[§21](DESIGN_SPECIFICATION.md#21-responsive-behaviour) at the code level — the breakpoint *values* (compact <600dp, medium 600–839dp, expanded ≥840dp) are already frozen in those documents; this section is about how one codebase expresses them without forking.

A single `core/utils/breakpoint.dart` exposes the current `WindowSizeClass` (compact/medium/expanded) derived from `MediaQuery.sizeOf(context).width` — the **one and only** place breakpoint logic exists. `routing/shells/player_shell_scaffold.dart` and `coach_shell_scaffold.dart` consume this single utility to decide bottom-nav vs. rail vs. sidebar chrome ([DESIGN_SPECIFICATION.md §13](DESIGN_SPECIFICATION.md#13-navigation-architecture)); individual screens consume it to decide single-column vs. master-detail layout ([DESIGN_SPECIFICATION.md §21](DESIGN_SPECIFICATION.md#21-responsive-behaviour)).

**"Do not fork codebases" means, concretely:** there is exactly one screen widget per route, always — never a `HomeScreenMobile` and a `HomeScreenDesktop`. Platform checks (`Platform.isIOS`, `Platform.isMacOS`, etc.) are reserved strictly for genuinely platform-specific concerns with no UI dimension (file system paths, platform-specific permission request flows) — they are never used to select between two different layouts or widget trees. Layout adaptation is driven exclusively by `WindowSizeClass`, which is a function of available width, not of platform.

---

## 19. Future Expansion

How each capability named in this phase's brief can be added without restructuring the application — every one is additive under the architecture already frozen above, which is the direct payoff of the decisions in [ARCHITECTURE.md](ARCHITECTURE.md) and this document.

| Future Capability | How It's Added, Without Restructuring |
|---|---|
| **BLE / direct wearable communication** | A new `services/ble/` folder (a `BleService`, mirroring the pattern every other Firebase service already follows) and a new `features/device_pairing/` feature, following exactly the same presentation/domain/data structure as every existing feature. This is the exact extension point [ARCHITECTURE.md's Future Evolution section](ARCHITECTURE.md#future-evolution) already designed for — the `BleFailure` type retained (unused) in `core/errors/` since Phase 1 is specifically there for this day. |
| **Apple Watch / Wear OS** | Flutter has no native watch UI target; this would be a companion native watch app (WatchOS/Wear OS) communicating with the phone app via platform channels — a genuinely new architecture spike when prioritized, not designed in further detail here to avoid inventing scope beyond this phase's mandate |
| **Video** | A new Storage-backed media type, following the same pattern already established for avatars and report PDFs ([BACKEND_SPECIFICATION.md §16](BACKEND_SPECIFICATION.md#16-cloud-storage-folder-hierarchy)) — a new `services/firebase/storage_service.dart` method plus a new `design_system/components` video player component. Additive to both layers, no restructuring. |
| **Additional sensors** | Handled almost entirely on the backend side: a new `alerts.type` or `summaryMetrics` field ([BACKEND_SPECIFICATION.md §23](BACKEND_SPECIFICATION.md#23-future-scalability)) requires zero Flutter architecture change, since Flutter already displays whatever fields exist on those documents generically through its repository/model layer — only the `domain/models` for `Session`/`Alert` gain a new optional field |
| **AI improvements** | Entirely a laptop/ML pipeline concern per [ADR-030](DECISIONS.md#adr-030-laptop-centric-ble-etl-and-ml-pipeline-for-mvp); Flutter's consumption of `alerts`/`reports` is already provider-and-model-agnostic ([ARCHITECTURE.md §14](ARCHITECTURE.md#14-ai-analysis-pipeline)) — a better model on the laptop requires zero Flutter change |

The common thread across all five: the feature-first structure ([§2](#2-folder-structure), [§3](#3-feature-organization)) means a new capability is a new feature folder or a new service, never a change to an existing feature's internals; the repository pattern ([§7](#7-repository-pattern)) means a new data source is a new datasource behind an existing or new interface, never a UI change; and the backend's extensible schema ([BACKEND_SPECIFICATION.md §23](BACKEND_SPECIFICATION.md#23-future-scalability)) means most sensor/AI evolution requires no Flutter change at all.

---

## 20. Architecture Decisions

Per this phase's explicit instruction, **no existing ADR in [DECISIONS.md](DECISIONS.md) is modified.** The following are new engineering decisions this phase makes, proposed for approval as ADR-032 through ADR-038. They are not yet recorded in DECISIONS.md.

| Proposed ADR | Decision | Summary of Reasoning |
|---|---|---|
| **ADR-032** (proposed) | Feature layer structure is `presentation / domain / data`, with an *optional*, feature-local `application/` sub-layer only when a controller would otherwise coordinate 3+ repositories | Reconciles this phase's brief with the frozen [ADR-005](DECISIONS.md#adr-005-overall-application-architecture--pragmatic-layered-architecture) rather than silently overriding it — see [§1](#1-overall-flutter-architecture) |
| **ADR-033** (proposed) | `repositories/`, `models/`, `widgets/`, `utils/`, `extensions/` exist only nested (inside features, `shared/`, or `core/`), never as flat top-level `lib/` folders | Preserves [ADR-006](DECISIONS.md#adr-006-folder-structure--feature-first)'s feature-first structure — see [§2](#2-folder-structure) |
| **ADR-034** (proposed) | Architecture tests (import-boundary enforcement) are a mandatory CI gate, not just a code-review convention | Turns "no widget touches Firebase directly" ([ADR-010](DECISIONS.md#adr-010-repository-pattern-for-all-external-data-access)) into a mechanically enforced rule — see [§15](#15-testing-strategy) |
| **ADR-035** (proposed) | Golden tests are added to the testing pyramid, scoped to `design_system/components` only (not feature screens) | Protects [DESIGN_SPECIFICATION.md](DESIGN_SPECIFICATION.md)'s frozen visual language from silent drift without the maintenance cost of full-screen golden tests |
| **ADR-036** (proposed) | Design tokens for Alert Crimson and the elevation-overlay model are implemented as custom Flutter `ThemeExtension`s, not forced into Material's default `ColorScheme`/elevation model | Material 3's built-in roles don't have a slot for either — see [§10](#10-design-system-implementation) |
| **ADR-037** (proposed) | Three Flutter flavors (development/staging/production), each with an isolated Firebase project, one shared `bootstrap()` function | Standard, low-risk environment-isolation pattern; directly required by [BACKEND_SPECIFICATION.md](BACKEND_SPECIFICATION.md)'s environment-isolated data model — see [§14](#14-configuration) |
| **ADR-038** (proposed) | Flutter calls exactly two Cloud Functions at MVP (join-team, create-team) for `users/{uid}.workspaces` mutation; all other Cloud-Function-mediated writes remain laptop-only | Direct consequence of [ADR-031](DECISIONS.md#adr-031-single-application-with-player-and-coach-workspace-switching)'s resolution — narrows what "Flutter networking" means in practice — see [§8](#8-networking) |

---

## Assumptions

- The FlutterFire CLI will be used to generate per-environment `firebase_options_*.dart` files during Phase 4 scaffolding; this document specifies where they live ([§14](#14-configuration)) but does not generate them.
- `golden_toolkit` (or an equivalent) and a custom architecture-test script are assumed available/buildable in whatever CI provider is eventually chosen ([ADR-029](DECISIONS.md#adr-029-cicd-strategy--staged-pipeline-with-gated-backend-deployment), still open).
- The four bespoke icon glyphs and Inter typeface licensing ([DESIGN_SPECIFICATION.md Open Questions](DESIGN_SPECIFICATION.md#open-questions)) are assumed resolved before `design_system/` implementation begins in Phase 4 — this document specifies where they'd go, not what they are.

## Open Questions

1. **Session History / Alert Inbox pagination** — [BACKEND_SPECIFICATION.md §22](BACKEND_SPECIFICATION.md#22-flutter-read-contract) doesn't specify a page size; [§16](#16-performance) recommends cursor-based pagination but this needs confirming (and, if approved, a corresponding read-contract update) before Phase 4 implements those screens.
2. **Offline indicator component** — [§9](#9-offline-behaviour) recommends a "showing saved data" indicator; this is a `design_system/components` addition belonging to [DESIGN_SPECIFICATION.md](DESIGN_SPECIFICATION.md), not this document, and should be raised there.
3. **Proposed ADRs 032–038** ([§20](#20-architecture-decisions)) — need explicit approval and formal recording in [DECISIONS.md](DECISIONS.md) before Phase 4 begins, per this phase's instruction not to record them here directly.
4. **CI provider** (still open per [ADR-029](DECISIONS.md#adr-029-cicd-strategy--staged-pipeline-with-gated-backend-deployment)) — this document's testing and configuration strategy ([§14](#14-configuration), [§15](#15-testing-strategy)) assumes a CI system capable of running flavors, golden tests, and architecture tests, but doesn't select one.

## Document Control

| Field | Value |
|---|---|
| Owner | Lead Flutter Architect |
| Status | Frozen — Phase 3 (Flutter Engineering Architecture). Binding for Phase 4 implementation, pending approval of the Proposed ADRs in [§20](#20-architecture-decisions). |
| Related documents | [README.md](README.md), [SPECIFICATION.md](SPECIFICATION.md), [ARCHITECTURE.md](ARCHITECTURE.md), [BACKEND_SPECIFICATION.md](BACKEND_SPECIFICATION.md), [DESIGN_SPECIFICATION.md](DESIGN_SPECIFICATION.md), [DECISIONS.md](DECISIONS.md), [ROADMAP.md](ROADMAP.md) |

This document is updated, not rewritten, as later phases resolve its Open Questions or as implementation surfaces a genuine need to adjust a folder, provider convention, or test category. A change that reverses a decision recorded here should be logged as a new ADR in [DECISIONS.md](DECISIONS.md), exactly as ARCHITECTURE.md, BACKEND_SPECIFICATION.md, and DESIGN_SPECIFICATION.md already do.
