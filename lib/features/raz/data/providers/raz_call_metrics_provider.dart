import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One completed RAZ Cloud Functions call (`razAsk`/`razDailyBrief`) —
/// real, measured latency from [RazRepositoryImpl], captured only for
/// the Developer Diagnostics screen (Phase 20.5 Part 4). In-memory for
/// this app run only; never persisted, never sent anywhere.
class RazCallMetric {
  const RazCallMetric({required this.callableName, required this.latency, required this.success});

  final String callableName;
  final Duration latency;
  final bool success;
}

class RazCallMetricsRecorder extends Notifier<RazCallMetric?> {
  @override
  RazCallMetric? build() => null;

  void record(RazCallMetric metric) => state = metric;
}

/// The most recent RAZ Cloud Functions call's outcome, or `null` if none
/// has happened yet this session.
final razCallMetricsProvider = NotifierProvider<RazCallMetricsRecorder, RazCallMetric?>(
  RazCallMetricsRecorder.new,
);
