import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../domain/models/raz_voice_option.dart';
import '../../domain/repositories/raz_speech_synthesizer.dart';
import '../../domain/utils/raz_text_utils.dart';

/// The one real [RazSpeechSynthesizer] implementation today — wraps
/// `flutter_tts`. Resolved exclusively through
/// `raz_speech_providers.dart`'s `routeToSpeechSynthesizer()`.
///
/// Natural pauses between sentences come from sequential,
/// `awaitSpeakCompletion`-gated `speak()` calls — each call's Future
/// only resolves once that sentence's audio finishes, so the gap
/// between one resolving and the next starting is a real, audible
/// pause. This is the honest substitute for SSML `<break>` tags, which
/// `flutter_tts` doesn't expose reliably across platforms.
class FlutterTtsSynthesizer implements RazSpeechSynthesizer {
  FlutterTtsSynthesizer([FlutterTts? tts]) : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;
  bool _isSpeaking = false;
  bool _configured = false;
  int _generation = 0;

  @override
  bool get isSpeaking => _isSpeaking;

  @override
  Future<void> speak(String text) async {
    await stop();
    final cleaned = stripSpeechFormatting(text);
    if (cleaned.isEmpty) return;

    final generation = ++_generation;
    _isSpeaking = true;
    try {
      for (final sentence in splitIntoSentences(cleaned)) {
        if (generation != _generation) return; // superseded or stopped
        await _speakRaw(sentence);
      }
    } finally {
      if (generation == _generation) _isSpeaking = false;
    }
  }

  @override
  Future<void> speakSentence(String sentence) async {
    // Deliberately no `stop()` here — see this method's own doc comment
    // on `RazSpeechSynthesizer`. The caller (`RazConversationManager`)
    // stops once, before the first sentence of a streamed turn, and
    // owns sequencing (awaiting each call before enqueueing the next)
    // and the turn's overall speaking/idle state — this method's only
    // job is speaking the one sentence it's given. Real interruption
    // still works exactly as it does for `speak()`: `stop()` calls the
    // platform's own `_tts.stop()`, which resolves any in-flight
    // `_tts.speak()` early, per `awaitSpeakCompletion`.
    final cleaned = stripSpeechFormatting(sentence);
    if (cleaned.isEmpty) return;
    _isSpeaking = true;
    await _speakRaw(cleaned);
  }

  Future<void> _speakRaw(String sentence) async {
    if (!_configured) {
      // Deliberately lazy, not in the constructor — a constructor with
      // an async platform side effect makes the class impossible to
      // safely construct (or unit-test) without a live platform channel
      // already wired up.
      await _tts.awaitSpeakCompletion(true);
      _configured = true;
    }
    await _tts.speak(sentence);
  }

  @override
  Future<void> stop() async {
    _generation++; // invalidates any in-flight sentence loop
    _isSpeaking = false;
    await _tts.stop();
  }

  @override
  Future<void> setRate(double rate) => _tts.setSpeechRate(rate).then((_) {});

  @override
  Future<void> setVolume(double volume) => _tts.setVolume(volume).then((_) {});

  @override
  Future<List<RazVoiceOption>> availableVoices() async {
    try {
      final raw = await _tts.getVoices;
      if (raw is! List) return const [];
      return raw
          .whereType<Map<dynamic, dynamic>>()
          .map(_toVoiceOption)
          .whereType<RazVoiceOption>()
          // English only — RAZ has no localization infrastructure yet
          // (see `RazVoiceSettings`'s own doc comment); offering a
          // voice whose language RAZ never actually speaks in would be
          // a picker entry that quietly does nothing useful.
          .where((voice) => voice.locale.toLowerCase().startsWith('en'))
          .toList();
    } catch (error, stackTrace) {
      // A platform/plugin failure here must never crash Settings — the
      // picker simply has nothing to offer, same as "no voices
      // installed" would look like to a caller.
      if (kDebugMode) {
        debugPrint('[VIKZAR_TTS] availableVoices() failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      return const [];
    }
  }

  RazVoiceOption? _toVoiceOption(Map<dynamic, dynamic> raw) {
    final name = raw['name'] as String?;
    final locale = raw['locale'] as String?;
    if (name == null || locale == null) return null;
    return RazVoiceOption(name: name, locale: locale, gender: _deriveGender(raw));
  }

  /// The only real signal available: iOS's `getVoices` includes a
  /// `gender` key directly (`flutter_tts`'s own doc comment confirms
  /// this is iOS-specific). Android's platform channel returns just
  /// `name`/`locale` — no gender field exists to read, so this
  /// correctly returns `null` there rather than guessing one from the
  /// voice name, which Android doesn't document or guarantee any
  /// stable convention for.
  RazVoiceGender? _deriveGender(Map<dynamic, dynamic> raw) {
    final value = (raw['gender'] as String?)?.toLowerCase();
    return switch (value) {
      'male' => RazVoiceGender.male,
      'female' => RazVoiceGender.female,
      _ => null,
    };
  }

  @override
  Future<void> setVoice(RazVoiceOption voice) async {
    try {
      await _tts.setVoice({'name': voice.name, 'locale': voice.locale});
    } catch (error) {
      // Never throws past this boundary — see this method's own doc
      // comment on `RazSpeechSynthesizer`: a rejected/uninstalled voice
      // falls back to whatever was already selected, silently.
      if (kDebugMode) debugPrint('[VIKZAR_TTS] setVoice(${voice.name}) failed: $error');
    }
  }
}
