import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../design_system/components/vikzar_bottom_sheet.dart';
import '../../../../design_system/tokens/spacing.dart';
import '../../data/providers/raz_speech_providers.dart';
import '../../domain/models/raz_message.dart';
import '../../domain/models/raz_response.dart';
import '../../domain/repositories/raz_repository.dart';
import '../../domain/repositories/raz_voice_permissions.dart';
import '../controllers/raz_conversation_controller.dart';
import '../controllers/raz_voice_controller.dart';
import '../widgets/raz_awareness_card.dart';
import '../widgets/raz_mic_pulse.dart';

/// The premium, large-mic voice interaction surface — opened from the
/// existing mic button, layered *over* [RazScreen] rather than
/// replacing it. Reads the exact same [razConversationControllerProvider]
/// and [razVoiceControllerProvider] instances the underlying screen
/// does, so closing this sheet returns to the identical scrolled
/// conversation thread — never a fresh one. The player should never
/// feel they're restarting from zero.
class RazVoiceModeSheet extends ConsumerWidget {
  const RazVoiceModeSheet({super.key, required this.audience});

  final RazAudience audience;

  static Future<void> show(BuildContext context, {required RazAudience audience}) {
    return VikzarBottomSheet.show<void>(
      context,
      builder: (context) => RazVoiceModeSheet(audience: audience),
    );
  }

  RazResponse? _lastRazResponse(List<RazMessage> messages) {
    for (final message in messages.reversed) {
      if (message.sender == RazSender.raz && message.response != null) return message.response;
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final voiceState = ref.watch(razVoiceControllerProvider(audience));
    final conversationState = ref.watch(razConversationControllerProvider(audience));
    final voice = ref.read(razVoiceControllerProvider(audience).notifier);
    final lastResponse = _lastRazResponse(conversationState.messages);

    final visualState = switch ((voiceState.isListening, voiceState.isThinking, voiceState.isSpeaking)) {
      (true, _, _) => RazMicPulseVisualState.listening,
      (_, true, _) => RazMicPulseVisualState.thinking,
      (_, _, true) => RazMicPulseVisualState.speaking,
      _ => RazMicPulseVisualState.idle,
    };

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          SpacingTokens.space20,
          SpacingTokens.space16,
          SpacingTokens.space20,
          SpacingTokens.space24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: const Icon(Symbols.close),
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
            const SizedBox(height: SpacingTokens.space16),
            RazMicPulse(
              visualState: visualState,
              onTap: () {
                if (voiceState.isSpeaking) {
                  voice.stopSpeaking();
                } else if (voiceState.isListening) {
                  voice.stopListening();
                } else {
                  voice.startListening();
                }
              },
            ),
            const SizedBox(height: SpacingTokens.space20),
            if (voiceState.permissionStatus == RazPermissionStatus.permanentlyDenied) ...[
              Text(
                voiceState.lastError ?? 'Microphone access is off.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error),
              ),
              const SizedBox(height: SpacingTokens.space8),
              TextButton(
                onPressed: () => ref.read(razVoicePermissionsProvider).openSettings(),
                child: const Text('Open Settings'),
              ),
            ] else if (voiceState.lastError != null) ...[
              Text(
                voiceState.lastError!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error),
              ),
            ] else ...[
              Text(
                _captionFor(voiceState, visualState),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
            ],
            if (lastResponse != null) ...[
              const SizedBox(height: SpacingTokens.space20),
              RazAwarenessCard(awareness: lastResponse.awareness, confidence: lastResponse.confidence),
              const SizedBox(height: SpacingTokens.space8),
              TextButton.icon(
                onPressed: () => voice.replay(lastResponse.text),
                icon: const Icon(Symbols.replay, size: 18),
                label: const Text('Replay'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// [RazVoiceState.thinkingLabel] takes priority while thinking — a
  /// real status ("Checking your data…"), not the leftover question
  /// text sitting in [RazVoiceState.captionText] from the listen
  /// session that just ended. Every other state shows the live/last
  /// caption text if there is one, falling back to a static prompt.
  String _captionFor(RazVoiceState voiceState, RazMicPulseVisualState visualState) {
    if (voiceState.isThinking && voiceState.thinkingLabel.isNotEmpty) {
      return voiceState.thinkingLabel;
    }
    if (voiceState.captionText.isNotEmpty) return voiceState.captionText;
    return switch (visualState) {
      RazMicPulseVisualState.idle => 'Tap to talk to RAZ.',
      RazMicPulseVisualState.listening => "I'm listening…",
      RazMicPulseVisualState.thinking => '',
      RazMicPulseVisualState.speaking => '',
    };
  }
}
