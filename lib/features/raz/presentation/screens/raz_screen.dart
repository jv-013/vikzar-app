import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../design_system/tokens/spacing.dart';
import '../../../../shared/models/workspace_type.dart';
import '../../data/providers/raz_speech_providers.dart';
import '../../domain/models/raz_message.dart';
import '../../domain/models/raz_response.dart';
import '../../domain/repositories/raz_repository.dart';
import '../../domain/repositories/raz_voice_permissions.dart';
import '../controllers/raz_conversation_controller.dart';
import '../controllers/raz_voice_controller.dart';
import '../widgets/raz_awareness_card.dart';
import '../widgets/raz_message_bubble.dart';
import '../widgets/raz_mic_pulse.dart';
import '../widgets/raz_orb.dart';

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
/// or simulated.
///
/// **RC2.1:** Major UX changes:
/// - RAZ Orb replaces the empty-state icon as the visual identity.
/// - One-tap mic: tapping mic immediately starts listening (no more
///   intermediate Voice Mode Sheet).
/// - "New Conversation" action in the AppBar.
/// - Conversation persists across navigation.
/// - Voice state caption below the orb.
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

  /// **RC2.1:** One-tap mic — immediately starts listening. No more
  /// intermediate Voice Mode Sheet.
  void _onMicTap() {
    final voice = ref.read(razVoiceControllerProvider(_audience).notifier);
    final voiceState = ref.read(razVoiceControllerProvider(_audience));

    if (voiceState.isSpeaking) {
      voice.stopSpeaking();
    } else if (voiceState.isListening) {
      voice.stopListening();
    } else {
      voice.startListening();
    }
  }

  void _newConversation() {
    ref.read(razConversationControllerProvider(_audience).notifier).clearConversation();
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

  RazOrbState _orbStateFrom(RazVoiceState voiceState) {
    if (voiceState.lastError != null) return RazOrbState.error;
    if (voiceState.isListening) return RazOrbState.listening;
    if (voiceState.isThinking) return RazOrbState.thinking;
    if (voiceState.isSpeaking) return RazOrbState.speaking;
    if (voiceState.wakeWordListening) return RazOrbState.wakeWordListening;
    return RazOrbState.idle;
  }

  String _captionFor(RazVoiceState voiceState) {
    if (voiceState.lastError != null) return voiceState.lastError!;
    if (voiceState.isThinking && voiceState.thinkingLabel.isNotEmpty) {
      return voiceState.thinkingLabel;
    }
    if (voiceState.isListening) {
      return voiceState.captionText.isNotEmpty ? voiceState.captionText : "I'm listening…";
    }
    if (voiceState.isSpeaking) return 'Speaking…';
    if (voiceState.wakeWordListening) return 'Say "Hey Raz"';
    return 'Hey, ask me anything.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    ref.listen(razConversationControllerProvider(_audience), (previous, next) {
      if (next.messages.length != previous?.messages.length) _scrollToBottomSoon();
    });
    final state = ref.watch(razConversationControllerProvider(_audience));
    final voiceState = ref.watch(razVoiceControllerProvider(_audience));
    final prompts = widget.workspace == WorkspaceType.player ? _playerPrompts : _coachPrompts;
    final orbState = _orbStateFrom(voiceState);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('RAZ'),
        actions: [
          if (state.messages.isNotEmpty)
            IconButton(
              onPressed: _newConversation,
              icon: const Icon(Symbols.add_comment),
              tooltip: 'New conversation',
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: state.messages.isEmpty
                  ? _buildEmptyState(theme, voiceState, orbState, prompts)
                  : _buildConversation(theme, state, voiceState, orbState),
            ),
            // Error messages
            if (state.errorText != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: SpacingTokens.space16),
                child: Text(
                  state.errorText!,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                ),
              ),
            // Permission denied action
            if (voiceState.permissionStatus == RazPermissionStatus.permanentlyDenied)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: SpacingTokens.space16),
                child: TextButton(
                  onPressed: () => ref.read(razVoicePermissionsProvider).openSettings(),
                  child: const Text('Open Settings to enable microphone'),
                ),
              ),
            // Input bar
            _buildInputBar(theme, state, voiceState),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(
    ThemeData theme,
    RazVoiceState voiceState,
    RazOrbState orbState,
    List<String> prompts,
  ) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(SpacingTokens.space24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            RazOrb(state: orbState, onTap: _onMicTap),
            const SizedBox(height: SpacingTokens.space16),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(
                _captionFor(voiceState),
                key: ValueKey(_captionFor(voiceState)),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: voiceState.lastError != null
                      ? theme.colorScheme.error
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: SpacingTokens.space24),
            Wrap(
              spacing: SpacingTokens.space8,
              runSpacing: SpacingTokens.space8,
              alignment: WrapAlignment.center,
              children: [
                for (final prompt in prompts)
                  ActionChip(
                    label: Text(prompt, style: theme.textTheme.bodySmall),
                    onPressed: () {
                      _controller.text = prompt;
                      _send();
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConversation(
    ThemeData theme,
    RazConversationState state,
    RazVoiceState voiceState,
    RazOrbState orbState,
  ) {
    final lastResponse = _lastRazResponse(state.messages);

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(SpacingTokens.space16),
      itemCount: state.messages.length +
          (state.isLoading ? 1 : 0) +
          (lastResponse != null ? 1 : 0) +
          1, // +1 for orb header
      itemBuilder: (context, index) {
        // Orb header at the top of the conversation
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: SpacingTokens.space16),
            child: Column(
              children: [
                RazOrb(state: orbState, size: 80, onTap: _onMicTap),
                const SizedBox(height: SpacingTokens.space8),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    _captionFor(voiceState),
                    key: ValueKey(_captionFor(voiceState)),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: voiceState.lastError != null
                          ? theme.colorScheme.error
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        final messageIndex = index - 1;

        // Message bubbles
        if (messageIndex < state.messages.length) {
          final message = state.messages[messageIndex];
          return RazMessageBubble(
            message: message,
            onSpeak: message.sender == RazSender.raz
                ? (text) => ref.read(razVoiceControllerProvider(_audience).notifier).speak(text)
                : null,
          );
        }

        // Loading indicator
        if (state.isLoading && messageIndex == state.messages.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: SpacingTokens.space8),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        // Awareness card
        if (lastResponse != null) {
          return Padding(
            padding: const EdgeInsets.only(top: SpacingTokens.space8),
            child: RazAwarenessCard(
              awareness: lastResponse.awareness,
              confidence: lastResponse.confidence,
            ),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildInputBar(ThemeData theme, RazConversationState state, RazVoiceState voiceState) {
    final micVisualState = switch ((
      voiceState.isListening,
      voiceState.isThinking,
      voiceState.isSpeaking,
      voiceState.lastError != null,
      voiceState.wakeWordListening,
    )) {
      (true, _, _, _, _) => RazMicPulseVisualState.listening,
      (_, true, _, _, _) => RazMicPulseVisualState.thinking,
      (_, _, true, _, _) => RazMicPulseVisualState.speaking,
      (_, _, _, true, _) => RazMicPulseVisualState.error,
      (_, _, _, _, true) => RazMicPulseVisualState.wakeWordListening,
      _ => RazMicPulseVisualState.idle,
    };

    return Padding(
      padding: const EdgeInsets.all(SpacingTokens.space16),
      child: Row(
        children: [
          RazMicPulse(
            visualState: micVisualState,
            onTap: _onMicTap,
          ),
          const SizedBox(width: SpacingTokens.space8),
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
    );
  }
}
