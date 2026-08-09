import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/providers/current_uid_provider.dart';
import '../../data/repositories/raz_repository_impl.dart';
import '../../domain/models/raz_message.dart';
import '../../domain/models/raz_response.dart';
import '../../domain/repositories/raz_repository.dart';
import '../../domain/utils/raz_text_utils.dart';

const _maxHistoryTurns = 6;

/// **Enabled.** The previous freeze (`HttpsCallable.stream` against a
/// non-streaming-aware backend locking the Flutter isolate — even past
/// a client-side `Stream.timeout`) was a symptom of the *old* deployed
/// `razAsk`, not of this code. The backend is now deployed as a real
/// streaming-capable revision (`razask-00003-mad`, confirmed via
/// `gcloud functions describe` and a direct read of its deployed
/// source), so this flag now matches reality. See
/// `RC1_RAZ_INTELLIGENCE_UPGRADE.md` §11/§11b for the full history —
/// if this ever needs reverting, `_askOnce` remains fully intact below.
const _useStreamingConversation = true;

class RazConversationState {
  const RazConversationState({this.messages = const [], this.isLoading = false, this.errorText});

  final List<RazMessage> messages;
  final bool isLoading;
  final String? errorText;

  RazConversationState copyWith({
    List<RazMessage>? messages,
    bool? isLoading,
    String? errorText,
    bool clearError = false,
  }) {
    return RazConversationState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      errorText: clearError ? null : (errorText ?? this.errorText),
    );
  }
}

/// Drives the RAZ conversation screen — the secondary, optional
/// interface to RAZ's intelligence (the Daily Brief is primary). Every
/// `ask` call goes through `RazRepository`, never a direct Gemini/LLM
/// call from Flutter. Conversation state lives in memory only for this
/// provider's lifetime (see `RazMessage`'s doc comment for why);
/// `.family` over [RazAudience] so Player and Coach each get their own
/// independent thread.
class RazConversationController extends Notifier<RazConversationState> {
  RazConversationController(this.audience);

  final RazAudience audience;

  // Rebuilds fresh (dropping any prior conversation) whenever the
  // signed-in user changes — without this, `RazAudience` alone (2
  // values) means Player A's conversation history, including real
  // training/recovery details in `RazResponse` text, could otherwise be
  // reused for Player B on a shared device after sign-out/sign-in, and
  // would even be fed back to the server as "history" context for
  // Player B's own questions.
  @override
  RazConversationState build() {
    ref.watch(currentUidProvider);
    return const RazConversationState();
  }

  /// Returns the response so a caller (e.g. voice input, which needs to
  /// speak the answer back) can react to this specific call directly,
  /// rather than subscribing to state changes and risking a listener
  /// leak across repeated asks.
  ///
  /// Streams under the hood: [state.messages] grows a live
  /// [RazMessage.razStreaming] entry as text arrives (so the typed chat
  /// thread renders progressively, not just once at the end), and
  /// [onSentence] — when given — fires once per complete sentence as
  /// soon as it's recognized in the arriving text, letting a voice
  /// caller start speaking before the full answer has finished
  /// generating. [mode] is presentation-only (see
  /// `RazConversationMode`): it never changes the reasoning behind the
  /// answer, only how much of it the backend chooses to say.
  Future<RazResponse?> ask(
    String question, {
    RazConversationMode mode = RazConversationMode.text,
    void Function(String sentence)? onSentence,
  }) {
    final trimmed = question.trim();
    if (trimmed.isEmpty || state.isLoading) return Future.value();
    return _useStreamingConversation
        ? _askStreaming(trimmed, mode: mode, onSentence: onSentence)
        : _askOnce(trimmed, mode: mode, onSentence: onSentence);
  }

  /// The active path — a single, complete, already-proven-stable
  /// request/response call. [onSentence], when given, is still called
  /// once the full answer arrives, with the complete text — real,
  /// honest behavior for a non-streaming call (not "fake streaming":
  /// nothing here claims the text arrived incrementally when it didn't;
  /// the voice caller simply speaks the one real answer it received).
  Future<RazResponse?> _askOnce(
    String trimmed, {
    required RazConversationMode mode,
    void Function(String sentence)? onSentence,
  }) async {
    final history = _recentHistory();
    state = state.copyWith(
      messages: [...state.messages, RazMessage.user(trimmed)],
      isLoading: true,
      clearError: true,
    );

    final result = await ref
        .read(razRepositoryProvider)
        .ask(audience: audience, question: trimmed, history: history, mode: mode);

    return result.fold(
      onSuccess: (response) {
        state = state.copyWith(
          messages: [...state.messages, RazMessage.raz(response)],
          isLoading: false,
        );
        if (onSentence != null && response.text.trim().isNotEmpty) {
          onSentence(response.text.trim());
        }
        return response;
      },
      onFailure: (_) {
        state = state.copyWith(
          isLoading: false,
          errorText: "Couldn't reach RAZ. Please try again.",
        );
        return null;
      },
    );
  }

  /// The streaming path — see [_useStreamingConversation]'s doc comment
  /// for why this isn't active. Left fully implemented, not deleted:
  /// the backend already supports it (`razAsk`'s `sendChunk` calls), and
  /// re-enabling this is meant to be a one-line flip once a coordinated
  /// deploy is verified safe, not a rewrite.
  Future<RazResponse?> _askStreaming(
    String trimmed, {
    required RazConversationMode mode,
    void Function(String sentence)? onSentence,
  }) async {
    final history = _recentHistory();
    state = state.copyWith(
      messages: [...state.messages, RazMessage.user(trimmed), const RazMessage.razStreaming('')],
      isLoading: true,
      clearError: true,
    );

    var textSoFar = '';
    var spokenRemainder = '';
    RazResponse? finalResponse;
    String? errorText;

    final stream = ref
        .read(razRepositoryProvider)
        .askStream(audience: audience, question: trimmed, history: history, mode: mode);

    await for (final event in stream) {
      switch (event) {
        case RazAskDelta(:final text):
          textSoFar += text;
          _replaceStreamingMessage(RazMessage.razStreaming(textSoFar));
          if (onSentence != null) {
            final split = splitCompleteSentences(spokenRemainder + text);
            for (final sentence in split.complete) {
              onSentence(sentence);
            }
            spokenRemainder = split.remainder;
          }
        case RazAskDone(:final result):
          result.fold(
            onSuccess: (response) {
              finalResponse = response;
              _replaceStreamingMessage(RazMessage.raz(response));
              if (onSentence != null && spokenRemainder.trim().isNotEmpty) {
                onSentence(spokenRemainder.trim());
              }
            },
            onFailure: (_) {
              errorText = "Couldn't reach RAZ. Please try again.";
              // Drop the failed streaming placeholder — never leave a
              // half-answered bubble on screen after an error.
              state = state.copyWith(messages: state.messages.sublist(0, state.messages.length - 1));
            },
          );
      }
    }

    state = state.copyWith(isLoading: false, errorText: errorText, clearError: errorText == null);
    return finalResponse;
  }

  /// Replaces the trailing in-progress streaming message with [updated]
  /// — always the last entry in [state.messages] while a stream is in
  /// flight, per how [ask] appends it before the loop starts.
  void _replaceStreamingMessage(RazMessage updated) {
    final messages = [...state.messages];
    messages[messages.length - 1] = updated;
    state = state.copyWith(messages: messages);
  }

  /// The last [_maxHistoryTurns] complete question/answer pairs, oldest
  /// first — mirrors `render.ts`'s own history cap so a long-running
  /// conversation doesn't grow the request unbounded.
  List<RazTurn> _recentHistory() {
    final turns = <RazTurn>[];
    String? pendingQuestion;
    for (final message in state.messages) {
      if (message.sender == RazSender.user) {
        pendingQuestion = message.text;
      } else if (pendingQuestion != null) {
        turns.add(RazTurn(question: pendingQuestion, answer: message.text));
        pendingQuestion = null;
      }
    }
    if (turns.length > _maxHistoryTurns) {
      return turns.sublist(turns.length - _maxHistoryTurns);
    }
    return turns;
  }
}

final razConversationControllerProvider = NotifierProvider.autoDispose
    .family<RazConversationController, RazConversationState, RazAudience>(
      RazConversationController.new,
    );
