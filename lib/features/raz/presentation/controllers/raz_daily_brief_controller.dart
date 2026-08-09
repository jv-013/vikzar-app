import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/result/result.dart';
import '../../data/repositories/raz_repository_impl.dart';
import '../../domain/models/raz_response.dart';
import '../../domain/repositories/raz_repository.dart';

/// One real, narrated brief per audience — the primary Vikzar
/// experience. Backed by `razDailyBrief`, which caches server-side by
/// context hash, so re-opening Home repeatedly doesn't re-run the LLM;
/// this provider is `.autoDispose` so it still refetches (cheaply,
/// cache-hit) each time Home is freshly built rather than holding a
/// stale brief forever.
final razDailyBriefProvider = FutureProvider.autoDispose
    .family<Result<RazResponse>, RazAudience>((ref, audience) {
      return ref.read(razRepositoryProvider).dailyBrief(audience: audience);
    });
