import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vikzar/core/result/result.dart';
import 'package:vikzar/design_system/theme/app_theme.dart';
import 'package:vikzar/features/alerts/domain/models/alert.dart';
import 'package:vikzar/features/alerts/presentation/controllers/alerts_controller.dart';
import 'package:vikzar/features/alerts/presentation/screens/alerts_screen.dart';

Alert _alert(
  String id, {
  AlertSeverity severity = AlertSeverity.info,
  bool acknowledged = false,
  String message = 'Something happened.',
}) {
  return Alert(
    alertId: id,
    sessionId: 's1',
    playerId: 'p1',
    teamId: 't1',
    severity: severity,
    type: 'high_impact',
    message: message,
    triggeredAt: DateTime.now().subtract(const Duration(minutes: 5)),
    acknowledged: acknowledged,
  );
}

Future<void> _pump(WidgetTester tester, List<Alert> alerts) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        alertsControllerProvider.overrideWith(
          (ref) => Stream.value(Result.success(alerts)),
        ),
      ],
      child: MaterialApp(theme: AppTheme.dark(), home: const AlertsScreen()),
    ),
  );
  await tester.pump();
}

void main() {
  group('AlertsScreen', () {
    testWidgets(
      'shows the exact DESIGN_SPECIFICATION.md §19.4 empty-state copy when there are no alerts',
      (tester) async {
        await _pump(tester, const []);

        expect(find.text('No alerts. Your team is clear.'), findsOneWidget);
      },
    );

    testWidgets('shows each real alert with its severity and message', (tester) async {
      await _pump(tester, [
        _alert('a1', severity: AlertSeverity.critical, message: 'Critical event.'),
        _alert('a2', severity: AlertSeverity.warning, message: 'Warning event.'),
      ]);

      expect(find.text('Critical'), findsOneWidget);
      expect(find.text('Critical event.'), findsOneWidget);
      expect(find.text('Warning'), findsOneWidget);
      expect(find.text('Warning event.'), findsOneWidget);
    });

    testWidgets('the Unacknowledged filter hides already-acknowledged alerts', (tester) async {
      await _pump(tester, [
        _alert('a1', acknowledged: true, message: 'Already handled.'),
        _alert('a2', acknowledged: false, message: 'Still open.'),
      ]);

      expect(find.text('Already handled.'), findsOneWidget);
      expect(find.text('Still open.'), findsOneWidget);

      await tester.tap(find.text('Unacknowledged'));
      await tester.pump();

      expect(find.text('Already handled.'), findsNothing);
      expect(find.text('Still open.'), findsOneWidget);
    });

    testWidgets('tapping an unacknowledged alert offers to acknowledge it', (tester) async {
      await _pump(tester, [_alert('a1', message: 'Needs review.')]);

      await tester.tap(find.text('Needs review.'));
      await tester.pumpAndSettle();

      expect(find.text('Acknowledge alert'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Acknowledge'), findsOneWidget);
    });
  });
}
