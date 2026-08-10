/// `users/{uid}/notifications/{notificationId}` — BACKEND_SPECIFICATION.md
/// §1.6. **Revised at Phase 8B** (DECISIONS.md ADR-053): this is now a real
/// Firestore-backed model, so `NotificationCategory`'s values and
/// [firestoreKey] mirror the schema's `type` enum exactly rather than an
/// invented placeholder set.
enum NotificationCategory {
  alert,
  reportReady,
  sessionSummary,
  teamInvite,
  sessionScheduled,
  system;

  /// The exact string stored in Firestore's `type` field — snake_case,
  /// per BACKEND_SPECIFICATION.md §1.6, unlike this codebase's usual
  /// `.name` convention (camelCase Dart enum names don't match this
  /// schema's existing snake_case values, which predate this revision).
  /// `sessionScheduled` is additive (Phase 13 §5) — a coach's
  /// `createPlannedSession` call notifies the team's players.
  String get firestoreKey => switch (this) {
    NotificationCategory.alert => 'alert',
    NotificationCategory.reportReady => 'report_ready',
    NotificationCategory.sessionSummary => 'session_summary',
    NotificationCategory.teamInvite => 'team_invite',
    NotificationCategory.sessionScheduled => 'session_scheduled',
    NotificationCategory.system => 'system',
  };

  static NotificationCategory fromFirestoreKey(String? key) {
    for (final value in NotificationCategory.values) {
      if (value.firestoreKey == key) return value;
    }
    return NotificationCategory.system;
  }
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.timestamp,
    this.read = false,
    this.category = NotificationCategory.system,
    this.razCategory,
  });

  final String id;
  final String title;
  final String body;
  final DateTime timestamp;
  final bool read;
  final NotificationCategory category;

  /// RAZ's own semantic flavor of *why* this notification is what it is
  /// (`recovery`/`coach`/`session`/`hardware`/`movement` — see
  /// `RazNotificationCategory` in `functions/src/lib/intelligence/
  /// razNotificationEngine.ts`) — distinct from [category] above, which
  /// is the structural/routing type every notification has. Only
  /// alert/report-sourced notifications carry one; `null` for
  /// `teamInvite`/`sessionScheduled`/`sessionSummary`/`system`
  /// notifications, which have no RAZ category to show.
  final String? razCategory;

  factory AppNotification.fromMap(Map<String, dynamic> data, {required String id}) {
    return AppNotification(
      id: id,
      title: data['title'] as String? ?? '',
      body: data['body'] as String? ?? '',
      timestamp: (data['createdAt'] as DateTime?) ?? DateTime.now(),
      read: data['read'] as bool? ?? false,
      category: NotificationCategory.fromFirestoreKey(data['type'] as String?),
      razCategory: data['razCategory'] as String?,
    );
  }
}
