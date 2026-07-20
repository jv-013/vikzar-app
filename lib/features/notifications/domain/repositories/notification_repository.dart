import '../../../../core/result/result.dart';
import '../models/app_notification.dart';

/// `users/{uid}/notifications/{notificationId}` — BACKEND_SPECIFICATION.md
/// §1.6/§18. Creation is Cloud-Function-only (no notification pipeline
/// exists yet, per §17/§18); the client only ever reads and marks `read`.
abstract interface class NotificationRepository {
  Stream<Result<List<AppNotification>>> watchNotifications(String uid);

  Future<Result<void>> markAsRead({
    required String uid,
    required String notificationId,
  });

  Future<Result<void>> markAllAsRead({
    required String uid,
    required List<String> notificationIds,
  });
}
