import 'package:flutter_test/flutter_test.dart';

import 'package:vikzar/features/alerts/domain/models/alert.dart';

void main() {
  group('Alert.fromMap', () {
    test('parses a well-formed map, defaulting severity to info when unrecognized', () {
      final triggeredAt = DateTime(2026, 1, 1, 9);
      final alert = Alert.fromMap({
        'sessionId': 's1',
        'playerId': 'p1',
        'teamId': 't1',
        'severity': 'critical',
        'type': 'high_impact',
        'message': 'A high-impact event was recorded.',
        'triggeredAt': triggeredAt,
        'acknowledged': false,
      }, alertId: 'a1');

      expect(alert.alertId, 'a1');
      expect(alert.severity, AlertSeverity.critical);
      expect(alert.message, 'A high-impact event was recorded.');
      expect(alert.triggeredAt, triggeredAt);
      expect(alert.acknowledged, isFalse);
      expect(alert.acknowledgedBy, isNull);
    });

    test('defaults an unrecognized severity string to info', () {
      final alert = Alert.fromMap({
        'sessionId': 's1',
        'playerId': 'p1',
        'severity': 'not-a-real-severity',
        'type': 'device_disconnected',
        'message': 'Device disconnected.',
        'triggeredAt': DateTime.now(),
      }, alertId: 'a2');

      expect(alert.severity, AlertSeverity.info);
    });
  });
}
