import 'raz_response.dart';

enum RazSender { user, raz }

/// One turn in an on-screen conversation with RAZ. Held entirely in
/// local Riverpod state — each backend call is already a self-contained
/// request (see `render.ts`'s history handling), so a fresh screen
/// means a fresh thread, the same way most assistant-style chat
/// surfaces behave.
class RazMessage {
  const RazMessage.user(this.text)
    : sender = RazSender.user,
      response = null,
      isStreaming = false;

  RazMessage.raz(RazResponse response)
    : sender = RazSender.raz,
      text = response.text,
      response = response,
      isStreaming = false;

  /// An in-progress RAZ reply — [text] grows as more of
  /// [RazAskDelta]s arrive; [response] is null until the stream
  /// completes (see [RazConversationController.ask]'s streaming path).
  /// [RazMessageBubble] already renders correctly with no `response`
  /// (its footer — highlights, confidence, speak button — only ever
  /// appears once one exists), so a streaming message needs no special
  /// UI case, only this state to be in.
  const RazMessage.razStreaming(this.text)
    : sender = RazSender.raz,
      response = null,
      isStreaming = true;

  final RazSender sender;
  final String text;
  final RazResponse? response;
  final bool isStreaming;
}
