# Vikzar

**Know Every Impact.**

Vikzar is a sports performance and biomechanics analytics platform for football. This repository contains the companion application software for Vikzar wearable hardware — the single Flutter codebase used by players, coaches, and (in future phases) clinical staff to monitor impact exposure, training load, and elevated injury risk.

This README is the entry point to the project. It explains what Vikzar is, what hardware it works with, how the software is expected to evolve, and how this repository is organized.

---

## What Is Vikzar

Football is a contact sport, and repeated or severe impacts to the body — particularly in ways that go unnoticed in the moment — are a leading cause of both acute injury and long-term harm. Vikzar exists to make impact exposure visible, in real time, to the people responsible for player welfare: the players themselves and their coaches.

Vikzar pairs purpose-built wearable sensors with a companion application that streams, stores, and interprets impact and biomechanical data. The goal is not to replace medical judgment, but to give players and coaches better information, sooner.

## Hardware Overview

The Vikzar application is designed as the software counterpart to Vikzar's wearable hardware line. Current hardware includes:

- **Smart Pod** — mounted on or inside football shinguards, worn during matches and training. This is the primary sensing device.
- **EMG Thigh Band (optional)** — a wireless thigh-worn band used during training sessions to capture muscular activity data.

The application communicates with these devices over Bluetooth Low Energy (BLE) and is responsible for device pairing, live data streaming, session recording, and surfacing insights derived from that data.

Hardware capabilities are expected to expand over time. The software architecture should treat devices as a category to be extended, not a fixed, hardcoded pair.

## Who Uses Vikzar

The application supports two primary user roles at MVP:

- **Player** — connects their own device(s), views their own sessions, impact history, and profile.
- **Coach** — manages a team or squad, monitors players live during sessions, reviews team and individual history, and manages devices at a team level.

Additional roles (e.g. clinician/medical staff, club administrator) are anticipated but out of scope for MVP. See [SPECIFICATION.md](SPECIFICATION.md) and [ROADMAP.md](ROADMAP.md).

## Development Philosophy

Vikzar's software is being built to last, not to be shipped once and abandoned. That shapes how this project is run:

- **Documentation before code.** Architecture, product principles, and decisions are written down before implementation begins, and are kept current as the project evolves.
- **One codebase, many form factors.** The application is built from day one as a single Flutter codebase spanning phones, tablets, and desktop — not a phone app that is later awkwardly adapted.
- **Principles guide features.** Every feature is evaluated against the principles in [PRODUCT_PRINCIPLES.md](PRODUCT_PRINCIPLES.md) before it is designed or built.
- **Decisions are recorded, not lost.** Significant product, UX, architecture, and engineering decisions are logged in [DECISIONS.md](DECISIONS.md) with their reasoning and alternatives, so future contributors understand *why*, not just *what*.
- **Safety before engagement.** Player safety takes precedence over growth or engagement mechanics in every tradeoff.

## Platform Scope

Vikzar is not a mobile-only application. It is designed to run on:

- Android phones and tablets
- iPhone and iPad
- macOS
- Windows
- Linux

with an architecture that remains compatible with a future Flutter Web target. Coach-facing workflows in particular are expected to scale naturally to larger displays (tablet and desktop), where more information can be shown at once — these are not simply phone screens stretched wider.

## Repository Purpose

This repository is the single source of truth for the Vikzar application: its specification, its architecture and product decisions, its roadmap, and its source code.

Architecture and product scope were defined first, before any code — deliberately, so implementation starts from a clear and agreed foundation rather than being discovered along the way. The Flutter project (`lib/`, `test/`, and the platform folders) now exists, built exactly to the structure specified in [FLUTTER_ARCHITECTURE.md](FLUTTER_ARCHITECTURE.md); see [Getting Started](#getting-started) below to run it.

### Key Documents

| Document | Purpose |
|---|---|
| [README.md](README.md) | This file. Project overview and orientation. |
| [SPECIFICATION.md](SPECIFICATION.md) | The master specification for the application. Updated continuously as features are designed. |
| [ARCHITECTURE.md](ARCHITECTURE.md) | The engineering blueprint — application architecture, state management, backend, data model, and every major technical decision, with full reasoning. |
| [BACKEND_SPECIFICATION.md](BACKEND_SPECIFICATION.md) | The official backend contract — complete Firestore schema, Security Rules strategy, and the exact upload/read contracts shared between the laptop ETL/ML pipeline, Firebase, and the Flutter application. |
| [DESIGN_SPECIFICATION.md](DESIGN_SPECIFICATION.md) | The permanent product design specification — visual language, design tokens, information architecture for both workspaces, component library, and wireframe descriptions for every MVP screen. |
| [FLUTTER_ARCHITECTURE.md](FLUTTER_ARCHITECTURE.md) | The buildable Flutter engineering architecture — complete `lib/` folder structure, feature organization, navigation, state management, dependency injection, testing strategy, and every other implementation-adjacent decision, frozen ahead of Phase 4 implementation. |
| [PRODUCT_PRINCIPLES.md](PRODUCT_PRINCIPLES.md) | The non-negotiable principles every feature and design decision must be checked against. |
| [DECISIONS.md](DECISIONS.md) | Architecture Decision Record (ADR) log — the history and reasoning behind significant decisions. |
| [ROADMAP.md](ROADMAP.md) | The phased plan from architecture through to a production-ready MVP. |
| [CHANGELOG.md](CHANGELOG.md) | Notable changes to the project over time, in Keep a Changelog format. |

## Getting Started

Requires the Flutter stable channel (developed against 3.44.0) with the `web`, `macos`, `windows`, `linux`, `android`, and `ios` platforms enabled.

```
flutter pub get
flutter analyze
flutter test
flutter run -d chrome   # or -d macos, or any connected device
```

The app now has a complete identity, onboarding, and application-shell experience, genuinely backed by Firestore: Splash → Authentication (passwordless — email, then a 6-digit code) → Workspace Selection (Player/Coach) → the full onboarding sequence for whichever workspace was chosen (completing it writes the collected profile, and — for a coach — creates or joins a team, to Firestore) → **Player Home or Coach Home**, with bottom navigation, a profile badge for Settings/Notifications/Profile/workspace actions, and a Notification Center streaming real (currently empty) data. Authentication runs against the real, connected Firebase project (`vikzar-prod`) — but **code verification is still a documented placeholder** (any syntactically valid 6-digit code is accepted, see [ADR-044](DECISIONS.md#adr-044-placeholder-otp-verification-pending-real-backend-delivery)), so sign-in always succeeds today; real code delivery/verification is a later phase's work. Session/sensor/team-monitoring data (sessions, risk scores, live team status, alerts) remains an honest placeholder — no Bluetooth/ETL/ML pipeline exists yet, per [ADR-051](DECISIONS.md#adr-051-client-direct-firestore-writes-for-workspace-team-and-onboarding-state-mvp-self-service-model).

## Status

**Current phase:** Identity & Access, the complete onboarding experience, the first application shell, and real Firestore-backed persistence for everything the app collects (profiles, workspace ownership, teams, Become-a-Coach requests, notifications) are all done (Roadmap [Phase 4 — Authentication](ROADMAP.md#phase-4--authentication)). A single-workspace account (every new account, always — Coach access is never automatic, requested via "Become a Coach" and never auto-granted) sees no hint that a second workspace exists; an account holding both workspaces can switch between them instantly, locally, no logout. The official Vikzar brand marks are imported and in use; typography is frozen (Inter for body text, implemented; Nohemi for headings, decided but its font asset not yet sourced). Live Team Monitoring, real session/Timeline/History content, and Bluetooth remain unbuilt — those begin in later phases, once the laptop ETL/ML pipeline and Cloud Functions exist.

**Firebase:** connected to the real `vikzar-prod` project (Android, iOS, macOS, Web) — see [DECISIONS.md ADR-050](DECISIONS.md#adr-050-production-firebase-connection-requires-the-project-owners-own-credentials--cannot-be-completed-by-an-agent). Firestore reads/writes are real, with offline persistence enabled; `firestore.rules`/`storage.rules`/`firestore.indexes.json` are written but not deployed. Enabling the Authentication/Firestore/Storage products in the Firebase Console has not been confirmed; until then, real Firebase calls fail gracefully rather than crash, per this app's established `Failure`-mapping architecture.

See [ROADMAP.md](ROADMAP.md) for what comes next.
