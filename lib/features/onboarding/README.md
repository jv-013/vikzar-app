# Feature: Onboarding

**Screens (DESIGN_SPECIFICATION.md §16, §19.1):** Splash (#1, implemented in
Phase 4 — see `presentation/screens/splash_screen.dart`), Level (#4), Profile
Form (#5), Permissions (#6), Connect First Pod / Create-Join Team (#7, #8).

**Purpose:** The frozen six-screen onboarding flow. Workspace Selection (#3)
lives in the `workspace` feature since it is reused by the Workspace Switcher.
Not implemented beyond Splash in Phase 4 (bootstrap).

**Layers:** presentation/{screens,widgets,controllers}, domain/{models,repositories},
data/{repositories,datasources} — per FLUTTER_ARCHITECTURE.md §3.
