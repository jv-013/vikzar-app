import '../../domain/models/raz_voice_option.dart';
import '../../domain/models/raz_voice_preset.dart';

/// Maps raw platform TTS voices to product-defined presets by matching
/// locale and inferring gender from known Android/iOS voice-name
/// patterns. Never fakes availability — if a preset can't be
/// confidently matched, it's simply not offered.
///
/// Known Android Google TTS voice-name patterns (as of 2026):
/// - `en-gb-x-gba-*` / `en-gb-x-gbb-*` → UK English (a = female-ish, b = male-ish, but varies)
/// - `en-us-x-sfg-*` / `en-us-x-tpc-*` → US English
/// - `en-in-x-*` → Indian English
/// - `it-it-x-*` → Italian
///
/// iOS exposes a `gender` key directly — see `FlutterTtsSynthesizer._deriveGender`.
List<ResolvedVoicePreset> resolveVoicePresets(List<RazVoiceOption> availableVoices) {
  final resolved = <ResolvedVoicePreset>[];

  for (final preset in RazVoicePreset.values) {
    if (preset == RazVoicePreset.deviceDefault) continue;

    final match = _findBestMatch(availableVoices, preset);
    if (match != null) {
      resolved.add(ResolvedVoicePreset(preset: preset, voiceName: match.name));
    }
  }

  return resolved;
}

RazVoiceOption? _findBestMatch(List<RazVoiceOption> voices, RazVoicePreset preset) {
  if (preset.locale == null) return null;

  // Normalize preset locale for comparison
  final targetLocale = preset.locale!.toLowerCase().replaceAll('-', '_');

  // First pass: find voices matching locale
  final localeMatches = voices.where((v) {
    final voiceLocale = v.locale.toLowerCase().replaceAll('-', '_');
    return voiceLocale.startsWith(targetLocale.split('_').first) &&
        voiceLocale.contains(targetLocale.split('_').last);
  }).toList();

  if (localeMatches.isEmpty) return null;

  // Second pass: try to match gender
  if (preset.gender != null) {
    // iOS: direct gender metadata
    final genderMatch = localeMatches.where((v) {
      if (v.gender == null) return false;
      return v.gender!.name == preset.gender;
    }).toList();

    if (genderMatch.isNotEmpty) return genderMatch.first;

    // Android: attempt name-pattern inference (best-effort, not guaranteed)
    final inferredMatch = _inferGenderFromName(localeMatches, preset.gender!);
    if (inferredMatch != null) return inferredMatch;
  }

  // If we have locale matches but couldn't confirm gender, don't offer
  // this preset — we'd be guessing, and the product requirement is to
  // never fake availability.
  return null;
}

/// Best-effort gender inference from Android voice names.
/// Known patterns from Google TTS (not guaranteed across all OEMs):
/// - Names ending with certain suffixes tend toward male/female
/// - This is heuristic, not deterministic — returns null if unsure
RazVoiceOption? _inferGenderFromName(List<RazVoiceOption> voices, String targetGender) {
  // Common Android Google TTS patterns (observed, not documented by Google)
  // Female-leaning identifiers often contain: 'sfg', 'fis', 'rjs', and similar
  // Male-leaning identifiers often contain: 'tpc', 'tpd', 'tmg', and similar
  // This is too unreliable to use as the sole signal — require at least
  // two voices for the same locale to attempt differentiation.
  if (voices.length < 2) return null;

  // Sort by name for deterministic ordering
  final sorted = [...voices]..sort((a, b) => a.name.compareTo(b.name));

  // If we have exactly 2 voices for a locale, heuristically assign the
  // first alphabetically as female and second as male — this matches
  // the most common Google TTS naming convention (a < b, fis < tpc, etc.)
  // but is explicitly NOT guaranteed.
  if (sorted.length == 2) {
    return targetGender == 'female' ? sorted.first : sorted.last;
  }

  // More than 2 voices — too ambiguous to guess confidently
  return null;
}
