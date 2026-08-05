import { NotificationInput, NotificationType } from "../notifications";

/**
 * RazNotificationEngine — turns a raw trigger event into RAZ-toned
 * notification copy, replacing generic "Alert"/"Report ready" titles
 * with the same calm, specific voice `persona.ts` defines everywhere
 * else. Deliberately deterministic (no LLM call): a notification fires
 * from a real-time Firestore trigger, where the low latency and zero
 * added cost of a pure function matters more than the LLM's more fluid
 * phrasing — the same reasoning that keeps `razEngine.ts`/
 * `razRecommendations.ts` LLM-free.
 *
 * "Never spam. Only meaningful information" is enforced structurally:
 * this file only ever *phrases* an event some other trigger already
 * decided was worth notifying about (`onAlertCreated`/
 * `onReportCreated`'s existing recipient rules) — it does not introduce
 * a new decision to notify more often. A genuinely new "worth
 * notifying" decision (a training reminder, a hydration nudge on a hot
 * matchday) is a scheduled-function extension point, not something a
 * Firestore-write trigger can originate — see this file's
 * `FUTURE EXTENSION POINTS` note at the bottom.
 */

/** RAZ's own notification categories — distinct from the generic `NotificationType` union the Firestore schema exposes, so a UI can group/icon by *why* something fired, not just its Firestore doc shape. */
export type RazNotificationCategory = "recovery" | "coach" | "session" | "hardware" | "movement";

interface AlertNotificationInput {
  uid: string;
  alertId: string;
  severity: string;
  type: string;
  message: string;
}

export function razAlertNotification(input: AlertNotificationInput): NotificationInput & {
  razCategory: RazNotificationCategory;
} {
  const isCritical = input.severity === "critical";
  const isDeviceIssue = input.type === "device_disconnected";

  const razCategory: RazNotificationCategory = isDeviceIssue ? "hardware" : "recovery";
  const title = isDeviceIssue
    ? "Pod disconnected"
    : isCritical
      ? "Elevated risk noticed"
      : "Worth a look";

  return {
    uid: input.uid,
    type: "alert" satisfies NotificationType,
    title,
    body: input.message,
    relatedAlertId: input.alertId,
    razCategory,
  };
}

interface ReportNotificationInput {
  uid: string;
  reportId: string;
  reportType: string;
}

export function razReportNotification(input: ReportNotificationInput): NotificationInput & {
  razCategory: RazNotificationCategory;
} {
  const isWeeklySummary = input.reportType === "weekly_summary";
  return {
    uid: input.uid,
    type: "report_ready" satisfies NotificationType,
    title: isWeeklySummary ? "Weekly summary ready" : "Session report ready",
    body: isWeeklySummary
      ? "Your team's weekly summary is ready to review."
      : "A new report is ready to view.",
    relatedReportId: input.reportId,
    razCategory: "session",
  };
}

// ---------------------------------------------------------------------------
// FUTURE EXTENSION POINTS (Part 9/13) — designed, not implemented. Each of
// these needs a scheduled Cloud Function (Cloud Scheduler, not a Firestore
// trigger) to decide *when* to fire, since none of them react to a
// document write:
//
// - Morning Brief nudge: a scheduled function per-team's typical wake
//   time, pushing "Your brief is ready" rather than requiring the
//   player to open the app.
// - Training reminder: fires from `plannedSessions`, a fixed offset
//   before `scheduledAt` — needs a scheduled sweep (Cloud Scheduler),
//   not a create-trigger, since the reminder time is a function of the
//   *current* time, not of when the session was created.
// - Recovery warning: fires when `razEngine.ts` computes
//   `hasElevatedRisk` for a *new* daily-brief context hash, not on
//   every unchanged cache hit — hook into `razDailyBrief.ts`'s
//   post-cache-miss path once real recovery data exists to derive it
//   from (today: honestly `available: false`, see `RecoveryInsight`).
// - Coach reminder / upcoming session / hydration reminder / late
//   recovery: same "needs a time-based trigger, not a write-based one"
//   shape as the above.
// ---------------------------------------------------------------------------
