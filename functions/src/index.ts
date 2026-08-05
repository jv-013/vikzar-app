/**
 * Cloud Functions implementing BACKEND_SPECIFICATION.md §17/§21 — the sole
 * code path permitted to write computed session, alert, report, and
 * live-monitoring data into Firestore, per §0's trust boundary. Not
 * deployed as part of this pass (requires the project owner's Firebase
 * CLI access) — built and unit-tested locally, ready to deploy.
 */
import { setGlobalOptions } from "firebase-functions/v2";

// Phase 13 §14 — a real, code-doable budget-protection measure: caps the
// number of concurrent instances any one function can scale to, so a
// runaway trigger loop (e.g. a Firestore trigger that writes the
// document type that re-triggers it) has a hard ceiling rather than
// scaling unboundedly and driving up cost. 20 comfortably covers this
// app's realistic concurrent load (a handful of simultaneous live
// sessions/teams) without being high enough to mask a genuine bug.
setGlobalOptions({ maxInstances: 20 });

// Callable — invoked by the laptop ETL/ML pipeline's ingestion principal.
export { startSession } from "./callable/startSession";
export { ingestLiveTick } from "./callable/ingestLiveTick";
export { completeSession } from "./callable/completeSession";
export { submitAlert } from "./callable/submitAlert";
export { submitReport } from "./callable/submitReport";

// Callable — invoked by a real, authenticated product end user (Coach).
export { createPlannedSession } from "./callable/createPlannedSession";
export { approveCoachRequest } from "./callable/approveCoachRequest";

// Callable — Team/Invite backend (Phase 15). Every team-membership write
// (create a team, generate an invite code, redeem one as a player, join
// an existing team as a co-coach) now runs here instead of the Flutter
// client writing `teams`/`teams/{id}/members` directly.
export { createTeam } from "./callable/createTeam";
export { createTeamInvite } from "./callable/createTeamInvite";
export { joinTeamWithInvite } from "./callable/joinTeamWithInvite";
export { joinTeamAsCoach } from "./callable/joinTeamAsCoach";

// Callable — RAZ (Vikzar's Football Operating System), invoked by any
// signed-in Player/Coach. Builds its own context from real Firestore
// data via RazContext rather than trusting a client-supplied assessment.
export { razAsk } from "./callable/razAsk";
export { razDailyBrief } from "./callable/razDailyBrief";

// Firestore-triggered.
export { fanOutLiveMonitoring } from "./triggers/fanOutLiveMonitoring";
export { onSessionCompleted } from "./triggers/onSessionCompleted";
export { onAlertCreated } from "./triggers/onAlertCreated";
export { onReportCreated } from "./triggers/onReportCreated";
export { onPlannedSessionCreated } from "./triggers/onPlannedSessionCreated";

// Scheduled.
export { deviceHeartbeatMonitor } from "./scheduled/deviceHeartbeatMonitor";
export { weeklySummaryAggregator } from "./scheduled/weeklySummaryAggregator";
