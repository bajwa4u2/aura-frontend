/// AURA TRACE — the client model.
///
///     DON'T ASK PEOPLE TO TRUST A LABEL. SHOW THEM THE TRACE.
///
/// TR is a minimal signal: there is meaningful Trace information about this
/// content. The product begins after a person opens it, and what they meet must
/// answer, in ordinary language — what does Aura know, what does it mean, how
/// does Aura know it, what happened to this content, and what is still unknown.
///
/// ## WHAT THIS LAYER MAY NOT DO
///
/// It performs NO reasoning and NO curation. The server has already resolved
/// the public account: the headline, the ordering, the evidence wording and the
/// history are decided there. This parses and renders them.
///
/// That is deliberate. A client that re-derived any of it would become a second
/// authority, and two authorities on the same question eventually disagree —
/// usually on the object where it matters most. There is no code here that can
/// promote, combine or summarise evidence, and `available` is read, never
/// computed.
///
/// ## OBJECT-TYPE INDEPENDENT BY CONSTRUCTION
///
/// Nothing below mentions media. One model serves posts, messages, articles and
/// photographs, because a person opening TR is asking the same question of all
/// of them and a second model would be a second place for the rules to drift.
library;

/// How much surface the evidence deserves.
///
/// The container follows the evidence. A single fact must not be given a
/// near-full-screen panel merely because the component supports one.
enum TraceDensity { simple, rich }

TraceDensity traceDensityFrom(String? wire) =>
    (wire ?? '').trim().toUpperCase() == 'RICH'
        ? TraceDensity.rich
        : TraceDensity.simple;

/// One line of what Aura holds.
class TraceEvidenceLine {
  const TraceEvidenceLine({required this.label, this.detail});

  final String label;
  final String? detail;

  static TraceEvidenceLine? tryFromJson(dynamic raw) {
    if (raw is! Map) return null;
    final m = Map<String, dynamic>.from(raw);
    final label = (m['label'] ?? '').toString().trim();
    // A line with nothing to say is not a line. Rendering an empty row would
    // suggest Aura knows something it cannot express.
    if (label.isEmpty) return null;
    final detail = (m['detail'] ?? '').toString().trim();
    return TraceEvidenceLine(
      label: label,
      detail: detail.isEmpty ? null : detail,
    );
  }
}

/// One step in what happened to the object.
class TraceHistoryStep {
  const TraceHistoryStep({
    required this.title,
    required this.basis,
    this.detail,
  });

  final String title;
  final String? detail;

  /// How Aura holds this step — the public evidence label, never the internal
  /// class name.
  final String basis;

  static TraceHistoryStep? tryFromJson(dynamic raw) {
    if (raw is! Map) return null;
    final m = Map<String, dynamic>.from(raw);
    final title = (m['title'] ?? '').toString().trim();
    if (title.isEmpty) return null;
    final detail = (m['detail'] ?? '').toString().trim();
    final basis = (m['basis'] ?? '').toString().trim();
    return TraceHistoryStep(
      title: title,
      detail: detail.isEmpty ? null : detail,
      basis: basis,
    );
  }
}

/// Who published it. Never who made it.
class TracePublication {
  const TracePublication({this.by, this.forInstitution});

  final String? by;
  final String? forInstitution;

  bool get isEmpty => (by ?? '').isEmpty && (forInstitution ?? '').isEmpty;

  static TracePublication? tryFromJson(dynamic raw) {
    if (raw is! Map) return null;
    final m = Map<String, dynamic>.from(raw);
    final by = (m['by'] ?? '').toString().trim();
    final inst = (m['forInstitution'] ?? '').toString().trim();
    if (by.isEmpty && inst.isEmpty) return null;
    return TracePublication(
      by: by.isEmpty ? null : by,
      forInstitution: inst.isEmpty ? null : inst,
    );
  }
}

/// The public account of what Aura knows about one object.
class AuraTrace {
  const AuraTrace({
    required this.available,
    this.headline,
    this.source,
    this.summary,
    this.evidence = const <TraceEvidenceLine>[],
    this.history = const <TraceHistoryStep>[],
    this.publication,
    this.uncertainty = const <String>[],
    this.hasConflict = false,
    this.about = '',
    this.density = TraceDensity.simple,
  });

  /// Whether the TR mark should appear at all.
  ///
  /// Read from the server, never inferred from a non-empty list, so the
  /// visibility rule lives in exactly one place.
  final bool available;

  /// The most consequential thing Aura can responsibly say.
  final String? headline;

  /// The producing system, where one is identified.
  final String? source;

  /// One sentence of plain meaning under the headline.
  final String? summary;

  final List<TraceEvidenceLine> evidence;
  final List<TraceHistoryStep> history;
  final TracePublication? publication;

  /// Consequential unknowns, stated rather than implied.
  final List<String> uncertainty;

  final bool hasConflict;

  /// The provenance/truth boundary. Quiet, persistent, never the headline.
  final String about;

  final TraceDensity density;

  /// Nothing to disclose. The default everywhere, and visually silent.
  static const AuraTrace none = AuraTrace(available: false);

  bool get isEmpty => !available || (headline ?? '').isEmpty;

  /// There is something to disclose. Provided so call sites read as the
  /// question they are actually asking, rather than as a negated one.
  bool get isNotEmpty => !isEmpty;

  static AuraTrace fromJson(dynamic raw) {
    if (raw is! Map) return none;
    final m = Map<String, dynamic>.from(raw);

    List<T> list<T>(String key, T? Function(dynamic) parse) {
      final v = m[key];
      if (v is! List) return <T>[];
      return v.map(parse).whereType<T>().toList(growable: false);
    }

    final headline = (m['headline'] ?? '').toString().trim();
    final source = (m['source'] ?? '').toString().trim();
    final summary = (m['summary'] ?? '').toString().trim();

    return AuraTrace(
      available: m['available'] == true,
      headline: headline.isEmpty ? null : headline,
      source: source.isEmpty ? null : source,
      summary: summary.isEmpty ? null : summary,
      evidence: list('evidence', TraceEvidenceLine.tryFromJson),
      history: list('history', TraceHistoryStep.tryFromJson),
      publication: TracePublication.tryFromJson(m['publication']),
      uncertainty: (m['uncertainty'] is List)
          ? (m['uncertainty'] as List)
              .map((e) => e.toString().trim())
              .where((e) => e.isNotEmpty)
              .toList(growable: false)
          : const <String>[],
      hasConflict: m['hasConflict'] == true,
      about: (m['about'] ?? '').toString().trim(),
      // An unrecognised density resolves to SIMPLE — the smaller container.
      // Guessing RICH would hand a near-full-screen panel to a single fact.
      density: traceDensityFrom(m['density']?.toString()),
    );
  }
}
