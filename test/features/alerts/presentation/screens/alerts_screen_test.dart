import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vikzar/core/errors/failure.dart';
import 'package:vikzar/core/result/result.dart';
import 'package:vikzar/design_system/theme/app_theme.dart';
import 'package:vikzar/features/alerts/data/repositories/alert_repository_impl.dart';
import 'package:vikzar/features/alerts/domain/models/alert.dart';
import 'package:vikzar/features/alerts/domain/repositories/alert_repository.dart';
import 'package:vikzar/features/alerts/presentation/controllers/alerts_controller.dart';
import 'package:vikzar/features/alerts/presentation/screens/alerts_screen.dart';
import 'package:vikzar/shared/providers/current_uid_provider.dart';

/// Phase 13 §16 — a fake so the acknowledge-failure path (previously
/// silently swallowed by an unawaited Future) can actually be exercised
/// without touching real Firestore.
class _FakeAlertRepository implements AlertRepository {
  _FakeAlertRepository({this.acknowledgeResult = const Result.success(null)});

  final Result<void> acknowledgeResult;
  String? lastAcknowledgedAlertId;

  @override
  Stream<Result<List<Alert>>> watchAlerts(List<String> teamIds) => const Stream.empty();

  @override
  Future<Result<void>> acknowledgeAlert({
    required String alertId,
    required String coachUid,
  }) async {
    lastAcknowledgedAlertId = alertId;
    return acknowledgeResult;
  }
}

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

Future<void> _pump(
  WidgetTester tester,
  List<Alert> alerts, {
  AlertRepository? repository,
  String? coachUid,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        alertsControllerProvider.overrideWith(
          (ref) => Stream.value(Result.success(alerts)),
        ),
        if (repository != null) alertRepositoryProvider.overrideWithValue(repository),
        if (coachUid != null) currentUidProvider.overrideWithValue(coachUid),
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

    testWidgets(
      'confirming Acknowledge awaits the real result and closes the dialog '
      'only on success (Phase 13 §16 fix — previously fired-and-forgot)',
      (tester) async {
        final fakeRepository = _FakeAlertRepository();
        await _pump(
          tester,
          [_alert('a1', message: 'Needs review.')],
          repository: fakeRepository,
          coachUid: 'coach-1',
        );

        await tester.tap(find.text('Needs review.'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(TextButton, 'Acknowledge'));
        await tester.pumpAndSettle();

        expect(fakeRepository.lastAcknowledgedAlertId, 'a1');
        expect(find.text('Acknowledge alert'), findsNothing);
      },
    );

    testWidgets(
      'a failed acknowledge surfaces a calm SnackBar instead of silently '
      'succeeding (Phase 13 §16 fix)',
      (tester) async {
        final fakeRepository = _FakeAlertRepository(
          acknowledgeResult: const Result.failure(NetworkFailure()),
        );
        await _pump(
          tester,
          [_alert('a1', message: 'Needs review.')],
          repository: fakeRepository,
          coachUid: 'coach-1',
        );

        await tester.tap(find.text('Needs review.'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(TextButton, 'Acknowledge'));
        await tester.pumpAndSettle();

        expect(fakeRepository.lastAcknowledgedAlertId, 'a1');
        expect(
          find.text("You're offline. Please check your connection and try again."),
          findsOneWidget,
        );
      },
    );
  });
}
