import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/providers/current_uid_provider.dart';
import '../../data/repositories/notification_repository_impl.dart';
import '../../domain/models/app_notification.dart';

/// Streams `users/{uid}/notifications` from Firestore — **Revised at
/// Phase 8B** (DECISIONS.md ADR-053), replacing the hardcoded two-item
/// placeholder seed list. Notification creation is Cloud-Function-only;
/// real triggers (`onAlertCreated`/`onReportCreated`/
/// `onPlannedSessionCreated`/`onSessionCompleted`, ADR-067) write to this
/// collection since Phase 13/15 — an account with no qualifying events
/// yet sees a genuinely, honestly empty collection, not a simulated one.
class NotificationsController extends StreamNotifier<List<AppNotification>> {
  @override
  Stream<List<AppNotification>> build() {
    final uid = ref.watch(currentUidProvider);
    if (uid == null) return Stream.value(const []);

    return ref.watch(notificationRepositoryProvider).watchNotifications(uid).map(
      (result) => result.fold(
        onSuccess: (notifications) => notifications,
        onFailure: (failure) => throw failure,
      ),
    );
  }

  Future<void> markAsRead(String id) async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    await ref
        .read(notificationRepositoryProvider)
        .markAsRead(uid: uid, notificationId: id);
  }

  Future<void> markAllAsRead() async {
    final uid = ref.read(currentUidProvider);
    final current = state.value;
    if (uid == null || current == null) return;

    final unreadIds = [
      for (final notification in current)
        if (!notification.read) notification.id,
    ];
    if (unreadIds.isEmpty) return;

    await ref
        .read(notificationRepositoryProvider)
        .markAllAsRead(uid: uid, notificationIds: unreadIds);
  }
}

// `.autoDispose` — matches every other Firestore-backed provider in this
// codebase (DECISIONS.md ADR-068); this one was found missing it during
// a later production-readiness pass.
final notificationsControllerProvider =
    StreamNotifierProvider.autoDispose<NotificationsController, List<AppNotification>>(
      NotificationsController.new,
    );
