import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../design_system/tokens/spacing.dart';
import '../../../../shared/models/workspace_type.dart';
import '../../../../shared/widgets/section_empty_state.dart';
import '../../domain/models/raz_message.dart';
import '../../domain/models/raz_response.dart';
import '../../domain/repositories/raz_repository.dart';
import '../controllers/raz_conversation_controller.dart';
import '../controllers/raz_voice_controller.dart';
import '../widgets/raz_awareness_card.dart';
import '../widgets/raz_message_bubble.dart';
import 'raz_voice_mode_sheet.dart';

const _playerPrompts = [
  'How did I train today?',
  'How is my recovery?',
  'What should I focus on tomorrow?',
];
const _coachPrompts = [
  'Who needs recovery?',
  'Summarise today\'s session.',
  'Show workload trends.',
];

/// RAZ's conversation screen — the secondary, optional interface to
/// Vikzar's Football Operating System (the Daily Brief is primary).
/// Every question here calls the real `razAsk` Callable and shows the
/// real `RazResponse` it returns — nothing on this screen is hardcoded
/// or simulated. Text and voice share this exact same path; the
/// microphone only ever fills the text field's send action.
class RazScreen extends ConsumerStatefulWidget {
  const RazScreen({super.key, required this.workspace});

  final WorkspaceType workspace;

  @override
  ConsumerState<RazScreen> createState() => _RazScreenState();
}

class _RazScreenState extends ConsumerState<RazScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  RazAudience get _audience =>
      widget.workspace == WorkspaceType.player ? RazAudience.player : RazAudience.coach;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text;
    if (text.trim().isEmpty) return;
    _controller.clear();
    _scrollToBottomSoon();
    await ref.read(razConversationControllerProvider(_audience).notifier).ask(text);
    _scrollToBottomSoon();
  }

  void _scrollToBottomSoon() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  /// Opens the large-mic Voice Mode overlay — [RazConversationManager]
  /// (behind [razVoiceControllerProvider]) owns the whole voice turn
  /// from there (recognizing speech, asking RAZ via the exact same
  /// [RazConversationController] this screen already watches, speaking
  /// the reply back). The message list updates itself reactively (see
  /// `build()`'s `ref.watch(razConversationControllerProvider)`) whether
  /// the sheet is open or already closed — exactly as it does for a
  /// typed question — so closing the sheet never loses anything.
  void _openVoiceMode() {
    RazVoiceModeSheet.show(context, audience: _audience);
  }

  /// The Awareness card always reflects what informed RAZ's most recent
  /// reply — never a separately-fetched "current" awareness that could
  /// drift from what the reply actually used.
  RazResponse? _lastRazResponse(List<RazMessage> messages) {
    for (final message in messages.reversed) {
      if (message.sender == RazSender.raz && message.response != null) return message.response;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Scrolls to bottom whenever a voice-originated turn adds a message
    // — the typed path already scrolls explicitly from `_send()`, but a
    // voice turn is driven entirely by `RazConversationManager` with no
    // callback back into this screen, so this listener is voice's only
    // hook to keep the thread pinned to the latest message.
    ref.listen(razConversationControllerProvider(_audience), (previous, next) {
      if (next.messages.length != previous?.messages.length) _scrollToBottomSoon();
    });
    final state = ref.watch(razConversationControllerProvider(_audience));
    final voiceState = ref.watch(razVoiceControllerProvider(_audience));
    final prompts = widget.workspace == WorkspaceType.player ? _playerPrompts : _coachPrompts;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('RAZ')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: state.messages.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(SpacingTokens.space24),
                        child: SectionEmptyState(
                          icon: Symbols.self_improvement,
                          headline: 'Ask RAZ anything about your data.',
                          body: prompts.join('   ·   '),
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(SpacingTokens.space16),
                      itemCount: state.messages.length,
                      itemBuilder: (context, index) {
                        final message = state.messages[index];
                        return RazMessageBubble(
                          message: message,
                          onSpeak: message.sender == RazSender.raz
                              ? (text) =>
                                    ref.read(razVoiceControllerProvider(_audience).notifier).speak(text)
                              : null,
                        );
                      },
                    ),
            ),
            if (state.isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: SpacingTokens.space8),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            if (state.errorText != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: SpacingTokens.space16),
                child: Text(
                  state.errorText!,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                ),
              ),
            if (voiceState.lastError != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: SpacingTokens.space16),
                child: Text(
                  voiceState.lastError!,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                ),
              ),
            if (_lastRazResponse(state.messages) case final response?)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  SpacingTokens.space16,
                  0,
                  SpacingTokens.space16,
                  SpacingTokens.space16,
                ),
                child: RazAwarenessCard(
                  awareness: response.awareness,
                  confidence: response.confidence,
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(SpacingTokens.space16),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _openVoiceMode,
                    icon: Icon(
                      voiceState.isListening ? Symbols.mic : Symbols.mic_none,
                      color: voiceState.isListening ? theme.colorScheme.error : null,
                    ),
                    tooltip: 'Ask by voice',
                  ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      enabled: !state.isLoading,
                      decoration: const InputDecoration(hintText: 'Ask RAZ…'),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  IconButton(
                    onPressed: state.isLoading ? null : _send,
                    icon: const Icon(Symbols.send),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
