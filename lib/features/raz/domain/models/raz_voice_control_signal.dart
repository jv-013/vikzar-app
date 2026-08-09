/// What a transcript means for `RazConversationManager`'s turn-taking —
/// decided by a fixed, deterministic keyword table, **never** an LLM or
/// intent classifier. This is the same "no LLM, deterministic phrasing"
/// philosophy `razNotificationEngine.ts` already uses server-side, for
/// a different reason (there: latency/cost; here: never letting voice
/// bypass `RazEngine` even for something as small as deciding whether to
/// cancel).
enum RazVoiceControlSignal {
  /// The user wants RAZ to stop talking, and said nothing else worth
  /// forwarding — e.g. "stop" while RAZ is speaking.
  stopSpeaking,

  /// The user wants to replace a request that's still in flight — e.g.
  /// "actually, how's my recovery instead" while a previous question
  /// hasn't answered yet.
  cancelPending,

  /// A bare control word with nothing in flight and nothing speaking —
  /// nothing to cancel, and not a real question either.
  ignore,

  /// An ordinary question — forward to RAZ exactly as today.
  forward,
}

const _stopWords = {'stop', 'wait', 'hold on', 'never mind'};
const _replaceWords = {'actually'};

/// Pure, exhaustively testable — the entire turn-taking "brain" boils
/// down to this. [isSpeaking]/[askInFlight] are read at the moment the
/// transcript arrives; this function makes no assumption about *why*
/// either is true.
RazVoiceControlSignal classifyVoiceTranscript(
  String transcript, {
  required bool isSpeaking,
  required bool askInFlight,
}) {
  final normalized = transcript.trim().toLowerCase();
  final isBareStopWord = _stopWords.contains(normalized);
  final startsWithStopWord = _stopWords.any(normalized.startsWith);
  final startsWithReplaceWord = _replaceWords.any(normalized.startsWith);

  if (startsWithStopWord && (isSpeaking || askInFlight)) {
    return isSpeaking ? RazVoiceControlSignal.stopSpeaking : RazVoiceControlSignal.cancelPending;
  }
  if (startsWithReplaceWord && askInFlight) return RazVoiceControlSignal.cancelPending;
  if (isBareStopWord && !isSpeaking && !askInFlight) return RazVoiceControlSignal.ignore;
  return RazVoiceControlSignal.forward;
}
