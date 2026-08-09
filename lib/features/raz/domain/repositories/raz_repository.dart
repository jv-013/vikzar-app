import '../../../../core/result/result.dart';
import '../models/raz_response.dart';

enum RazAudience { player, coach }

/// Mirrors `functions/src/lib/intelligence/razConversation.ts`'s
/// `ConversationMode` — presentation only, never changes the reasoning
/// behind an answer. `voice` asks the backend to keep the reply short
/// enough to speak naturally; `text` allows the fuller detail a typed
/// chat thread can afford.
enum RazConversationMode {
  voice,
  text;

  String get wireName => name;
}

class RazTurn {
  const RazTurn({required this.question, required this.answer});

  final String question;
  final String answer;
}

/// One event from [RazRepository.askStream] — either the next slice of
/// text as RAZ's answer generates (concatenate in arrival order to
/// reconstruct the text so far), or the final, complete [RazResponse]
/// once generation has finished. Exactly one [RazAskDone] always ends
/// the stream, whether preceded by any [RazAskDelta] events or not (a
/// non-streaming-capable path still resolves through this same event).
sealed class RazAskEvent {
  const RazAskEvent();
}

final class RazAskDelta extends RazAskEvent {
  const RazAskDelta(this.text);

  final String text;
}

final class RazAskDone extends RazAskEvent {
  const RazAskDone(this.result);

  final Result<RazResponse> result;
}

/// Calls RAZ's Cloud Functions (`razAsk`/`razDailyBrief`) — the only two
/// ways this app ever reaches Vikzar's Football Operating System.
/// Nothing in Flutter calls Gemini, or any LLM, directly.
abstract interface class RazRepository {
  /// Non-streaming — awaits the complete answer. Kept for callers that
  /// only ever need the final result (e.g. nothing renders progressively
  /// for them); [askStream] is what the conversational UI actually uses.
  Future<Result<RazResponse>> ask({
    required RazAudience audience,
    required String question,
    List<RazTurn> history = const [],
    RazConversationMode mode = RazConversationMode.text,
  });

  /// Streams RAZ's answer as it generates. Always ends in exactly one
  /// [RazAskDone] — callers that don't care about incremental text can
  /// simply ignore [RazAskDelta] events and await the done event.
  Stream<RazAskEvent> askStream({
    required RazAudience audience,
    required String question,
    List<RazTurn> history = const [],
    RazConversationMode mode = RazConversationMode.text,
  });

  Future<Result<RazResponse>> dailyBrief({required RazAudience audience});
}
