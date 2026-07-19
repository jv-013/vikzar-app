# Feature: Workspace

**Screens (DESIGN_SPECIFICATION.md §16):** Workspace Selection (#3, onboarding
entry point), Workspace Switcher sheet (#26, always-available in-app control).

**Purpose:** Owns the Player/Coach workspace-switching mechanic per
[DECISIONS.md ADR-031](../../../DECISIONS.md#adr-031-single-application-with-player-and-coach-workspace-switching):
`workspaces`/`defaultWorkspace` (server) and the active-workspace pointer
(local device state only — never Firestore). Not implemented in Phase 4.

**Layers:** presentation/{screens,widgets,controllers}, domain/{models,repositories},
data/{repositories,datasources} — per FLUTTER_ARCHITECTURE.md §3.
