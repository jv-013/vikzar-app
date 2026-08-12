import '../repositories/raz_voice_permissions.dart';

/// The voice UI's entire visual state, in one place — what the RAZ Orb
/// and caption render, and what `RazVoiceController` exposes to widgets
/// via `ref.watch`. Populated by `RazConversationManager`, never mutated
/// directly by a widget.
///
/// **RC2.1:** Added `wakeWordListening` for the passive-detection visual
/// state (distinct from active listening), and explicit error states for
/// the RAZ Orb visual system.
class RazVoiceState {
  const RazVoiceState({
    this.isListening = false,
    this.isThinking = false,
    this.isSpeaking = false,
    this.wakeWordArmed = false,
    this.wakeWordListening = false,
    this.permissionStatus,
    this.captionText = '',
    this.thinkingLabel = '',
    this.lastError,
  });

  final bool isListening;

  /// `true` while a question is in flight (`RazConversationController`
  /// hasn't resolved `ask()` yet) — distinct from [isListening], since
  /// the mic is closed again by the time RAZ is "thinking."
  final bool isThinking;
  final bool isSpeaking;

  /// The wake-word engine has been initialized and is ready to detect.
  final bool wakeWordArmed;

  /// The wake-word engine is actively processing audio frames right now.
  /// Distinct from [wakeWordArmed]: armed means ready; listening means
  /// the microphone is actively being used by the wake-word detector.
  /// Used by the RAZ Orb to show a subtle passive-awareness state.
  final bool wakeWordListening;

  /// `null` until the first permission check/request happens.
  final RazPermissionStatus? permissionStatus;

  /// The current partial transcript while listening, or the last
  /// spoken/heard text once a turn completes — what a caption label
  /// shows beneath the RAZ Orb.
  final String captionText;

  /// What to show while [isThinking] — one real, honest sentence
  /// describing what's actually happening (RAZ is genuinely gathering
  /// this athlete's data before the model call), never a rotating set
  /// of phrases invented purely to look busy. Empty when not thinking.
  final String thinkingLabel;

  final String? lastError;

  RazVoiceState copyWith({
    bool? isListening,
    bool? isThinking,
    bool? isSpeaking,
    bool? wakeWordArmed,
    bool? wakeWordListening,
    RazPermissionStatus? permissionStatus,
    String? captionText,
    String? thinkingLabel,
    String? lastError,
    bool clearError = false,
  }) {
    return RazVoiceState(
      isListening: isListening ?? this.isListening,
      isThinking: isThinking ?? this.isThinking,
      isSpeaking: isSpeaking ?? this.isSpeaking,
      wakeWordArmed: wakeWordArmed ?? this.wakeWordArmed,
      wakeWordListening: wakeWordListening ?? this.wakeWordListening,
      permissionStatus: permissionStatus ?? this.permissionStatus,
      captionText: captionText ?? this.captionText,
      thinkingLabel: thinkingLabel ?? this.thinkingLabel,
      lastError: clearError ? null : (lastError ?? this.lastError),
    );
  }
}
