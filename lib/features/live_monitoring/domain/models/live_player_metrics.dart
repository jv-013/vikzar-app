/// `teams/{teamId}/liveMonitoring/{playerId}` — BACKEND_SPECIFICATION.md
/// §1.4. Denormalized, coach-facing live monitoring surface, fanned out by
/// the `fanOutLiveMonitoring` Cloud Function trigger from each player's
/// `sessions/{sessionId}/live/current` document — written by that trigger
/// only, never a direct client or laptop write (per `firestore.rules`).
library;

enum LiveConnectionStatus {
  connected,
  degraded,
  disconnected;

  static LiveConnectionStatus fromName(String? name) {
    for (final value in LiveConnectionStatus.values) {
      if (value.name == name) return value;
    }
    return LiveConnectionStatus.disconnected;
  }
}

/// DESIGN_SPECIFICATION.md "Risk & Status Semantic Colours": Normal/Low,
/// Elevated/Moderate, High, Critical — four levels, matching
/// `currentRiskLevel`'s documented enum exactly.
enum LiveRiskLevel {
  low,
  moderate,
  high,
  critical;

  static LiveRiskLevel fromName(String? name) {
    for (final value in LiveRiskLevel.values) {
      if (value.name == name) return value;
    }
    return LiveRiskLevel.low;
  }
}

class LivePlayerMetrics {
  const LivePlayerMetrics({
    required this.playerId,
    required this.sessionId,
    required this.displayName,
    required this.connectionStatus,
    required this.lastTickAt,
    required this.currentRiskScore,
    required this.currentRiskLevel,
    required this.currentLoad,
    required this.cumulativeImpacts,
    this.deviceBattery = const {},
    this.updatedAt,
  });

  final String playerId;
  final String sessionId;
  final String displayName;
  final LiveConnectionStatus connectionStatus;
  final DateTime lastTickAt;
  final double currentRiskScore;
  final LiveRiskLevel currentRiskLevel;
  final double currentLoad;
  final int cumulativeImpacts;

  /// Keyed by `deviceId`, value 0-100. May be empty — `deviceBattery` is an
  /// optional field per §1.4.
  final Map<String, int> deviceBattery;
  final DateTime? updatedAt;

  /// The lowest battery reading across this player's connected devices, or
  /// `null` if no battery data has arrived yet — never a fabricated
  /// average or default.
  int? get lowestBattery =>
      deviceBattery.values.isEmpty ? null : deviceBattery.values.reduce((a, b) => a < b ? a : b);

  /// Expects [data]'s `lastTickAt`/`updatedAt` already normalized to plain
  /// [DateTime] values — [LiveMonitoringRepositoryImpl] does that
  /// conversion before calling this, keeping this domain model itself free
  /// of any Firebase dependency, per FLUTTER_ARCHITECTURE.md §1's
  /// dependency rule (the same pattern [Alert.fromMap] already uses).
  factory LivePlayerMetrics.fromMap(Map<String, dynamic> data, {required String playerId}) {
    final rawBattery = data['deviceBattery'];
    return LivePlayerMetrics(
      playerId: playerId,
      sessionId: data['sessionId'] as String? ?? '',
      displayName: data['displayName'] as String? ?? '',
      connectionStatus: LiveConnectionStatus.fromName(data['connectionStatus'] as String?),
      lastTickAt: (data['lastTickAt'] as DateTime?) ?? DateTime.now(),
      currentRiskScore: (data['currentRiskScore'] as num?)?.toDouble() ?? 0.0,
      currentRiskLevel: LiveRiskLevel.fromName(data['currentRiskLevel'] as String?),
      currentLoad: (data['currentLoad'] as num?)?.toDouble() ?? 0.0,
      cumulativeImpacts: (data['cumulativeImpacts'] as num?)?.toInt() ?? 0,
      deviceBattery: rawBattery is Map
          ? rawBattery.map((key, value) => MapEntry(key as String, (value as num).toInt()))
          : const {},
      updatedAt: data['updatedAt'] as DateTime?,
    );
  }
}
