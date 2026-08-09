/// Mirrors `functions/src/lib/intelligence/types.ts`'s `RazResponse` —
/// the Structured Response RAZ's backend pipeline returns. Nothing on
/// the Flutter side ever calls Gemini directly; this is the only shape
/// the app ever receives from it.
library;

enum RazConfidence {
  high,
  moderate,
  low;

  static RazConfidence fromName(String? name) {
    for (final value in RazConfidence.values) {
      if (value.name == name) return value;
    }
    return RazConfidence.low;
  }
}

class RazHighlight {
  const RazHighlight({required this.label, required this.value});

  final String label;
  final String value;

  factory RazHighlight.fromMap(Map<String, dynamic> data) {
    return RazHighlight(
      label: data['label'] as String? ?? '',
      value: data['value'] as String? ?? '',
    );
  }
}

/// A distinct block of a Daily Brief (Performance/Recovery/Focus for a
/// player; Team Brief/Needs Attention/Upcoming Sessions/Recent Alerts
/// for a coach). Empty for a plain `razAsk` reply.
class RazSection {
  const RazSection({required this.label, required this.body});

  final String label;
  final String body;

  factory RazSection.fromMap(Map<String, dynamic> data) {
    return RazSection(
      label: data['label'] as String? ?? '',
      body: data['body'] as String? ?? '',
    );
  }
}

/// One data source RAZ's Awareness card can show — "Player Data",
/// "Pods", "EMG", etc. Mirrors `AwarenessSource` in
/// `razHardwareContext.ts`.
class RazAwarenessSource {
  const RazAwarenessSource({required this.key, required this.label, required this.active});

  final String key;
  final String label;
  final bool active;

  factory RazAwarenessSource.fromMap(Map<String, dynamic> data) {
    return RazAwarenessSource(
      key: data['key'] as String? ?? '',
      label: data['label'] as String? ?? '',
      active: data['active'] as bool? ?? false,
    );
  }
}

/// Hardware upgrades RAZ, it never activates it — `level` is always 0
/// (fully served) unless real hardware is genuinely connected and
/// streaming. Mirrors `HardwareAwareness` in `razHardwareContext.ts`.
class RazAwareness {
  const RazAwareness({required this.level, this.sources = const []});

  final int level;
  final List<RazAwarenessSource> sources;

  List<RazAwarenessSource> get active => sources.where((s) => s.active).toList();

  factory RazAwareness.fromMap(Map<String, dynamic>? data) {
    if (data == null) return const RazAwareness(level: 0);
    final sourcesRaw = data['sources'] as List<dynamic>? ?? const [];
    return RazAwareness(
      level: (data['level'] as num?)?.toInt() ?? 0,
      sources: [
        for (final entry in sourcesRaw) RazAwarenessSource.fromMap(entry as Map<String, dynamic>),
      ],
    );
  }
}

class RazResponse {
  const RazResponse({
    required this.text,
    this.sections = const [],
    this.highlights = const [],
    required this.confidence,
    this.traceRefs = const [],
    this.awareness = const RazAwareness(level: 0),
  });

  final String text;
  final List<RazSection> sections;
  final List<RazHighlight> highlights;
  final RazConfidence confidence;
  final List<String> traceRefs;
  final RazAwareness awareness;

  factory RazResponse.fromMap(Map<String, dynamic> data) {
    final sectionsRaw = data['sections'] as List<dynamic>? ?? const [];
    final highlightsRaw = data['highlights'] as List<dynamic>? ?? const [];
    final traceRefsRaw = data['traceRefs'] as List<dynamic>? ?? const [];
    return RazResponse(
      text: data['text'] as String? ?? '',
      sections: [
        for (final entry in sectionsRaw) RazSection.fromMap(entry as Map<String, dynamic>),
      ],
      highlights: [
        for (final entry in highlightsRaw) RazHighlight.fromMap(entry as Map<String, dynamic>),
      ],
      confidence: RazConfidence.fromName(data['confidence'] as String?),
      traceRefs: traceRefsRaw.cast<String>(),
      awareness: RazAwareness.fromMap(data['awareness'] as Map<String, dynamic>?),
    );
  }
}
