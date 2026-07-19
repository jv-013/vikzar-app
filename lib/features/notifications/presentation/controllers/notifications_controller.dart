import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/app_notification.dart';

/// Placeholder notification data — DESIGN_SPECIFICATION.md §16 row 25.
/// **No backend this phase**: no Firestore `users/{uid}/notifications`
/// read, no FCM. The simulated delay gives the Notification Center's
/// loading state something genuine to show; the seeded list is realistic
/// (mirrors what a real welcome/profile-nudge notification would say) but
/// entirely static.
class NotificationsController extends AsyncNotifier<List<AppNotification>> {
  @override
  Future<List<AppNotification>> build() async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final now = DateTime.now();
    return [
      AppNotification(
        id: 'welcome',
        title: 'Welcome to Vikzar',
        body: 'Your account is ready. Explore your Home to get started.',
        timestamp: now.subtract(const Duration(minutes: 5)),
      ),
      AppNotification(
        id: 'complete-profile',
        title: 'Complete your profile',
        body: 'Add your details so your coach can recognize you on the roster.',
        timestamp: now.subtract(const Duration(hours: 3)),
        read: true,
      ),
    ];
  }

  void markAsRead(String id) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData([
      for (final notification in current)
        if (notification.id == id) notification.copyWith(read: true) else notification,
    ]);
  }

  void markAllAsRead() {
    final current = state.value;
    if (current == null) return;
    state = AsyncData([for (final notification in current) notification.copyWith(read: true)]);
  }
}

final notificationsControllerProvider =
    AsyncNotifierProvider<NotificationsController, List<AppNotification>>(
      NotificationsController.new,
    );
