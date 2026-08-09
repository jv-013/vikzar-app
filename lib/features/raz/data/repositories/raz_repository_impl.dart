// `cloud_functions` also exports a `Result` type, colliding with this
// codebase's own `core/result/result.dart` — hidden here since only
// `FirebaseFunctions` is needed, matching every other Callable
// repository's own import. `fn` is the same package imported again
// under a prefix, solely to reach its `Chunk`/`Result` stream-event
// variants (needed for `askStream`) without that collision.
import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart' hide Result;
import 'package:cloud_functions/cloud_functions.dart' as fn show Chunk, Result;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/cloud_function_failure_mapper.dart';
import '../../../../core/result/result.dart';
import '../../../../services/firebase/functions_service.dart';
import '../../domain/models/raz_response.dart';
import '../../domain/repositories/raz_repository.dart';
import '../providers/raz_call_metrics_provider.dart';

class RazRepositoryImpl implements RazRepository {
  RazRepositoryImpl(this._functions, {void Function(RazCallMetric)? onCall})
    : _onCall = onCall ?? ((_) {});

  final FirebaseFunctions _functions;
  final void Function(RazCallMetric) _onCall;

  Future<Result<RazResponse>> _call(
    String callableName,
    Map<String, dynamic> payload,
  ) async {
    final stopwatch = Stopwatch()..start();
    try {
      final callable = _functions.httpsCallable(callableName);
      final response = await callable.call<Map<String, dynamic>>(payload);
      stopwatch.stop();
      _onCall(
        RazCallMetric(callableName: callableName, latency: stopwatch.elapsed, success: true),
      );
      return Result.success(RazResponse.fromMap(response.data));
    } catch (e) {
      stopwatch.stop();
      _onCall(
        RazCallMetric(callableName: callableName, latency: stopwatch.elapsed, success: false),
      );
      return Result.failure(mapCloudFunctionError(e));
    }
  }

  @override
  Future<Result<RazResponse>> ask({
    required RazAudience audience,
    required String question,
    List<RazTurn> history = const [],
    RazConversationMode mode = RazConversationMode.text,
  }) {
    return _call('razAsk', _askPayload(audience, question, history, mode));
  }

  /// **`mode` deliberately not sent yet.** The currently-deployed
  /// `razAsk` revision validates its payload with an exact-shape check
  /// that rejects unknown fields — sending `mode` before that revision
  /// is live turns every RAZ call into a fast, clean
  /// `invalid-argument` failure (confirmed live: "Couldn't reach RAZ."
  /// on every message). [mode] stays a real parameter, threaded and
  /// ready, so turning this back on the moment the new backend is
  /// deployed is a one-line change here, not a re-plumb — see
  /// `RC1_RAZ_INTELLIGENCE_UPGRADE.md` §11/§12 for the full context.
  Map<String, dynamic> _askPayload(
    RazAudience audience,
    String question,
    List<RazTurn> history,
    RazConversationMode mode,
  ) {
    return {
      'audience': audience.name,
      'question': question,
      if (history.isNotEmpty)
        'history': [
          for (final turn in history) {'question': turn.question, 'answer': turn.answer},
        ],
    };
  }

  /// No event of any kind (chunk or final result) arriving within this
  /// long resets the guarantee every network call in this app already
  /// makes — that it eventually resolves, one way or another. Streaming
  /// specifically has no other backstop: a normal `.call()` is bounded
  /// by the transport's own request timeout, but a stream that never
  /// receives its first server-sent event can otherwise hang open
  /// indefinitely with the UI showing nothing — no error, no spinner
  /// resolving, nothing. Resets on every event, so a slow-but-alive
  /// stream is never cut off mid-answer, only one that's gone silent.
  static const _streamTimeout = Duration(seconds: 25);

  @override
  Stream<RazAskEvent> askStream({
    required RazAudience audience,
    required String question,
    List<RazTurn> history = const [],
    RazConversationMode mode = RazConversationMode.text,
  }) async* {
    final stopwatch = Stopwatch()..start();
    try {
      final callable = _functions.httpsCallable('razAsk');
      final payload = _askPayload(audience, question, history, mode);
      final stream = callable
          .stream<dynamic, Map<String, dynamic>>(payload)
          .timeout(
            _streamTimeout,
            onTimeout: (sink) => sink.addError(
              TimeoutException('razAsk: no response within $_streamTimeout.'),
            ),
          );
      await for (final event in stream) {
        switch (event) {
          case fn.Chunk(:final partialData):
            final delta = partialData is String ? partialData : partialData.toString();
            if (delta.isNotEmpty) yield RazAskDelta(delta);
          case fn.Result(:final result):
            stopwatch.stop();
            _onCall(RazCallMetric(callableName: 'razAsk', latency: stopwatch.elapsed, success: true));
            yield RazAskDone(Result.success(RazResponse.fromMap(result.data)));
        }
      }
    } catch (e) {
      stopwatch.stop();
      _onCall(RazCallMetric(callableName: 'razAsk', latency: stopwatch.elapsed, success: false));
      yield RazAskDone(Result.failure(mapCloudFunctionError(e)));
    }
  }

  @override
  Future<Result<RazResponse>> dailyBrief({required RazAudience audience}) {
    return _call('razDailyBrief', {'audience': audience.name});
  }
}

final razRepositoryProvider = Provider<RazRepository>((ref) {
  return RazRepositoryImpl(
    ref.watch(functionsProvider),
    onCall: (metric) => ref.read(razCallMetricsProvider.notifier).record(metric),
  );
});
