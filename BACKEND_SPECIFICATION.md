# Vikzar Backend Specification

**Status:** Foundation — official backend contract. Confirmed as consistent with [ARCHITECTURE.md](ARCHITECTURE.md), [SPECIFICATION.md](SPECIFICATION.md), and [ROADMAP.md](ROADMAP.md) as of Phase 1.6 ([DECISIONS.md ADR-030](DECISIONS.md#adr-030-laptop-centric-ble-etl-and-ml-pipeline-for-mvp)) and the Phase 2 freeze review ([DECISIONS.md ADR-031](DECISIONS.md#adr-031-single-application-with-player-and-coach-workspace-switching), `users/{uid}` §1.5 revised from a single `role` enum to `workspaces`/`defaultWorkspace`). Phase 1.6 changed framing only; the Phase 2 freeze review changed one field's shape on one document, `users/{uid}` — every other collection, Security Rule, and contract in this document is unchanged.

**Owner:** Lead Backend Architect

This document is the official contract shared between every system that touches Vikzar's backend: the **Laptop ETL Pipeline**, the **Laptop Machine Learning Pipeline**, **Firebase**, the **Flutter Application** (Player and Coach), and the **Coach Dashboard**. It defines exactly what data exists, where it lives, who writes it, who reads it, and under what constraints.

This document does not contain application code, Flutter code, or pseudocode. It is an engineering specification: schemas, contracts, and rules.

**Relationship to other documents:** [ARCHITECTURE.md](ARCHITECTURE.md) established Firebase as the backend platform (ADR-012) and, in its original Phase 1 form, sketched a preliminary Firestore shape (ARCHITECTURE.md §10) and a Flutter-side BLE architecture (ARCHITECTURE.md §7) under the assumption, at that time, that the Flutter application itself connects to hardware over BLE. This document's laptop-centric system architecture — computation performed entirely by a laptop-based pipeline, with Firebase strictly as a synchronization and storage layer — was subsequently confirmed as the approved MVP architecture and formally reconciled into ARCHITECTURE.md via [DECISIONS.md ADR-030](DECISIONS.md#adr-030-laptop-centric-ble-etl-and-ml-pipeline-for-mvp) (Phase 1.6). ARCHITECTURE.md §7 and §14 now describe the same laptop-centric architecture as this document. Where this document's data model is more specific than ARCHITECTURE.md §10, it remains the authoritative, field-level source. This document, ARCHITECTURE.md, SPECIFICATION.md, and ROADMAP.md now describe exactly the same system architecture; this document does not itself modify ARCHITECTURE.md or DECISIONS.md.

Every design choice below still answers to [PRODUCT_PRINCIPLES.md](PRODUCT_PRINCIPLES.md) — in particular Principle 2 (player safety before engagement), Principle 7 (scalable without overengineering), and Principle 10 (long-term maintainability).

---

## Table of Contents

0. [System Actors and Trust Boundaries](#0-system-actors-and-trust-boundaries)
1. [Complete Firestore Schema](#1-complete-firestore-schema)
2. [Document Relationships](#2-document-relationships)
3. [Authentication Mapping](#3-authentication-mapping)
4. [Player Ownership Model](#4-player-ownership-model)
5. [Coach Ownership Model](#5-coach-ownership-model)
6. [Team Ownership Model](#6-team-ownership-model)
7. [Device Ownership Model](#7-device-ownership-model)
8. [Live Session Data Model](#8-live-session-data-model)
9. [Session Summary Data Model](#9-session-summary-data-model)
10. [Historical Player Data](#10-historical-player-data)
11. [Analytics Data Model](#11-analytics-data-model)
12. [Alert Model](#12-alert-model)
13. [Report Model](#13-report-model)
14. [Firestore Indexes](#14-firestore-indexes)
15. [Security Rules Strategy](#15-security-rules-strategy)
16. [Cloud Storage Folder Hierarchy](#16-cloud-storage-folder-hierarchy)
17. [Cloud Function Responsibilities](#17-cloud-function-responsibilities)
18. [Notification Triggers](#18-notification-triggers)
19. [Offline Synchronization Strategy](#19-offline-synchronization-strategy)
20. [Data Retention Strategy](#20-data-retention-strategy)
21. [Upload Contract for the Laptop](#21-upload-contract-for-the-laptop)
22. [Flutter Read Contract](#22-flutter-read-contract)
23. [Future Scalability](#23-future-scalability)
24. [Example JSON](#24-example-json)

---

## 0. System Actors and Trust Boundaries

| Actor | Role | Trust Level |
|---|---|---|
| **Sensors** (Smart Pod, EMG Thigh Band) | Emit raw signal over Bluetooth. | N/A — hardware, not a network principal. |
| **Laptop ETL Pipeline** | Receives Bluetooth data, cleans/structures it. | Trusted ingestion principal (below). |
| **Laptop Machine Learning Pipeline** | Feature extraction, ML inference, ACL/injury Risk Engine. | Trusted ingestion principal (below). |
| **Cloud Functions** | The *only* code path permitted to write computed session, alert, report, and live-monitoring data into Firestore/Storage. | Fully trusted (Firebase Admin privileges; not subject to Security Rules). |
| **Cloud Firestore** | System of record for structured, queryable data. | N/A — data store. |
| **Firebase Storage** | Store for large/binary data (raw archives, exported reports, images). | N/A — data store. |
| **Firebase Authentication** | Identity provider for both human users (Player, Coach) and the laptop's ingestion principal. | N/A — identity provider. |
| **Flutter Application** (Player, Coach) | Reads synchronized data; performs a small, explicit set of direct writes (profile edits, alert acknowledgement, FCM token registration). | Untrusted client, fully governed by Security Rules. |
| **Coach Dashboard** | A coach-facing surface of the same Flutter application (adaptive, per [ARCHITECTURE.md §20](ARCHITECTURE.md#20-responsive-layout-strategy)), not a separate codebase or backend contract. | Same as Flutter Application. |

**The non-negotiable constraint governing this entire document:** Firebase never performs ETL, feature extraction, machine learning, or ACL/injury risk prediction. Every field in this schema that looks "computed" (risk scores, load indices, fatigue indices, muscle activation metrics) was computed by the laptop before it ever reaches Firebase. Cloud Functions in this system perform only: validation, authorization checks, writing already-computed values, arithmetic aggregation of already-computed values (e.g. summing existing session totals into a weekly rollup), timeout/heartbeat checks, and notification dispatch. A Cloud Function must never process a raw sensor sample or derive a new risk/health metric from raw signal data — if a future requirement seems to need that, it belongs on the laptop pipeline, not in Firebase, and should be raised as an architecture decision, not implemented silently.

**Why the laptop does not write to Firestore/Storage directly:** the laptop is operated in the field (pitchside, training ground) and is a more exposed environment than a cloud service. Rather than provisioning it with a broad Firebase Admin credential, the laptop authenticates as a scoped **ingestion principal** (§3) and calls a small, fixed set of **HTTPS Callable Cloud Functions** (§17, §21). Those functions validate the payload and the caller's authorized scope, then perform the actual Firestore/Storage writes using Admin privileges. This keeps the field-deployed credential narrow and revocable, gives a single validated entry point for all data entering the system, and matches the trust-boundary principle already established in [ARCHITECTURE.md §12](ARCHITECTURE.md#12-cloud-functions-responsibilities) and [§19](ARCHITECTURE.md#19-security-architecture) (Cloud Functions handle what Security Rules cannot safely enforce; the client is never trusted with privileged writes).

---

## 1. Complete Firestore Schema

Seven top-level collections, four subcollections. Every collection below states its purpose, its document ID convention, its fields with types, and — critically — **who writes it** and **who reads it** (elaborated further in §15).

### 1.1 `organizations/{orgId}`

Represents a club, academy, university, or professional team — the top-level tenant. Exists from MVP to support §23 (Future Scalability) without later redesign.

| Field | Type | Required | Description |
|---|---|---|---|
| `orgId` | string | Yes | Document ID, also stored as a field for query convenience. |
| `name` | string | Yes | Organization display name. |
| `type` | string (enum) | Yes | One of `club`, `academy`, `university`, `professional_team`. |
| `country` | string | Yes | ISO 3166-1 alpha-2 country code (e.g. `"GB"`). |
| `region` | string | No | State/province/region, free text. |
| `timezone` | string | Yes | IANA timezone identifier (e.g. `"Europe/London"`). |
| `status` | string (enum) | Yes | One of `active`, `trial`, `suspended`. |
| `createdAt` | timestamp | Yes | Server timestamp at creation. |
| `updatedAt` | timestamp | Yes | Server timestamp of last update. |

**Written by:** administrative provisioning process (out of scope of this document — see Open Questions). **Read by:** Flutter Application (org name/branding context), Cloud Functions (scope validation).

### 1.2 `teams/{teamId}`

A squad within an organization.

| Field | Type | Required | Description |
|---|---|---|---|
| `teamId` | string | Yes | Document ID. |
| `orgId` | string | Yes | Reference to `organizations/{orgId}`. |
| `name` | string | Yes | Team display name. |
| `ageGroup` | string | No | Free text, e.g. `"U18"`, `"Senior"`. |
| `coachIds` | array&lt;string&gt; | Yes | Firebase Auth uids of coaches for this team. Array supports multiple coaches per team. |
| `country` | string | No | Denormalized from the parent organization for query convenience. |
| `status` | string (enum) | Yes | One of `active`, `archived`. |
| `createdAt` | timestamp | Yes | |
| `updatedAt` | timestamp | Yes | |

**Written by:** Flutter Application (coach, for `name`/`ageGroup` only, via Security Rules), administrative provisioning (for `orgId`, `coachIds` at creation). **Read by:** Flutter Application (coaches and members of the team).

### 1.3 `teams/{teamId}/members/{uid}`

Subcollection: roster entry for a player on this team. Document ID equals the player's Firebase Auth `uid`.

| Field | Type | Required | Description |
|---|---|---|---|
| `uid` | string | Yes | Document ID; the player's Firebase Auth uid. |
| `displayName` | string | Yes | Denormalized from `users/{uid}.displayName`, kept in sync by Cloud Function, to avoid N+1 reads on roster screens. |
| `avatarUrl` | string | No | Denormalized from `users/{uid}.avatarUrl`. |
| `jerseyNumber` | number | No | |
| `position` | string | No | Free text (e.g. `"Midfielder"`). |
| `role` | string (enum) | Yes | `player` at MVP. Reserved for future roster roles (e.g. `assistant_coach`) without schema change. |
| `status` | string (enum) | Yes | One of `active`, `injured`, `inactive`. |
| `joinedAt` | timestamp | Yes | |

**Written by:** Flutter Application (coach only, for roster management fields), Cloud Function (denormalized `displayName`/`avatarUrl` sync on profile change). **Read by:** Flutter Application (team members and coach).

### 1.4 `teams/{teamId}/liveMonitoring/{playerId}`

Subcollection: the denormalized, coach-facing live monitoring surface — one document per currently-relevant player, fanned out from that player's `sessions/{sessionId}/live/current` document by a Cloud Function trigger (§17). This exists so the Coach Dashboard's Live Team Monitoring view can listen to one shallow collection instead of opening N per-session listeners.

| Field | Type | Required | Description |
|---|---|---|---|
| `playerId` | string | Yes | Document ID; equals the player's uid. |
| `sessionId` | string | Yes | The active session this entry reflects. |
| `displayName` | string | Yes | Denormalized. |
| `connectionStatus` | string (enum) | Yes | One of `connected`, `degraded`, `disconnected`. |
| `lastTickAt` | timestamp | Yes | Timestamp of the most recent live tick received. |
| `currentRiskScore` | number | Yes | 0.0–1.0, as computed by the laptop's Risk Engine. |
| `currentRiskLevel` | string (enum) | Yes | One of `low`, `moderate`, `high`, `critical`. |
| `currentLoad` | number | Yes | Normalized current load index (0–100), laptop-computed. |
| `cumulativeImpacts` | number | Yes | Running impact count for the current session. |
| `deviceBattery` | map&lt;string, number&gt; | No | Keyed by `deviceId`, value 0–100. |
| `updatedAt` | timestamp | Yes | Server timestamp of last fan-out write. |

**Written by:** Cloud Function only (fan-out trigger; never a direct client or laptop write). **Read by:** Flutter Application (coach of the team; a player may read their own entry).

### 1.5 `users/{uid}`

Document ID equals the Firebase Auth uid. **Revised at the Phase 2 freeze review** per [DECISIONS.md ADR-031](DECISIONS.md#adr-031-single-application-with-player-and-coach-workspace-switching): the account-level `role` enum is replaced by a `workspaces` structure, supporting one account holding both a Player and a Coach workspace.

| Field | Type | Required | Description |
|---|---|---|---|
| `uid` | string | Yes | Document ID. |
| `email` | string | Yes | From Firebase Auth. |
| `displayName` | string | Yes | |
| `workspaces` | map | Yes | Which workspace(s) this account holds. See below. |
| `defaultWorkspace` | string (enum) | Yes | `player` or `coach`. Set once at onboarding; the fallback workspace shown on a device with no locally cached "last used workspace" state. The *currently active* workspace is never stored here or anywhere in Firestore — it is local, per-device app state only (Riverpod + local storage), per ADR-031. |
| `dateOfBirth` | string | No | ISO 8601 date (`YYYY-MM-DD`); relevant primarily for players. |
| `country` | string | No | ISO 3166-1 alpha-2. |
| `primaryOrgId` | string | No | Reference to `organizations/{orgId}`. |
| `avatarUrl` | string | No | Firebase Storage download URL. |
| `careerStats` | map | Yes | See below. Maintained by Cloud Function, never client-written. |
| `fcmTokens` | array&lt;string&gt; | No | Registered push notification tokens for this user's devices. |
| `status` | string (enum) | Yes | One of `active`, `inactive`. |
| `createdAt` | timestamp | Yes | |
| `updatedAt` | timestamp | Yes | |

`workspaces` map fields — each key is present only if the account holds that workspace; presence of the key is itself the "has this workspace" signal, with no separate boolean:
- `workspaces.player` (map, optional): `{ teamId: string | null }` — the team this player belongs to, if any.
- `workspaces.coach` (map, optional): `{ teamIds: array<string> }` — the team(s) this account coaches.

This structure resolves an ambiguity the previous flat `teamIds` array had: an account holding both workspaces can now have its played-for team and its coached-for teams recorded distinctly, rather than merged into one undifferentiated array.

`careerStats` map fields: `totalSessions` (number), `totalImpacts` (number), `lastSessionAt` (timestamp, nullable), `averageRiskScore30d` (number, nullable).

**Written by:** Flutter Application (self, for `displayName`/`avatarUrl`/`fcmTokens` only), Cloud Function (`careerStats`, `workspaces`, `defaultWorkspace` — the latter two require server-side validation, e.g. verifying a team invite code before adding a `coach` workspace, matching how `role`/`teamIds` were already Cloud-Function-written prior to this revision). **Read by:** Flutter Application (self; a coach may read profiles of players on a team they coach — §5).

### 1.6 `users/{uid}/notifications/{notificationId}`

Subcollection: in-app, durable notification record (distinct from the ephemeral FCM push itself).

| Field | Type | Required | Description |
|---|---|---|---|
| `notificationId` | string | Yes | Document ID. |
| `type` | string (enum) | Yes | One of `alert`, `report_ready`, `session_summary`, `team_invite`, `system`. |
| `title` | string | Yes | |
| `body` | string | Yes | |
| `relatedAlertId` | string | No | Set when `type == "alert"`. |
| `relatedReportId` | string | No | Set when `type == "report_ready"`. |
| `relatedSessionId` | string | No | Set when `type == "session_summary"`. |
| `read` | boolean | Yes | Defaults `false`. |
| `createdAt` | timestamp | Yes | |

**Written by:** Cloud Function (creation), Flutter Application (self, `read` field only). **Read by:** Flutter Application (self only).

### 1.7 `devices/{deviceId}`

Document ID equals the hardware device identifier (§21).

| Field | Type | Required | Description |
|---|---|---|---|
| `deviceId` | string | Yes | Document ID. |
| `type` | string (enum) | Yes | `smart_pod` or `emg_band`. |
| `serialNumber` | string | Yes | Manufacturer serial. |
| `ownerId` | string | No | uid of the assigned player; null if unassigned (pooled). |
| `assignedTeamId` | string | No | Reference to `teams/{teamId}`. |
| `firmwareVersion` | string | No | |
| `lastSeenAt` | timestamp | No | Last time the laptop reported this device as connected. |
| `lastKnownBattery` | number | No | 0–100. |
| `status` | string (enum) | Yes | One of `active`, `inactive`, `maintenance`, `lost`. |
| `createdAt` | timestamp | Yes | |
| `updatedAt` | timestamp | Yes | |

**Written by:** Flutter Application (coach, for `ownerId`/`assignedTeamId`/`status` assignment fields only), Cloud Function (`lastSeenAt`, `lastKnownBattery`, telemetry fields — never client-written). **Read by:** Flutter Application (owner; coach of `assignedTeamId`).

### 1.8 `sessions/{sessionId}`

The system of record for one capture session (training or match). Created at session start, updated at completion. Document ID is laptop-generated (§21).

| Field | Type | Required | Description |
|---|---|---|---|
| `sessionId` | string | Yes | Document ID. |
| `playerId` | string | Yes | uid of the player wearing the hardware. |
| `teamId` | string | No | Null for a non-team (individual) session. |
| `orgId` | string | No | Denormalized from `teamId`'s organization, for scoped queries. |
| `type` | string (enum) | Yes | `training` or `match`. |
| `deviceIds` | array&lt;string&gt; | Yes | Devices used in this session. |
| `status` | string (enum) | Yes | One of `live`, `completed`, `completed_with_gaps`, `aborted`. |
| `startedAt` | timestamp | Yes | Set at session start. |
| `endedAt` | timestamp | No | Null while `status == "live"`. |
| `durationSeconds` | number | No | Set at completion. |
| `summaryMetrics` | map | No | Set at completion. See §9. |
| `dataCompleteness` | number | No | 0.0–1.0; fraction of expected live ticks actually received. Set at completion. |
| `rawDataStoragePath` | string | No | Firebase Storage path to the archived full-resolution data, if retained (§16). |
| `pipelineVersion` | string | Yes | Identifies the ETL/ML/Risk Engine version that produced this session's data — required for auditability of safety-relevant, ML-derived output. |
| `generatedBy` | string | Yes | Fixed value `"laptop_ingestion_pipeline"`, an explicit audit marker distinguishing laptop-originated data from any other future ingestion path. |
| `createdAt` | timestamp | Yes | |
| `updatedAt` | timestamp | Yes | |

**Written by:** Cloud Function only (`startSession`, `completeSession` — §17, §21). **Never** client-written. **Read by:** Flutter Application (playerId == self; coach of `teamId`).

### 1.9 `sessions/{sessionId}/live/current`

Subcollection with a single fixed document ID, `current`. Overwritten roughly once per second while the session is live. Not retained historically — it reflects only the latest known state.

| Field | Type | Required | Description |
|---|---|---|---|
| `sessionId` | string | Yes | |
| `playerId` | string | Yes | |
| `teamId` | string | No | |
| `sequenceNumber` | number | Yes | Monotonically increasing per session; authoritative ordering signal (§19, §21). |
| `tickTimestamp` | timestamp | Yes | Laptop-reported capture time for this tick. |
| `serverReceivedAt` | timestamp | Yes | Set by the Cloud Function via server timestamp; used to detect delivery latency, never used for event ordering. |
| `connectionStatus` | string (enum) | Yes | One of `connected`, `degraded`, `reconnecting`. |
| `metrics` | map | Yes | See §8. |
| `deviceBattery` | map&lt;string, number&gt; | No | Keyed by `deviceId`. |

**Written by:** Cloud Function only (`ingestLiveTick`). **Read by:** Flutter Application (playerId == self; coach of `teamId`) — though in practice the Coach Dashboard reads §1.4's fan-out collection instead, for efficiency.

### 1.10 `alerts/{alertId}`

Top-level collection. Safety-relevant, time-sensitive events, raised either by the laptop's Risk Engine mid-session or by a Cloud Function monitoring device health.

| Field | Type | Required | Description |
|---|---|---|---|
| `alertId` | string | Yes | Document ID. |
| `sessionId` | string | Yes | |
| `playerId` | string | Yes | |
| `teamId` | string | No | |
| `orgId` | string | No | Denormalized. |
| `severity` | string (enum) | Yes | One of `info`, `warning`, `critical`. |
| `type` | string (enum) | Yes | One of `high_impact`, `risk_threshold_exceeded`, `abnormal_fatigue_asymmetry`, `device_disconnected`, `low_battery`. |
| `message` | string | Yes | Human-readable, calm, plain-language (Principle 8) — composed by the laptop pipeline or Cloud Function, not the client. |
| `metricsSnapshot` | map | No | Relevant metric values at the moment the alert was raised. |
| `source` | string (enum) | Yes | One of `laptop_risk_engine`, `cloud_function_device_health`. |
| `triggeredAt` | timestamp | Yes | |
| `acknowledged` | boolean | Yes | Defaults `false`. |
| `acknowledgedBy` | string | No | uid of the coach who acknowledged it. |
| `acknowledgedAt` | timestamp | No | |

**Written by:** Cloud Function only for creation (`submitAlert`, `deviceHeartbeatMonitor`); Flutter Application (coach of `teamId`) may write **only** `acknowledged`/`acknowledgedBy`/`acknowledgedAt` — the single explicit client write permitted against safety-derived data in this schema. **Read by:** Flutter Application (playerId == self; coach of `teamId`).

### 1.11 `reports/{reportId}`

Top-level collection. Comprehensive, often longer-form output — a single session's full report, or a periodic rollup.

| Field | Type | Required | Description |
|---|---|---|---|
| `reportId` | string | Yes | Document ID. |
| `type` | string (enum) | Yes | One of `session_report`, `weekly_summary`, `player_profile_report`. |
| `playerId` | string | Yes | |
| `teamId` | string | No | |
| `orgId` | string | No | Denormalized. |
| `sessionId` | string | No | Set only when `type == "session_report"`. |
| `periodStart` | timestamp | No | Set for aggregate report types. |
| `periodEnd` | timestamp | No | Set for aggregate report types. |
| `generatedAt` | timestamp | Yes | |
| `generatedBy` | string (enum) | Yes | One of `laptop_ml_pipeline` (session_report), `cloud_function_aggregation` (weekly_summary, player_profile_report — pure arithmetic rollups of already-computed data, never new inference). |
| `summary` | map | Yes | Structured key metrics mirrored here for quick display without opening the Storage export. |
| `storagePath` | string | No | Reference to a generated PDF/export in Firebase Storage, if one exists. |
| `status` | string (enum) | Yes | One of `draft`, `final`. |

**Written by:** Cloud Function only (`submitReport` for laptop-originated session reports; `weeklySummaryAggregator` for scheduled rollups). **Never** client-written. **Read by:** Flutter Application (playerId == self; coach of `teamId`).

---

## 2. Document Relationships

```
organizations/{orgId}
   └── (referenced by) teams.orgId
   └── (referenced by) users.primaryOrgId
   └── (referenced by) sessions.orgId, alerts.orgId, reports.orgId  [denormalized]

teams/{teamId}
   ├── members/{uid}                       — one per player on the roster
   ├── liveMonitoring/{playerId}           — one per player currently live
   └── (referenced by) users.workspaces.player.teamId, users.workspaces.coach.teamIds,
                        sessions.teamId, devices.assignedTeamId,
                        alerts.teamId, reports.teamId

users/{uid}
   ├── notifications/{notificationId}
   └── (referenced by) sessions.playerId, alerts.playerId, reports.playerId,
                        devices.ownerId, teams/{teamId}/members/{uid} (doc ID)

devices/{deviceId}
   └── (referenced by) sessions.deviceIds (array)

sessions/{sessionId}
   ├── live/current                        — single doc, latest tick only
   └── (referenced by) alerts.sessionId, reports.sessionId (session_report only)

alerts/{alertId}      — leaf; references sessionId, playerId, teamId
reports/{reportId}    — leaf; references sessionId (optional), playerId, teamId
```

Firestore enforces no foreign keys — every reference above is a plain string field validated at write time by the Cloud Function performing the write (§17), not by the database itself. A reference field pointing to a non-existent document is a data integrity bug to catch in Cloud Function validation and testing, not something Firestore prevents natively.

---

## 3. Authentication Mapping

Firebase Authentication is the identity provider for **two distinct kinds of principal**, which must not be confused:

1. **Human users** — Player and Coach, per [ARCHITECTURE.md §9](ARCHITECTURE.md#9-authentication-architecture) and [DECISIONS.md ADR-003](DECISIONS.md). Auth uid == `users/{uid}` document ID. Workspace membership (`workspaces.player` / `workspaces.coach`) is read from the Firestore profile document, not from Auth custom claims, per ADR-013 — unchanged by [ADR-031](DECISIONS.md#adr-031-single-application-with-player-and-coach-workspace-switching)'s revision to the field's shape.

2. **The ingestion principal** — a non-human, system-level credential used exclusively by the Laptop ETL/ML Pipeline to call the ingestion Cloud Functions (§17, §21). This is **not** a third product-facing user role and does not conflict with [DECISIONS.md ADR-003](DECISIONS.md)'s MVP role scope (Player/Coach only) — it is a service credential, never surfaced as a user in the product, and never holds a `workspaces` entry of its own.

   - Provisioned as a dedicated Firebase Auth account (or accounts — one per organization is recommended for revocability, see §23) carrying custom claims: `{ ingestor: true, orgId: "<owning org>", teamIds: ["<authorized team ids>"] }`.
   - Every ingestion Cloud Function verifies `context.auth.token.ingestor === true` and that the payload's `teamId`/`orgId` falls within the token's authorized scope, before performing any write.
   - The exact provisioning process (how a new laptop deployment is issued credentials, how they are rotated/revoked) is operational tooling outside this document's scope — tracked as an open question.

| Principal | Auth Mechanism | Firestore Workspace Field | Can Call Ingestion Functions | Subject to Security Rules |
|---|---|---|---|---|
| Player | Firebase Auth (email/password or provider — see [ARCHITECTURE.md Open Questions](ARCHITECTURE.md#open-questions)) | `users/{uid}.workspaces.player` exists | No | Yes |
| Coach | Firebase Auth | `users/{uid}.workspaces.coach` exists | No | Yes |
| Laptop ingestion principal | Firebase Auth, custom claim `ingestor: true` | N/A — no `users/{uid}` document exists for this principal | Yes | N/A — never accesses Firestore directly; only calls Cloud Functions |

---

## 4. Player Ownership Model

A Player owns, and may read, exactly the resources that reference their own uid:

- Their own `users/{uid}` document (read/write limited fields — §1.5).
- Every `sessions/{sessionId}` where `playerId == self`.
- The corresponding `sessions/{sessionId}/live/current` for any of their own sessions.
- Every `alerts/{alertId}` and `reports/{reportId}` where `playerId == self`.
- Every `devices/{deviceId}` where `ownerId == self`.
- Their own `users/{uid}/notifications/*`.
- Their own `teams/{teamId}/members/{uid}` roster entries (read-only — coach-managed).

A Player **never** has read access to another player's session, alert, report, or device data, regardless of shared team membership. A Player cannot write any computed/safety field anywhere in the schema — every safety-relevant write originates from the laptop pipeline via Cloud Functions (§0).

---

## 5. Coach Ownership Model

A Coach's access is scoped to the team(s) they coach, established by `teams/{teamId}.coachIds` containing their uid (equivalently, `users/{uid}.workspaces.coach.teamIds` containing that `teamId`):

- Read access to every `users/{uid}` profile of a player on a team they coach (not full read access to all users).
- Read access to every `sessions/{sessionId}`, `sessions/{sessionId}/live/current`, `alerts/{alertId}`, and `reports/{reportId}` where `teamId` is a team they coach.
- Read access to `teams/{teamId}/liveMonitoring/*` for their team(s) — the primary data source for Live Team Monitoring.
- Write access to `teams/{teamId}` (name/roster-adjacent fields), `teams/{teamId}/members/*` (roster management), `devices/{deviceId}` assignment fields for devices assigned to their team.
- Write access to `alerts/{alertId}.acknowledged` (and its accompanying `acknowledgedBy`/`acknowledgedAt`) for alerts belonging to their team.

A Coach **never** has write access to any computed safety field (session summaries, live metrics, alert content, report content) — these originate exclusively from the laptop pipeline via Cloud Functions, matching the Player ownership model's same constraint. A Coach coaching multiple teams (`workspaces.coach.teamIds` length &gt; 1) has this same scoped access independently per team — access to Team A does not grant access to Team B.

---

## 6. Team Ownership Model

A team belongs to exactly one organization (`teams/{teamId}.orgId`) and has one or more coaches (`coachIds`) and zero or more player members (`teams/{teamId}/members` subcollection). Team-scoped data — sessions, alerts, reports, live monitoring, devices — is partitioned by `teamId`, which is the primary access-control boundary for coaches (§5) and the primary query boundary for the Coach Dashboard (§22). A session with `teamId == null` (an individual, non-team session) is visible only to the player themselves — no coach has implicit access to it, since it belongs to no team.

---

## 7. Device Ownership Model

A device (`devices/{deviceId}`) has two independent ownership axes, both optional and both settable by a coach:

- **`ownerId`** — the individual player the device is currently assigned to for personal use (a player's own Smart Pod, for example).
- **`assignedTeamId`** — the team the device is pooled under for team-level management, independent of whether it currently has an individual owner (e.g. a team's shared pool of EMG bands used session-to-session by whichever player is training).

A device with neither field set is an unassigned, pool-provisioned device, visible to administrative tooling only (out of scope of this document). Telemetry fields (`lastSeenAt`, `lastKnownBattery`, `status` transitions triggered by the heartbeat monitor) are Cloud-Function-written only, per §0's trust boundary — a coach can *assign* a device but cannot fabricate its connection state.

---

## 8. Live Session Data Model

Realized by `sessions/{sessionId}/live/current` (§1.9) and its fan-out, `teams/{teamId}/liveMonitoring/{playerId}` (§1.4).

The live tick is **not** raw sensor data. Raw signal never reaches Firestore (§0). It is a small, already-computed snapshot the laptop's ETL/Feature Extraction/ML/Risk Engine pipeline produces roughly once per second, containing exactly enough information to drive Live Team Monitoring and a player's own live session view:

`metrics` map fields: `currentLoad` (number, 0–100, normalized cumulative load index), `cumulativeImpacts` (number, running count), `riskScore` (number, 0.0–1.0, Risk Engine output), `riskLevel` (string enum: `low`/`moderate`/`high`/`critical`), `emgActivation` (number, 0–100, optional — present only when an EMG Thigh Band is part of `deviceIds` for this session).

Ordering is guaranteed by `sequenceNumber`, not by `serverReceivedAt` or Firestore write order — network delivery is not guaranteed strictly ordered (§19), so any consumer reconstructing a sequence of ticks (unlikely at the Flutter layer, since only the latest tick is retained, but relevant to the Cloud Function's own validation) must use `sequenceNumber` as the source of truth for "what happened when."

---

## 9. Session Summary Data Model

Realized by the `summaryMetrics` map on `sessions/{sessionId}` (§1.8), populated once at session completion:

| Field | Type | Description |
|---|---|---|
| `totalImpacts` | number | Total impact events recorded across the session. |
| `peakImpactForce` | number | Highest single-impact magnitude recorded (laptop-defined unit — see Open Questions). |
| `averageLoad` | number | Mean of the load index across the session. |
| `cumulativeLoadIndex` | number | Laptop-computed session-total load figure. |
| `muscleFatigueIndex` | number | Optional — present only if an EMG Thigh Band was worn. |
| `overallRiskScore` | number | 0.0–1.0, session-level Risk Engine output (distinct from any single live tick's `riskScore`). |
| `riskLevel` | string (enum) | `low` / `moderate` / `high` / `critical`. |
| `riskFactors` | array&lt;string&gt; | Laptop-supplied codes describing contributing factors (e.g. `"repeated_high_impact"`, `"asymmetric_fatigue"`) — a fixed vocabulary to be defined jointly with the ML pipeline, not invented by Firebase. |

The session summary is the durable, permanent safety record for that session (§20), distinct from the ephemeral live tick (§8), which is overwritten in place and not itself retained once the session completes.

---

## 10. Historical Player Data

A player's history is not a separate collection — it is realized as a query over `sessions` filtered by `playerId`, ordered by `startedAt` descending (§14, §22), giving the full session-by-session record. For fast profile-screen reads that do not require scanning the full session history, `users/{uid}.careerStats` (§1.5) maintains a small, Cloud-Function-updated rollup (`totalSessions`, `totalImpacts`, `lastSessionAt`, `averageRiskScore30d`), recomputed incrementally whenever a session completes (`onSessionCompleted` trigger, §17). This is pure arithmetic aggregation of already-computed session summaries — not a new analysis of raw data — and is therefore a permitted Cloud Function responsibility under §0's constraint.

---

## 11. Analytics Data Model

Two distinct meanings of "analytics" apply to Vikzar, and they must not be conflated:

1. **Product usage analytics** (screen views, funnel completion) — covered by Firebase Analytics per [ARCHITECTURE.md §18](ARCHITECTURE.md#18-analytics-strategy). Not part of this document's schema; strictly separated from health-adjacent data per that section.
2. **Team/organization performance analytics** (e.g. a coach viewing risk trends across their squad over time) — the concern of this section.

At MVP, team-level analytics views are computed directly via Firestore aggregation queries (`count()`, `sum()`, `average()`) against the `sessions` collection, filtered by `teamId` and a date range on `startedAt` — no dedicated denormalized analytics collection is built for MVP. This is a deliberate proportionality decision (Principle 7): a dedicated rollup collection (e.g. `teams/{teamId}/analyticsRollups/{periodId}`) is a reasonable future optimization if query cost or dashboard latency becomes a problem at higher session volumes, but building it now would be speculative — no such need is demonstrated yet. If introduced later, it would be populated by the same class of arithmetic-aggregation Cloud Function already established for `careerStats` (§10) and `weekly_summary` reports (§13), not a new architectural pattern.

---

## 12. Alert Model

Realized by `alerts/{alertId}` (§1.10). An alert is a discrete, timestamped, safety-relevant event — distinct from a report (§13) in that it is raised at the moment something crosses a threshold, is designed to be acted on quickly (acknowledged by a coach), and does not aggregate a full session's data. Two origins are modeled explicitly via the `source` field:

- `laptop_risk_engine` — raised mid-session or at session end when the Risk Engine detects a genuinely concerning pattern (e.g. `high_impact`, `risk_threshold_exceeded`, `abnormal_fatigue_asymmetry`). This is computed entirely by the laptop; the Cloud Function that writes it (`submitAlert`, §17) performs no analysis of its own.
- `cloud_function_device_health` — raised by the `deviceHeartbeatMonitor` scheduled function (§17) when a device that should be actively reporting during a live session goes silent past a timeout threshold (`device_disconnected`), or when the laptop reports a low-battery reading (`low_battery`). This is a timeout/threshold check on already-known values, not sensor analysis, and is therefore permitted under §0's constraint.

Every alert carries `metricsSnapshot`, a small map of the specific values that triggered it, so a coach reviewing an alert later has the supporting context without needing to separately query the session.

---

## 13. Report Model

Realized by `reports/{reportId}` (§1.11). A report is comprehensive and often exportable, in contrast to an alert's brevity:

- **`session_report`** — the full analytical write-up of a single completed session, submitted by the Laptop ML Pipeline via `submitReport` (§17) alongside `completeSession`. References `sessionId`.
- **`weekly_summary`** — a periodic rollup across a player's or team's sessions within `periodStart`–`periodEnd`, generated server-side by the scheduled `weeklySummaryAggregator` function (§17) purely from already-stored session summaries — arithmetic aggregation only, never new inference.
- **`player_profile_report`** — an on-demand or periodic rollup of a single player's history, also `cloud_function_aggregation`-generated on the same basis.

`summary` mirrors the report's key figures directly on the Firestore document for fast display; `storagePath`, if present, references a generated PDF or export in Firebase Storage (§16) for cases where a coach wants to download or share the full report.

---

## 14. Firestore Indexes

Single-field indexes are automatic in Firestore and are not listed. The following composite indexes are required to support the query patterns in §22:

| Collection | Fields (order) | Supports |
|---|---|---|
| `sessions` | `playerId` ASC, `startedAt` DESC | Player session history. |
| `sessions` | `teamId` ASC, `status` ASC, `startedAt` DESC | Coach dashboard: live/completed sessions for a team, most recent first. |
| `sessions` | `teamId` ASC, `startedAt` DESC | Coach: full team session history. |
| `alerts` | `teamId` ASC, `acknowledged` ASC, `triggeredAt` DESC | Coach alert inbox, unacknowledged first. |
| `alerts` | `playerId` ASC, `triggeredAt` DESC | Player's own alert history. |
| `reports` | `teamId` ASC, `type` ASC, `generatedAt` DESC | Coach: reports by type for a team. |
| `reports` | `playerId` ASC, `generatedAt` DESC | Player's own report history. |
| `devices` | `assignedTeamId` ASC, `status` ASC | Coach device management view. |
| `teams/{teamId}/members` (collection, per-parent) | `status` ASC, `displayName` ASC | Active roster, alphabetical. |

`teams/{teamId}/liveMonitoring` and `users/{uid}/notifications` are read as full small collections (typically single-digit to low-double-digit document counts per team/user) via realtime listeners and do not require composite indexes at MVP scale.

---

## 15. Security Rules Strategy

The governing pattern, established in [ARCHITECTURE.md §19](ARCHITECTURE.md#19-security-architecture) and made concrete here: **Security Rules govern the Flutter Application's direct access only.** Cloud Functions run with Firebase Admin privileges and are never subject to Security Rules — this is why every computed, safety-relevant write in this schema is routed through a Cloud Function (§0) rather than written by any client, laptop included.

| Collection | Client Read | Client Write |
|---|---|---|
| `organizations/{orgId}` | Members of any team under this org | Denied — administrative provisioning only |
| `teams/{teamId}` | Coach or member of this team | Coach of this team, `name`/`ageGroup` fields only |
| `teams/{teamId}/members/{uid}` | Coach or member of this team | Coach of this team |
| `teams/{teamId}/liveMonitoring/*` | Coach of this team; player may read their own entry | Denied — Cloud Function only |
| `users/{uid}` | Self; coach of a team this user belongs to | Self, `displayName`/`avatarUrl`/`fcmTokens` only |
| `users/{uid}/notifications/*` | Self only | Self, `read` field only |
| `devices/{deviceId}` | Owner; coach of `assignedTeamId` | Coach of `assignedTeamId`, assignment fields only |
| `sessions/{sessionId}` | `playerId == self`; coach of `teamId` | Denied — Cloud Function only |
| `sessions/{sessionId}/live/current` | `playerId == self`; coach of `teamId` | Denied — Cloud Function only |
| `alerts/{alertId}` | `playerId == self`; coach of `teamId` | Coach of `teamId`, `acknowledged`/`acknowledgedBy`/`acknowledgedAt` only |
| `reports/{reportId}` | `playerId == self`; coach of `teamId` | Denied — Cloud Function only |

Role and team-membership checks in Rules read the requester's own `users/{request.auth.uid}` document (per ADR-013 — role is not carried in the Auth token) and the relevant `teams/{teamId}.coachIds` array. Every rule of the form "coach of `teamId`" is implemented as: `request.auth.uid in get(/databases/$(database)/documents/teams/$(teamId)).data.coachIds`.

---

## 16. Cloud Storage Folder Hierarchy

Namespaced by organization and team from the root, so per-org/per-team security rules and bulk retention/deletion operations (§20) can operate on a path prefix rather than enumerating individual files:

```
/organizations/{orgId}/teams/{teamId}/players/{playerId}/sessions/{sessionId}/raw/{fileName}
/organizations/{orgId}/teams/{teamId}/players/{playerId}/sessions/{sessionId}/reports/{reportFileName}
/users/{uid}/avatar/{fileName}
```

- **`.../sessions/{sessionId}/raw/{fileName}`** — the full-resolution archive the laptop optionally uploads at session completion (§21), referenced by `sessions/{sessionId}.rawDataStoragePath`. Exact file format (binary/JSON/CSV) is deferred, per [ARCHITECTURE.md §11](ARCHITECTURE.md#11-firebase-storage-usage), to Roadmap Phase 6.
- **`.../sessions/{sessionId}/reports/{reportFileName}`** — a generated PDF/export for a `session_report`, referenced by `reports/{reportId}.storagePath`.
- **`/users/{uid}/avatar/{fileName}`** — profile images, outside the org/team hierarchy since a user's identity is independent of any one team.

Storage Security Rules mirror the Firestore access model in §15: a path under `organizations/{orgId}/teams/{teamId}/players/{playerId}/...` is readable by that player or a coach of that team, and writable only by Cloud Functions (never a direct client or laptop upload) for `raw` and `reports` subpaths; `/users/{uid}/avatar/` is writable by that user directly, consistent with `users/{uid}.avatarUrl` being a client-writable field.

---

## 17. Cloud Function Responsibilities

Extends [ARCHITECTURE.md §12](ARCHITECTURE.md#12-cloud-functions-responsibilities)'s four general categories with the concrete functions this backend requires. Every function below is either (a) an HTTPS Callable function invoked by the laptop's ingestion principal, (b) a Firestore-triggered function reacting to a write, or (c) a scheduled function.

| Function | Trigger | Responsibility |
|---|---|---|
| `startSession` | Callable (laptop) | Validates the ingestion principal's scope; creates `sessions/{sessionId}` with `status: "live"`. |
| `ingestLiveTick` | Callable (laptop) | Validates payload and scope; upserts `sessions/{sessionId}/live/current`. |
| `completeSession` | Callable (laptop) | Validates payload; finalizes `sessions/{sessionId}` with `summaryMetrics`, `status`, `endedAt`, `durationSeconds`, `dataCompleteness`, `rawDataStoragePath`. |
| `submitAlert` | Callable (laptop) | Validates payload; creates `alerts/{alertId}`. |
| `submitReport` | Callable (laptop) | Validates payload; creates `reports/{reportId}` with `type: "session_report"`. |
| `fanOutLiveMonitoring` | Firestore trigger on `sessions/{sessionId}/live/current` write | Upserts the corresponding `teams/{teamId}/liveMonitoring/{playerId}` document. |
| `onSessionCompleted` | Firestore trigger on `sessions/{sessionId}` status transition to `completed`/`completed_with_gaps`/`aborted` | Updates `users/{uid}.careerStats` (arithmetic aggregation only); removes or marks inactive the corresponding `liveMonitoring` entry; triggers a session-summary notification (§18). |
| `onAlertCreated` | Firestore trigger on `alerts/{alertId}` creation | Dispatches FCM push and writes the corresponding `users/{uid}/notifications` record(s) — to the player and to each coach of `teamId`. |
| `onReportCreated` | Firestore trigger on `reports/{reportId}` creation | Dispatches FCM push and writes the corresponding notification record(s). |
| `deviceHeartbeatMonitor` | Scheduled (e.g. every 30 seconds) | Checks `devices.lastSeenAt` for devices referenced by any currently-`live` session; raises a `device_disconnected` alert via the same path as `submitAlert` if a device has gone silent past a defined timeout. Timeout-checking only, not signal analysis. |
| `weeklySummaryAggregator` | Scheduled (weekly) | Aggregates existing `sessions.summaryMetrics` for the prior period into `reports` documents of type `weekly_summary`. Arithmetic aggregation of already-computed values only. |

Every Callable function in this table enforces the authorization check described in §0 and §3 before performing any write: the calling principal must carry `ingestor: true` and the payload's `teamId`/`orgId` must be within that principal's authorized scope.

---

## 18. Notification Triggers

| Event | Recipients | Notification `type` |
|---|---|---|
| `alerts/{alertId}` created with `severity: "critical"` or `"warning"` | The player (`playerId`); every coach in `teams/{teamId}.coachIds` | `alert` |
| `sessions/{sessionId}` completed | The player; coaches of `teamId` also notified if `summaryMetrics.riskLevel` is `high` or `critical` | `session_summary` |
| `reports/{reportId}` created, `type: "session_report"` or `"player_profile_report"` | The player; coaches of `teamId` | `report_ready` |
| `reports/{reportId}` created, `type: "weekly_summary"` | Coaches of `teamId` | `report_ready` |
| `alerts/{alertId}` created with `type: "device_disconnected"` during a live session | Coaches of `teamId` | `alert` |
| `alerts/{alertId}` created with `type: "low_battery"` | The device's `ownerId`; coaches of `assignedTeamId` | `alert` |
| Coach added to a team (`teams/{teamId}.coachIds` updated) | The newly added coach | `team_invite` |

Every row is dispatched by `onAlertCreated`, `onSessionCompleted`, or `onReportCreated` (§17) — no notification is ever triggered directly by a client write, consistent with §0's trust boundary.

---

## 19. Offline Synchronization Strategy

Two distinct offline concerns exist in this system, addressed separately:

**The Flutter Application's offline behavior** is unchanged from [ARCHITECTURE.md §15](ARCHITECTURE.md#15-offline-strategy): Firestore's built-in offline persistence handles structured-data reads and the small set of permitted client writes (profile edits, alert acknowledgement, notification read-state) while the app is offline, syncing automatically on reconnect. This document does not add to that.

**The Laptop's offline resilience** is new to this document, since the laptop — not the Flutter app — is now the system's data-origination point: the laptop buffers unsent `ingestLiveTick` calls to a local on-disk queue if network connectivity drops mid-session, and retries with exponential backoff on reconnect, submitting buffered ticks in their original `sequenceNumber` order. Because `sequenceNumber` (not `serverReceivedAt`) is the authoritative ordering signal (§8), a burst of buffered ticks arriving late does not corrupt the session's reconstructed timeline. If a gap in `sequenceNumber` is unrecoverable (e.g. the laptop process itself lost data before it could buffer it), the session's `dataCompleteness` field (§1.8) reflects that at `completeSession` time rather than silently reporting a complete session — this is a safety-relevant honesty requirement (Principle 2), not a cosmetic one: a coach or clinician reviewing a session must be able to tell whether a "low risk" reading reflects genuinely low risk or a gap in monitoring.

---

## 20. Data Retention Strategy

| Data | Retention | Reasoning |
|---|---|---|
| `sessions/{sessionId}/live/current` | Not retained historically — overwritten in place each tick, effectively ephemeral. | It exists only to drive live views; the durable record is the session summary. |
| `sessions/{sessionId}` (summary) | Retained indefinitely. | This is the core historical safety record (§9, §10) — the product's central value to players, coaches, and (in future) clinicians. |
| `alerts/{alertId}` | Retained indefinitely. | Functions as a safety audit trail; acknowledgement metadata (who, when) has ongoing accountability value. |
| `reports/{reportId}` | Retained indefinitely. | Same reasoning as session summaries. |
| Raw archives in Firebase Storage (`.../sessions/{sessionId}/raw/`) | Proposed default: retained for 24 months from `sessions.endedAt`, then deleted (not the derived summary, which is unaffected). | Raw full-resolution data is large and primarily useful for ML pipeline reprocessing/auditing in the near term; the derived, permanent safety record does not depend on the raw file surviving indefinitely. **This window is a proposed default, not a final decision** — it must be confirmed against whatever regulatory requirement is identified (see [ARCHITECTURE.md Open Questions](ARCHITECTURE.md#open-questions), item 2) before production. |
| `users/{uid}/notifications/*` | Proposed default: pruned after 90 days via scheduled cleanup. | Ephemeral UX record, not the safety record itself — the underlying alert/report/session it references is retained independently. |

No retention window in this section should be treated as final. They are proposed, reasoned defaults intended to make this specification concrete and implementable now, explicitly flagged for confirmation against compliance requirements before Roadmap Phase 13 (Production Readiness), consistent with how [ARCHITECTURE.md](ARCHITECTURE.md#assumptions) already flags this open item.

---

## 21. Upload Contract for the Laptop

This is the exact, binding contract between the Laptop ETL/ML Pipeline and Firebase, implemented as five HTTPS Callable Cloud Functions (§17). All payloads are JSON. All calls are authenticated with the ingestion principal's Firebase Auth ID token (§3).

### 21.1 Identifier Conventions

- **`sessionId`** — a UUID v4 string, generated by the laptop at the start of a session and reused in every subsequent call for that session (`ingestLiveTick`, `completeSession`, `submitAlert`, `submitReport`). Example: `"a3f1c9de-4b2e-4f11-9c7a-1d6e2f0b8a44"`.
- **`playerId`** — the player's Firebase Auth uid, exactly as issued by Firebase Authentication (a 28-character alphanumeric string). The laptop obtains this at session setup (e.g. the operator selects the player from the roster before starting capture) — how that lookup happens on the laptop's own UI is outside this document's scope.
- **`deviceId`** — a stable hardware identifier, human-readable-prefixed: `"SP-"` followed by 8 uppercase hex characters for a Smart Pod (e.g. `"SP-7F3A21C9"`), `"EB-"` followed by 8 uppercase hex characters for an EMG Thigh Band (e.g. `"EB-4B1109F2"`). Uniqueness is enforced at hardware provisioning time, out of scope of this document.

### 21.2 Timestamp Strategy

Two distinct timestamp concepts are used throughout, and must not be conflated:

- **Laptop-reported timestamps** (`tickTimestamp`, `startedAt`, `endedAt`, `triggeredAt`, `generatedAt`) — the laptop's own clock, submitted as ISO 8601 strings with millisecond precision and an explicit UTC offset (e.g. `"2026-07-19T14:32:07.412Z"`). These represent when the event actually happened, and are converted to Firestore `Timestamp` values by the receiving Cloud Function.
- **Server-received timestamps** (`serverReceivedAt`, every `createdAt`/`updatedAt`) — set exclusively by the Cloud Function using Firestore's server timestamp mechanism at the moment the write is processed. These represent when Firebase learned about the event, and exist to detect delivery latency (§19) — they are never used to reconstruct event ordering, which is `sequenceNumber`'s job (§8).

### 21.3 `startSession` — Called Once, at Session Start

**Required fields:** `sessionId`, `playerId`, `type` (`"training"` | `"match"`), `deviceIds` (array, at least one), `startedAt`.
**Optional fields:** `teamId` (omit for an individual session), `orgId`.

```json
{
  "sessionId": "a3f1c9de-4b2e-4f11-9c7a-1d6e2f0b8a44",
  "playerId": "hU3kP9mZ2LQvT8xR1nY6wA0bC7dE",
  "teamId": "team_riverside_u18",
  "orgId": "org_riverside_fc",
  "type": "training",
  "deviceIds": ["SP-7F3A21C9", "EB-4B1109F2"],
  "startedAt": "2026-07-19T14:30:00.000Z"
}
```

### 21.4 `ingestLiveTick` — Called Approximately Once Per Second, for the Duration of the Session

**Required fields:** `sessionId`, `playerId`, `sequenceNumber`, `tickTimestamp`, `connectionStatus`, `metrics.currentLoad`, `metrics.cumulativeImpacts`, `metrics.riskScore`, `metrics.riskLevel`.
**Optional fields:** `teamId`, `metrics.emgActivation` (present only if an EMG Thigh Band is active for this session), `deviceBattery`.

```json
{
  "sessionId": "a3f1c9de-4b2e-4f11-9c7a-1d6e2f0b8a44",
  "playerId": "hU3kP9mZ2LQvT8xR1nY6wA0bC7dE",
  "teamId": "team_riverside_u18",
  "sequenceNumber": 412,
  "tickTimestamp": "2026-07-19T14:36:52.108Z",
  "connectionStatus": "connected",
  "metrics": {
    "currentLoad": 47.2,
    "cumulativeImpacts": 63,
    "riskScore": 0.18,
    "riskLevel": "low",
    "emgActivation": 34.6
  },
  "deviceBattery": {
    "SP-7F3A21C9": 81,
    "EB-4B1109F2": 74
  }
}
```

### 21.5 `completeSession` — Called Once, at Session End

**Required fields:** `sessionId`, `endedAt`, `durationSeconds`, `status`, `summaryMetrics` (all sub-fields per §9 except `muscleFatigueIndex`), `dataCompleteness`, `pipelineVersion`.
**Optional fields:** `summaryMetrics.muscleFatigueIndex` (present only if an EMG band was worn), `rawDataStoragePath` (present only if a raw archive was uploaded to Storage).

```json
{
  "sessionId": "a3f1c9de-4b2e-4f11-9c7a-1d6e2f0b8a44",
  "endedAt": "2026-07-19T16:02:11.900Z",
  "durationSeconds": 5531,
  "status": "completed",
  "dataCompleteness": 0.997,
  "pipelineVersion": "etl-2.3.1+ml-1.7.0+risk-1.2.0",
  "rawDataStoragePath": "organizations/org_riverside_fc/teams/team_riverside_u18/players/hU3kP9mZ2LQvT8xR1nY6wA0bC7dE/sessions/a3f1c9de-4b2e-4f11-9c7a-1d6e2f0b8a44/raw/capture.bin",
  "summaryMetrics": {
    "totalImpacts": 288,
    "peakImpactForce": 62.4,
    "averageLoad": 41.9,
    "cumulativeLoadIndex": 2317.6,
    "muscleFatigueIndex": 58.3,
    "overallRiskScore": 0.24,
    "riskLevel": "low",
    "riskFactors": []
  }
}
```

### 21.6 `submitAlert` — Called Whenever the Risk Engine Crosses a Threshold (Zero or More Times Per Session, Asynchronous to the Tick Cadence)

**Required fields:** `sessionId`, `playerId`, `severity`, `type`, `message`, `triggeredAt`.
**Optional fields:** `teamId`, `metricsSnapshot`.

```json
{
  "sessionId": "a3f1c9de-4b2e-4f11-9c7a-1d6e2f0b8a44",
  "playerId": "hU3kP9mZ2LQvT8xR1nY6wA0bC7dE",
  "teamId": "team_riverside_u18",
  "severity": "warning",
  "type": "high_impact",
  "message": "A high-magnitude impact was recorded and exceeds this player's typical range.",
  "triggeredAt": "2026-07-19T15:12:44.331Z",
  "metricsSnapshot": {
    "impactForce": 58.9,
    "riskScoreAtEvent": 0.41
  }
}
```

### 21.7 `submitReport` — Called Once, Alongside `completeSession`, for the Session's Full Report

**Required fields:** `sessionId`, `playerId`, `generatedAt`, `summary`.
**Optional fields:** `teamId`, `storagePath` (if a PDF export was also generated and uploaded).

```json
{
  "sessionId": "a3f1c9de-4b2e-4f11-9c7a-1d6e2f0b8a44",
  "playerId": "hU3kP9mZ2LQvT8xR1nY6wA0bC7dE",
  "teamId": "team_riverside_u18",
  "generatedAt": "2026-07-19T16:03:05.000Z",
  "summary": {
    "overallRiskScore": 0.24,
    "riskLevel": "low",
    "totalImpacts": 288,
    "notableFindings": []
  }
}
```

---

## 22. Flutter Read Contract

For every MVP feature area (per [SPECIFICATION.md §7](SPECIFICATION.md#7-mvp-feature-set)), the exact collection(s), document(s)/query pattern, and fields read.

| Screen / Feature Area | Collection(s) | Document / Query | Key Fields Read |
|---|---|---|---|
| Sign-in / Authentication | `users` | `users/{uid}` (self, on `authStateChanges`) | `workspaces`, `defaultWorkspace`, `displayName`, `status` |
| Player Home / Dashboard | `sessions`, `users` | `sessions` where `playerId == self`, order by `startedAt` desc, limit 10; `users/{self}` | `sessions.summaryMetrics`, `sessions.status`, `sessions.startedAt`; `users.careerStats` |
| Player — Live Session View (own) | `sessions`, `sessions/{id}/live` | `sessions/{sessionId}` (self); `sessions/{sessionId}/live/current` (realtime listener) | `sessions.status`; `live.metrics.*`, `live.connectionStatus` |
| Coach — Live Team Monitoring | `teams/{teamId}/liveMonitoring` | Full subcollection (realtime listener), scoped to the coach's team | `displayName`, `connectionStatus`, `currentRiskScore`, `currentRiskLevel`, `currentLoad`, `cumulativeImpacts`, `deviceBattery` |
| Session History (Player) | `sessions` | where `playerId == self`, order by `startedAt` desc | `type`, `startedAt`, `durationSeconds`, `summaryMetrics.riskLevel`, `status` |
| Session History (Coach) | `sessions` | where `teamId == coachTeamId`, order by `startedAt` desc (optionally filtered further by `playerId`) | Same as above, plus `playerId` for attribution |
| Session Detail | `sessions`, `alerts`, `reports` | `sessions/{sessionId}`; `alerts` where `sessionId == X`; `reports` where `sessionId == X` | `sessions.summaryMetrics`, `sessions.dataCompleteness`; `alerts.*`; `reports.summary`, `reports.storagePath` |
| Player Profile | `users`, `devices` | `users/{uid}`; `devices` where `ownerId == uid` | `users.displayName`, `users.avatarUrl`, `users.careerStats`, `users.dateOfBirth`; `devices.type`, `devices.status`, `devices.lastKnownBattery` |
| Team Management (Coach) | `teams`, `teams/{id}/members` | `teams/{teamId}`; `teams/{teamId}/members` ordered by `displayName` | `teams.name`, `teams.ageGroup`; `members.displayName`, `members.jerseyNumber`, `members.position`, `members.status` |
| Device Management | `devices` | where `ownerId == self` OR where `assignedTeamId == coachTeamId` | `type`, `serialNumber`, `firmwareVersion`, `status`, `lastSeenAt`, `lastKnownBattery` |
| Notification Center | `users/{uid}/notifications` | Full subcollection, order by `createdAt` desc | `type`, `title`, `body`, `read`, `createdAt` |
| Reports | `reports` | where `teamId == coachTeamId` OR `playerId == self`, order by `generatedAt` desc | `type`, `generatedAt`, `summary`, `storagePath`, `status` |
| Alert Inbox (Coach) | `alerts` | where `teamId == coachTeamId`, order by `triggeredAt` desc (optionally filtered by `acknowledged == false`) | `severity`, `type`, `message`, `triggeredAt`, `acknowledged` |

No screen listed above reads raw sensor data or performs any computation on read — every field surfaced to the Flutter Application is already-computed, matching §0's constraint end-to-end from ingestion to display.

**Note:** Hardware pairing and streaming are performed entirely by the Laptop ETL Pipeline, not the Flutter Application — the table above accordingly has no "BLE pairing screen" reading device connection state from a live BLE stack. [SPECIFICATION.md §7.2](SPECIFICATION.md#7-mvp-feature-set) and [ARCHITECTURE.md §7](ARCHITECTURE.md#7-ble-architecture) have been updated to confirm this (Phase 1.6, [DECISIONS.md ADR-030](DECISIONS.md#adr-030-laptop-centric-ble-etl-and-ml-pipeline-for-mvp)) — this is no longer a discrepancy between documents, and direct Flutter-side BLE is documented only as a future capability (see [ARCHITECTURE.md's Future Evolution section](ARCHITECTURE.md#future-evolution)).

---

## 23. Future Scalability

The schema in §1 was designed specifically so the following can be added later **without a redesign**:

- **Multiple organizations of different types** (`club`, `academy`, `university`, `professional_team`) — already modeled via `organizations.type`; no schema change needed to onboard a new organization type, only a new enum value.
- **Multiple countries** — `organizations.country` and denormalized `teams.country`/`users.country` already support filtering, reporting, and (in future) localization or region-specific compliance handling per organization, without restructuring any collection.
- **A coach managing multiple teams, or multiple organizations** — already modeled: `users.workspaces.coach.teamIds` is an array, and access is evaluated independently per team (§5, §6) rather than assuming one coach-to-one-team.
- **An academy with many age-group teams under one organization** — already modeled: any number of `teams` documents may reference the same `orgId`.
- **Cross-organization or cross-country reporting** (a future need, not MVP scope) — supported by the denormalized `orgId` field already present on `sessions`, `alerts`, and `reports`, enabling a future composite index (`orgId` + date range) without adding a new field to any existing document.
- **A device pool shared across a larger organization rather than one team** — the two-axis ownership model (§7) already separates individual assignment from team pooling; extending it to organization-level pooling is an additive query change (`orgId` instead of `assignedTeamId`), not a schema change, since `devices` documents could add an `assignedOrgId` field later without touching existing documents.
- **New alert/report types or risk factors** — all three (`alerts.type`, `reports.type`, `summaryMetrics.riskFactors`) are string/enum values, not baked into document structure; adding a new type is a vocabulary addition, not a migration.

What this document deliberately does **not** build now, consistent with [ARCHITECTURE.md §23](ARCHITECTURE.md#23-future-scalability-strategy)'s anti-overengineering stance: a dedicated analytics rollup collection (§11), organization-level device pooling fields (§7), or any multi-region data residency infrastructure. Each has a clear, low-cost, additive path when a real requirement demonstrates the need.

---

## 24. Example JSON

Realistic, complete example documents for every collection defined in §1. Field values are illustrative, not prescriptive of any real player, team, or organization.

### `organizations/org_riverside_fc`

```json
{
  "orgId": "org_riverside_fc",
  "name": "Riverside Football Club",
  "type": "club",
  "country": "GB",
  "region": "Greater London",
  "timezone": "Europe/London",
  "status": "active",
  "createdAt": "2026-01-10T09:00:00Z",
  "updatedAt": "2026-01-10T09:00:00Z"
}
```

### `teams/team_riverside_u18`

```json
{
  "teamId": "team_riverside_u18",
  "orgId": "org_riverside_fc",
  "name": "Riverside FC U18",
  "ageGroup": "U18",
  "coachIds": ["cO4hN2pR9sT6uV1wX8yZ3aB5"],
  "country": "GB",
  "status": "active",
  "createdAt": "2026-01-10T09:05:00Z",
  "updatedAt": "2026-06-02T11:20:00Z"
}
```

### `teams/team_riverside_u18/members/hU3kP9mZ2LQvT8xR1nY6wA0bC7dE`

```json
{
  "uid": "hU3kP9mZ2LQvT8xR1nY6wA0bC7dE",
  "displayName": "Jordan Blake",
  "avatarUrl": "https://firebasestorage.googleapis.com/v0/b/vikzar/o/users%2FhU3kP9mZ2LQvT8xR1nY6wA0bC7dE%2Favatar%2Fphoto.jpg",
  "jerseyNumber": 14,
  "position": "Midfielder",
  "role": "player",
  "status": "active",
  "joinedAt": "2026-02-01T08:00:00Z"
}
```

### `teams/team_riverside_u18/liveMonitoring/hU3kP9mZ2LQvT8xR1nY6wA0bC7dE`

```json
{
  "playerId": "hU3kP9mZ2LQvT8xR1nY6wA0bC7dE",
  "sessionId": "a3f1c9de-4b2e-4f11-9c7a-1d6e2f0b8a44",
  "displayName": "Jordan Blake",
  "connectionStatus": "connected",
  "lastTickAt": "2026-07-19T14:36:52.108Z",
  "currentRiskScore": 0.18,
  "currentRiskLevel": "low",
  "currentLoad": 47.2,
  "cumulativeImpacts": 63,
  "deviceBattery": {
    "SP-7F3A21C9": 81,
    "EB-4B1109F2": 74
  },
  "updatedAt": "2026-07-19T14:36:52.400Z"
}
```

### `users/hU3kP9mZ2LQvT8xR1nY6wA0bC7dE`

```json
{
  "uid": "hU3kP9mZ2LQvT8xR1nY6wA0bC7dE",
  "email": "jordan.blake@example.com",
  "displayName": "Jordan Blake",
  "workspaces": {
    "player": {
      "teamId": "team_riverside_u18"
    }
  },
  "defaultWorkspace": "player",
  "dateOfBirth": "2008-03-22",
  "country": "GB",
  "primaryOrgId": "org_riverside_fc",
  "avatarUrl": "https://firebasestorage.googleapis.com/v0/b/vikzar/o/users%2FhU3kP9mZ2LQvT8xR1nY6wA0bC7dE%2Favatar%2Fphoto.jpg",
  "careerStats": {
    "totalSessions": 47,
    "totalImpacts": 11284,
    "lastSessionAt": "2026-07-19T16:02:11.900Z",
    "averageRiskScore30d": 0.21
  },
  "fcmTokens": ["dGVzdC1mY20tdG9rZW4tZXhhbXBsZQ=="],
  "status": "active",
  "createdAt": "2026-02-01T08:00:00Z",
  "updatedAt": "2026-07-19T16:02:12.000Z"
}
```

### `users/hU3kP9mZ2LQvT8xR1nY6wA0bC7dE/notifications/n_8f2a1c`

```json
{
  "notificationId": "n_8f2a1c",
  "type": "session_summary",
  "title": "Session complete",
  "body": "Your training session on 19 Jul has been analyzed. Overall risk: low.",
  "relatedSessionId": "a3f1c9de-4b2e-4f11-9c7a-1d6e2f0b8a44",
  "read": false,
  "createdAt": "2026-07-19T16:03:10.000Z"
}
```

### `devices/SP-7F3A21C9`

```json
{
  "deviceId": "SP-7F3A21C9",
  "type": "smart_pod",
  "serialNumber": "VKZ-SP-2026-004417",
  "ownerId": "hU3kP9mZ2LQvT8xR1nY6wA0bC7dE",
  "assignedTeamId": "team_riverside_u18",
  "firmwareVersion": "1.4.2",
  "lastSeenAt": "2026-07-19T16:02:00.000Z",
  "lastKnownBattery": 79,
  "status": "active",
  "createdAt": "2026-01-15T10:00:00Z",
  "updatedAt": "2026-07-19T16:02:00.000Z"
}
```

### `sessions/a3f1c9de-4b2e-4f11-9c7a-1d6e2f0b8a44`

```json
{
  "sessionId": "a3f1c9de-4b2e-4f11-9c7a-1d6e2f0b8a44",
  "playerId": "hU3kP9mZ2LQvT8xR1nY6wA0bC7dE",
  "teamId": "team_riverside_u18",
  "orgId": "org_riverside_fc",
  "type": "training",
  "deviceIds": ["SP-7F3A21C9", "EB-4B1109F2"],
  "status": "completed",
  "startedAt": "2026-07-19T14:30:00.000Z",
  "endedAt": "2026-07-19T16:02:11.900Z",
  "durationSeconds": 5531,
  "summaryMetrics": {
    "totalImpacts": 288,
    "peakImpactForce": 62.4,
    "averageLoad": 41.9,
    "cumulativeLoadIndex": 2317.6,
    "muscleFatigueIndex": 58.3,
    "overallRiskScore": 0.24,
    "riskLevel": "low",
    "riskFactors": []
  },
  "dataCompleteness": 0.997,
  "rawDataStoragePath": "organizations/org_riverside_fc/teams/team_riverside_u18/players/hU3kP9mZ2LQvT8xR1nY6wA0bC7dE/sessions/a3f1c9de-4b2e-4f11-9c7a-1d6e2f0b8a44/raw/capture.bin",
  "pipelineVersion": "etl-2.3.1+ml-1.7.0+risk-1.2.0",
  "generatedBy": "laptop_ingestion_pipeline",
  "createdAt": "2026-07-19T14:30:00.500Z",
  "updatedAt": "2026-07-19T16:02:12.100Z"
}
```

### `sessions/a3f1c9de-4b2e-4f11-9c7a-1d6e2f0b8a44/live/current`

```json
{
  "sessionId": "a3f1c9de-4b2e-4f11-9c7a-1d6e2f0b8a44",
  "playerId": "hU3kP9mZ2LQvT8xR1nY6wA0bC7dE",
  "teamId": "team_riverside_u18",
  "sequenceNumber": 412,
  "tickTimestamp": "2026-07-19T14:36:52.108Z",
  "serverReceivedAt": "2026-07-19T14:36:52.391Z",
  "connectionStatus": "connected",
  "metrics": {
    "currentLoad": 47.2,
    "cumulativeImpacts": 63,
    "riskScore": 0.18,
    "riskLevel": "low",
    "emgActivation": 34.6
  },
  "deviceBattery": {
    "SP-7F3A21C9": 81,
    "EB-4B1109F2": 74
  }
}
```

### `alerts/al_c91f4e`

```json
{
  "alertId": "al_c91f4e",
  "sessionId": "a3f1c9de-4b2e-4f11-9c7a-1d6e2f0b8a44",
  "playerId": "hU3kP9mZ2LQvT8xR1nY6wA0bC7dE",
  "teamId": "team_riverside_u18",
  "orgId": "org_riverside_fc",
  "severity": "warning",
  "type": "high_impact",
  "message": "A high-magnitude impact was recorded and exceeds this player's typical range.",
  "metricsSnapshot": {
    "impactForce": 58.9,
    "riskScoreAtEvent": 0.41
  },
  "source": "laptop_risk_engine",
  "triggeredAt": "2026-07-19T15:12:44.331Z",
  "acknowledged": true,
  "acknowledgedBy": "cO4hN2pR9sT6uV1wX8yZ3aB5",
  "acknowledgedAt": "2026-07-19T15:14:02.000Z"
}
```

### `reports/rp_5b7d21`

```json
{
  "reportId": "rp_5b7d21",
  "type": "session_report",
  "playerId": "hU3kP9mZ2LQvT8xR1nY6wA0bC7dE",
  "teamId": "team_riverside_u18",
  "orgId": "org_riverside_fc",
  "sessionId": "a3f1c9de-4b2e-4f11-9c7a-1d6e2f0b8a44",
  "generatedAt": "2026-07-19T16:03:05.000Z",
  "generatedBy": "laptop_ml_pipeline",
  "summary": {
    "overallRiskScore": 0.24,
    "riskLevel": "low",
    "totalImpacts": 288,
    "notableFindings": []
  },
  "storagePath": "organizations/org_riverside_fc/teams/team_riverside_u18/players/hU3kP9mZ2LQvT8xR1nY6wA0bC7dE/sessions/a3f1c9de-4b2e-4f11-9c7a-1d6e2f0b8a44/reports/session_report.pdf",
  "status": "final"
}
```

---

## Assumptions

- The Laptop ETL Pipeline and Laptop Machine Learning Pipeline are treated as a single trusted "laptop" system boundary for the purposes of this document's ingestion contract (§21); whether they are literally one process or two on the laptop is an implementation detail outside this document's scope.
- One laptop is assumed to handle one live session's ingestion calls at a time per `sessionId`; concurrent multi-laptop writes to the same `sessionId` are not addressed and are assumed not to occur.
- The ingestion principal (§3) is provisioned per organization; the exact provisioning/credential-rotation process is operational tooling not yet designed.
- `peakImpactForce` and similar laptop-computed magnitude fields are stored as opaque numeric values in a unit defined by the ML pipeline; this document does not define that unit, since doing so would be inventing an ML/hardware implementation detail outside a backend specification's scope.

## Open Questions

**Resolved in Phase 1.6:** the question of whether the laptop performs all BLE connectivity and computation, or whether the Flutter Application also connects to hardware directly, is resolved — the laptop is the sole MVP path. See [DECISIONS.md ADR-030](DECISIONS.md#adr-030-laptop-centric-ble-etl-and-ml-pipeline-for-mvp) and [ARCHITECTURE.md §7](ARCHITECTURE.md#7-ble-architecture). Direct Flutter-side BLE remains a documented future capability, not an open architectural question.

Remaining open questions:

1. **Ingestion principal provisioning and credential rotation** — how a new laptop deployment is issued its Firebase Auth credential, and how it is revoked if a laptop is lost or decommissioned.
2. **Raw sensor data retention window** (§20) — the proposed 24-month default requires confirmation against whatever compliance regime is identified per [ARCHITECTURE.md's open question on regulatory requirements](ARCHITECTURE.md#open-questions).
3. **`riskFactors` and alert `type` vocabulary** — this document establishes the field as a string/enum but the full, authoritative list of codes must be defined jointly with the ML/Risk Engine team, not invented unilaterally by the backend specification.
4. **Units for magnitude fields** (`peakImpactForce`, load indices) — not defined here; belongs to the ML/hardware pipeline's own specification.
5. **Whether a session can have more than one report of type `session_report`** (e.g. a revised report after manual clinician review) — this document assumes one `session_report` per `sessionId`, which should be confirmed before Roadmap Phase 10.
6. **Provisioning a distinct ingestion-principal claim shape for a future Flutter-side ingestion path** (per [ARCHITECTURE.md's Future Evolution section](ARCHITECTURE.md#future-evolution)) — not needed for MVP, but noted here so it isn't rediscovered from scratch if that capability is prioritized later.

## Document Control

| Field | Value |
|---|---|
| Owner | Lead Backend Architect |
| Status | Foundation — official backend contract |
| Related documents | [ARCHITECTURE.md](ARCHITECTURE.md), [SPECIFICATION.md](SPECIFICATION.md), [DECISIONS.md](DECISIONS.md), [ROADMAP.md](ROADMAP.md), [PRODUCT_PRINCIPLES.md](PRODUCT_PRINCIPLES.md) |

This document is updated, not rewritten, as later phases resolve its open questions or as the ETL/ML pipeline's actual output shape is confirmed against real hardware. A change that alters a collection's shape after implementation has begun against it should be treated with the same care as a database migration, not a documentation edit alone.
