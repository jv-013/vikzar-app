import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vikzar/features/notifications/domain/models/app_notification.dart';
import 'package:vikzar/features/notifications/presentation/controllers/notifications_controller.dart';
import 'package:vikzar/features/notifications/presentation/screens/notification_center_screen.dart';

void main() {
  group('NotificationCenterScreen', () {
    testWidgets('shows the populated placeholder notifications and marks '
        'one as read on tap', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: NotificationCenterScreen()),
        ),
      );
      // The controller's build() has a simulated delay — settle past it.
      await tester.pumpAndSettle();

      expect(find.text('Welcome to Vikzar'), findsOneWidget);
      expect(find.text('Complete your profile'), findsOneWidget);
    });

    testWidgets('shows an empty state when there are no notifications', (
      tester,
    ) async {
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
    });

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

class _EmptyNotifications extends NotificationsController {
  @override
  Future<List<AppNotification>> build() async => const [];
}

class _NeverResolves extends NotificationsController {
  @override
  Future<List<AppNotification>> build() => Completer<List<AppNotification>>().future;
}
