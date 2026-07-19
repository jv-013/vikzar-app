/// A single notification — DESIGN_SPECIFICATION.md §16, row 25
/// ("Notifications"). Modeled after `users/{uid}/notifications` in
/// BACKEND_SPECIFICATION.md §18's trigger design, but **entirely
/// client-side placeholder data this phase** — no Firestore collection is
/// read or written; see `notification_center_screen.dart`'s provider.
enum NotificationCategory { system, session, team, alert }

class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.timestamp,
    this.read = false,
    this.category = NotificationCategory.system,
  });

  final String id;
  final String title;
  final String body;
  final DateTime timestamp;
  final bool read;
  final NotificationCategory category;

  AppNotification copyWith({bool? read}) => AppNotification(
    id: id,
    title: title,
    body: body,
    timestamp: timestamp,
    read: read ?? this.read,
    category: category,
  );
}
