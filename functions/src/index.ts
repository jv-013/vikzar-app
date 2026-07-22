/**
 * Cloud Functions implementing BACKEND_SPECIFICATION.md §17/§21 — the sole
 * code path permitted to write computed session, alert, report, and
 * live-monitoring data into Firestore, per §0's trust boundary. Not
 * deployed as part of this pass (requires the project owner's Firebase
 * CLI access) — built and unit-tested locally, ready to deploy.
 */

// Callable — invoked by the laptop ETL/ML pipeline's ingestion principal.
export { startSession } from "./callable/startSession";
export { ingestLiveTick } from "./callable/ingestLiveTick";
export { completeSession } from "./callable/completeSession";
export { submitAlert } from "./callable/submitAlert";
export { submitReport } from "./callable/submitReport";

// Firestore-triggered.
export { fanOutLiveMonitoring } from "./triggers/fanOutLiveMonitoring";
export { onSessionCompleted } from "./triggers/onSessionCompleted";
export { onAlertCreated } from "./triggers/onAlertCreated";
export { onReportCreated } from "./triggers/onReportCreated";

// Scheduled.
export { deviceHeartbeatMonitor } from "./scheduled/deviceHeartbeatMonitor";
export { weeklySummaryAggregator } from "./scheduled/weeklySummaryAggregator";
