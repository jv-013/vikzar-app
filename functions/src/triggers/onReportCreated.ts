import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { coachUidsForTeam, writeNotifications, NotificationInput } from "../lib/notifications";

/**
 * BACKEND_SPECIFICATION.md §17/§18 — reacts to `reports/{reportId}`
 * creation. Per §18's table: `session_report`/`player_profile_report` →
 * the player and coaches of `teamId`; `weekly_summary` → coaches of
 * `teamId` only (a rollup report has no single owning player).
 */
export const onReportCreated = onDocumentCreated("reports/{reportId}", async (event) => {
  const report = event.data?.data();
  if (!report) return;

  const reportId = event.params.reportId;
  const type = report["type"] as string;
  const playerId = report["playerId"] as string | undefined;
  const teamId = report["teamId"] as string | undefined;

  const recipients = new Map<string, NotificationInput>();
  const notification: Omit<NotificationInput, "uid"> = {
    type: "report_ready",
    title: "Report ready",
    body:
      type === "weekly_summary"
        ? "Your team's weekly summary is ready."
        : "A new report is ready to view.",
    relatedReportId: reportId,
  };

  if (type !== "weekly_summary" && playerId != null) {
    recipients.set(playerId, { uid: playerId, ...notification });
  }
  if (teamId != null) {
    for (const uid of await coachUidsForTeam(teamId)) {
      recipients.set(uid, { uid, ...notification });
    }
  }

  await writeNotifications(Array.from(recipients.values()));
});
