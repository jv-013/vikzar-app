import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vikzar/features/notifications/domain/models/app_notification.dart';
import 'package:vikzar/features/notifications/presentation/controllers/notifications_controller.dart';
import 'package:vikzar/features/notifications/presentation/screens/notification_center_screen.dart';

void main() {
  group('NotificationCenterScreen', () {
    testWidgets('shows populated notifications from the stream', (tester) async {
      final now = DateTime.now();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            notificationsControllerProvider.overrideWith(
              () => _FixedNotifications([
                AppNotification(
                  id: 'n1',
                  title: 'Welcome to Vikzar',
                  body: 'Your account is ready. Explore your Home to get started.',
                  timestamp: now.subtract(const Duration(minutes: 5)),
                ),
                AppNotification(
                  id: 'n2',
                  title: 'Complete your profile',
                  body: 'Add your details so your coach can recognize you on the roster.',
                  timestamp: now.subtract(const Duration(hours: 3)),
                  read: true,
                ),
              ]),
            ),
          ],
          child: const MaterialApp(home: NotificationCenterScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Welcome to Vikzar'), findsOneWidget);
      expect(find.text('Complete your profile'), findsOneWidget);
    });

    testWidgets(
      'shows an empty state when there are no notifications — the real, '
      'honest state for every account today, since notification creation '
      'is Cloud-Function-only and no pipeline exists yet (DECISIONS.md '
      'ADR-053)',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              notificationsControllerProvider.overrideWith(_EmptyNotifications.new),
            ],
            child: const MaterialApp(home: NotificationCenterScreen()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('No notifications yet.'), findsOneWidget);
      },
    );

    testWidgets('shows a loading indicator while resolving', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            notificationsControllerProvider.overrideWith(_NeverResolves.new),
          ],
          child: const MaterialApp(home: NotificationCenterScreen()),
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}

class _FixedNotifications extends NotificationsController {
  _FixedNotifications(this._notifications);

  final List<AppNotification> _notifications;

  @override
  Stream<List<AppNotification>> build() => Stream.value(_notifications);
}

class _EmptyNotifications extends NotificationsController {
  @override
  Stream<List<AppNotification>> build() => Stream.value(const []);
}

class _NeverResolves extends NotificationsController {
  @override
  Stream<List<AppNotification>> build() =>
      Stream.fromFuture(Completer<List<AppNotification>>().future);
}
