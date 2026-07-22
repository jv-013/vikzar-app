/// `alerts/{alertId}` — BACKEND_SPECIFICATION.md §1.10. Written by Cloud
/// Functions only (`submitAlert`, `deviceHeartbeatMonitor`); the Flutter
/// app may write only [acknowledged]/[acknowledgedBy]/[acknowledgedAt],
/// per `firestore.rules`' `update` rule for this collection.
enum AlertSeverity {
  info,
  warning,
  critical;

  static AlertSeverity fromName(String? name) {
    for (final value in AlertSeverity.values) {
      if (value.name == name) return value;
    }
    return AlertSeverity.info;
  }
}

class Alert {
  const Alert({
    required this.alertId,
    required this.sessionId,
    required this.playerId,
    this.teamId,
    required this.severity,
    required this.type,
    required this.message,
    required this.triggeredAt,
    this.acknowledged = false,
    this.acknowledgedBy,
    this.acknowledgedAt,
  });

  final String alertId;
  final String sessionId;
  final String playerId;
  final String? teamId;
  final AlertSeverity severity;
  final String type;
  final String message;
  final DateTime triggeredAt;
  final bool acknowledged;
  final String? acknowledgedBy;
  final DateTime? acknowledgedAt;

  /// Expects [data]'s `triggeredAt`/`acknowledgedAt` already normalized to
  /// plain [DateTime] values — [AlertRepositoryImpl] does that conversion
  /// before calling this, keeping this domain model itself free of any
  /// Firebase dependency, per FLUTTER_ARCHITECTURE.md §1's dependency rule.
  factory Alert.fromMap(Map<String, dynamic> data, {required String alertId}) {
    return Alert(
      alertId: alertId,
      sessionId: data['sessionId'] as String? ?? '',
      playerId: data['playerId'] as String? ?? '',
      teamId: data['teamId'] as String?,
      severity: AlertSeverity.fromName(data['severity'] as String?),
      type: data['type'] as String? ?? '',
      message: data['message'] as String? ?? '',
      triggeredAt: (data['triggeredAt'] as DateTime?) ?? DateTime.now(),
      acknowledged: data['acknowledged'] as bool? ?? false,
      acknowledgedBy: data['acknowledgedBy'] as String?,
      acknowledgedAt: data['acknowledgedAt'] as DateTime?,
    );
  }
}
