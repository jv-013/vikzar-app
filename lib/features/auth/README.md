# Feature: Auth

**Screens (DESIGN_SPECIFICATION.md §16):** Sign In / Create Account (#2).

**Purpose:** Identity gate for the app. Wraps Firebase Authentication per
[ARCHITECTURE.md §9](../../../ARCHITECTURE.md#9-authentication-architecture).
Not implemented in Phase 4 (bootstrap) — see FLUTTER_ARCHITECTURE.md §4 for the
full auth-gated router design this feature will plug into.

**Layers:** presentation/{screens,widgets,controllers}, domain/{models,repositories},
data/{repositories,datasources} — per FLUTTER_ARCHITECTURE.md §3.
