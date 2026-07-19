# Feature: Devices

**Screens (DESIGN_SPECIFICATION.md §16):** Pod Connection (#14).

**Purpose:** Read-only device status (assignment, battery, connection) —
**not a pairing flow**. All BLE connectivity is a laptop responsibility for
MVP per [DECISIONS.md ADR-030](../../../DECISIONS.md#adr-030-laptop-centric-ble-etl-and-ml-pipeline-for-mvp).
Not implemented in Phase 4.

**Layers:** presentation/{screens,widgets,controllers}, domain/{models,repositories},
data/{repositories,datasources} — per FLUTTER_ARCHITECTURE.md §3.
