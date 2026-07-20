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
  system;

  /// The exact string stored in Firestore's `type` field — snake_case,
  /// per BACKEND_SPECIFICATION.md §1.6, unlike this codebase's usual
  /// `.name` convention (camelCase Dart enum names don't match this
  /// schema's existing snake_case values, which predate this revision).
  String get firestoreKey => switch (this) {
    NotificationCategory.alert => 'alert',
    NotificationCategory.reportReady => 'report_ready',
    NotificationCategory.sessionSummary => 'session_summary',
    NotificationCategory.teamInvite => 'team_invite',
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
  });

  final String id;
  final String title;
  final String body;
  final DateTime timestamp;
  final bool read;
  final NotificationCategory category;

  factory AppNotification.fromMap(Map<String, dynamic> data, {required String id}) {
    return AppNotification(
      id: id,
      title: data['title'] as String? ?? '',
      body: data['body'] as String? ?? '',
      timestamp: (data['createdAt'] as DateTime?) ?? DateTime.now(),
      read: data['read'] as bool? ?? false,
      category: NotificationCategory.fromFirestoreKey(data['type'] as String?),
    );
  }
}
