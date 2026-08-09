/// Small, pure text helpers shared by anything that turns RAZ's text
/// into speech or speech-paced chunks — the synthesizer (speaking a
/// complete answer) and the streaming conversation controller (deciding
/// when enough of an in-flight answer has arrived to speak the next
/// sentence) both need the exact same sentence-boundary rule, so it
/// lives here once rather than drifting between two copies.
library;

/// Strips markdown/formatting characters before speech — RAZ's
/// `RazResponse.text` is plain LLM prose today (verified: nothing in
/// `razConversation.ts` asks the model for markdown), but that's not a
/// contractual guarantee against a future prompt tweak or model swap
/// ever emitting `**bold**`/`- bullets`/`# headings`. Cheap, permanent
/// insurance against ever reading formatting characters aloud verbatim.
String stripSpeechFormatting(String text) {
  return text
      .replaceAll(RegExp(r'[*_`#]+'), '')
      .replaceAll(RegExp(r'^\s*-\s+', multiLine: true), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

final _sentenceBoundary = RegExp(r'(?<=[.!?])\s+');

/// Splits into sentences for sequential, naturally-paced playback — a
/// simple punctuation-based split, not a full NLP sentence tokenizer,
/// since RAZ's prose is short, deterministic-punctuation English.
List<String> splitIntoSentences(String text) {
  return text.split(_sentenceBoundary).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
}

/// Given text accumulated so far from a stream, returns the complete
/// sentences ready to speak/render and the remaining incomplete tail to
/// keep buffering. A "complete" sentence is everything up to and
/// including the last sentence-ending punctuation found — text after
/// that (a sentence still arriving) is never split off early, so a
/// caller never speaks/flushes a fragment.
({List<String> complete, String remainder}) splitCompleteSentences(String textSoFar) {
  final lastBoundary = _lastSentenceEnd(textSoFar);
  if (lastBoundary == -1) return (complete: const [], remainder: textSoFar);
  final readyText = textSoFar.substring(0, lastBoundary + 1);
  final remainder = textSoFar.substring(lastBoundary + 1);
  return (complete: splitIntoSentences(readyText), remainder: remainder);
}

int _lastSentenceEnd(String text) {
  for (var i = text.length - 1; i >= 0; i--) {
    final char = text[i];
    if (char == '.' || char == '!' || char == '?') return i;
  }
  return -1;
}
