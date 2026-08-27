/// AURA TRACE — the client model.
///
///     DON'T ASK PEOPLE TO TRUST A LABEL. SHOW THEM THE TRACE.
///
/// TR is a doorway, not a verdict. It means Aura has something worth disclosing
/// about this object — history, provenance, integrity information, or genuine
/// uncertainty — and opening it answers what Aura knows, how it knows it, and
/// what remains unresolved.
///
/// ## WHAT THIS LAYER MAY NOT DO
///
/// It performs NO reasoning. The server has already composed the facts and
/// attached an evidence class to each one; this parses them and renders them. A
/// client that re-derived any of it would become a second authority, and two
/// authorities on the same question eventually disagree — usually on the object
/// where it matters most.
///
/// So there is deliberately no code here that can promote, combine or summarise
/// evidence. `available` is read, never computed.
///
/// ## OBJECT-TYPE INDEPENDENT BY CONSTRUCTION
///
/// Nothing below mentions media. Trace already covers text posts and messages
/// server-side, and the ruling anticipates statements, documents and
/// institutional communications later. Naming this `AiMediaBadge` would have
/// made that extension a rewrite.
library;

/// How firmly Aura holds one fact. Never collapsed in presentation.
enum TraceEvidenceClass {
  /// Aura knows this first-hand.
  known,

  /// Cryptographically verified against a signer Aura trusts.
  verified,

  /// A person stated it. Attributable, and not proof.
  declared,

  /// Read from the object, which anyone could have written.
  observed,

  /// A model's assessment. May be wrong, and says so.
  inferred,

  /// Sources disagree, and Aura is not choosing between them.
  conflicting,
}

TraceEvidenceClass traceEvidenceFrom(String? wire) {
  switch ((wire ?? '').trim().toUpperCase()) {
    case 'KNOWN':
      return TraceEvidenceClass.known;
    case 'VERIFIED':
      return TraceEvidenceClass.verified;
    case 'DECLARED':
      return TraceEvidenceClass.declared;
    case 'INFERRED':
      return TraceEvidenceClass.inferred;
    case 'CONFLICTING':
      return TraceEvidenceClass.conflicting;
    default:
      // An unrecognised class resolves to the WEAKEST reading, never the
      // strongest. A newer server sending a class this build does not know must
      // not have it silently upgraded into verification.
      return TraceEvidenceClass.observed;
  }
}

/// Which part of the story a fact belongs to.
enum TraceSection {
  origin,
  capture,
  aiInvolvement,
  creatorDisclosure,
  contentCredentials,
  transformations,
  integrity,
  uncertainty,
  other,
}

TraceSection traceSectionFrom(String? wire) {
  switch ((wire ?? '').trim().toUpperCase()) {
    case 'ORIGIN':
      return TraceSection.origin;
    case 'CAPTURE':
      return TraceSection.capture;
    case 'AI_INVOLVEMENT':
      return TraceSection.aiInvolvement;
    case 'CREATOR_DISCLOSURE':
      return TraceSection.creatorDisclosure;
    case 'CONTENT_CREDENTIALS':
      return TraceSection.contentCredentials;
    case 'TRANSFORMATIONS':
      return TraceSection.transformations;
    case 'INTEGRITY':
      return TraceSection.integrity;
    case 'UNCERTAINTY':
      return TraceSection.uncertainty;
    default:
      return TraceSection.other;
  }
}

/// The heading a person reads. Deliberately human wording, not a state name.
String traceSectionLabel(TraceSection s) {
  switch (s) {
    case TraceSection.origin:
      return 'Origin';
    case TraceSection.capture:
      return 'How it was captured';
    case TraceSection.aiInvolvement:
      return 'AI involvement';
    case TraceSection.creatorDisclosure:
      return 'What the creator said';
    case TraceSection.contentCredentials:
      return 'Content Credentials';
    case TraceSection.transformations:
      return 'What changed';
    case TraceSection.integrity:
      return 'Integrity';
    case TraceSection.uncertainty:
      return 'What is unresolved';
    case TraceSection.other:
      return 'Other';
  }
}

/// How a fact is held, in words a reader can act on.
///
/// This is the sentence that stops a declaration reading like a verification.
String traceEvidenceLabel(TraceEvidenceClass e) {
  switch (e) {
    case TraceEvidenceClass.known:
      return 'Aura knows this';
    case TraceEvidenceClass.verified:
      return 'Verified';
    case TraceEvidenceClass.declared:
      return 'Stated by the creator';
    case TraceEvidenceClass.observed:
      return 'Found in the file';
    case TraceEvidenceClass.inferred:
      return 'Automated assessment';
    case TraceEvidenceClass.conflicting:
      return 'Sources disagree';
  }
}

class TraceFact {
  const TraceFact({
    required this.section,
    required this.evidence,
    required this.summary,
    this.detail,
    this.source,
  });

  final TraceSection section;
  final TraceEvidenceClass evidence;
  final String summary;
  final String? detail;
  final String? source;

  static TraceFact? tryFromJson(dynamic raw) {
    if (raw is! Map) return null;
    final m = Map<String, dynamic>.from(raw);
    final summary = (m['summary'] ?? '').toString().trim();
    // A fact with nothing to say is not a fact. Rendering an empty row would
    // suggest Aura knows something it cannot express.
    if (summary.isEmpty) return null;
    return TraceFact(
      section: traceSectionFrom(m['section']?.toString()),
      evidence: traceEvidenceFrom(m['evidence']?.toString()),
      summary: summary,
      detail: (m['detail'] ?? '').toString().trim().isEmpty
          ? null
          : m['detail'].toString().trim(),
      source: (m['source'] ?? '').toString().trim().isEmpty
          ? null
          : m['source'].toString().trim(),
    );
  }
}

/// What Aura is prepared to show about one object.
class AuraTrace {
  const AuraTrace({
    required this.available,
    required this.facts,
    this.headline,
    this.hasConflict = false,
  });

  /// Whether the TR mark should appear at all.
  ///
  /// Read from the server, never inferred from a non-empty list, so the
  /// visibility rule lives in exactly one place.
  final bool available;

  final List<TraceFact> facts;
  final String? headline;
  final bool hasConflict;

  /// Nothing to disclose. The default everywhere, and visually silent.
  static const AuraTrace none = AuraTrace(available: false, facts: []);

  bool get isEmpty => !available || facts.isEmpty;

  /// Facts grouped for display, in a stable, meaningful order.
  ///
  /// Uncertainty and integrity lead: they are what a reader most needs to know
  /// exists, even though both are held less firmly than a verified credential.
  /// Ordering by evidence strength would bury exactly the thing that matters.
  List<MapEntry<TraceSection, List<TraceFact>>> get grouped {
    const order = [
      TraceSection.uncertainty,
      TraceSection.integrity,
      TraceSection.aiInvolvement,
      TraceSection.origin,
      TraceSection.capture,
      TraceSection.contentCredentials,
      TraceSection.creatorDisclosure,
      TraceSection.transformations,
      TraceSection.other,
    ];
    final out = <MapEntry<TraceSection, List<TraceFact>>>[];
    for (final section in order) {
      final inSection = facts.where((f) => f.section == section).toList();
      // Empty sections are never emitted — a heading with nothing under it
      // reads as something withheld.
      if (inSection.isEmpty) continue;
      out.add(MapEntry(section, inSection));
    }
    return out;
  }

  static AuraTrace fromJson(dynamic raw) {
    if (raw is! Map) return none;
    final m = Map<String, dynamic>.from(raw);
    final facts = <TraceFact>[];
    final rawFacts = m['facts'];
    if (rawFacts is List) {
      for (final f in rawFacts) {
        final parsed = TraceFact.tryFromJson(f);
        if (parsed != null) facts.add(parsed);
      }
    }
    return AuraTrace(
      available: m['available'] == true,
      facts: facts,
      headline: (m['headline'] ?? '').toString().trim().isEmpty
          ? null
          : m['headline'].toString().trim(),
      hasConflict: m['hasConflict'] == true,
    );
  }
}
