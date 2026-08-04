/// Content Topics taxonomy — the LEFT-side feed filter dimension
/// ("what is the content about?"). Mirrors the backend `Topic` enum.
///
/// Primary Topic is human-selected and authoritative; Secondary Topics are
/// optional, machine-suggested, and human-editable. This file is the single
/// source of truth for the topic list, wire tokens, and labels on the client.
///
/// The approved-relationship graph is NOT duplicated here. The backend
/// (`aura-backend/src/topics/topic-relationships.ts`) is the sole authority
/// for which Topics may relate to which — see `topic_repository.dart` for
/// the read contracts (`GET /topics/:primary/secondaries` for the approved
/// set, `POST /topics/suggest-secondary` for ranked suggestions).
enum AuraTopic {
  government,
  education,
  healthcare,
  faith,
  community,
  business,
  technology,
  agriculture,
  transportation,
  environment,
  publicSafety,
  artsCulture,
  sports,
  research,
  infrastructure,
  employment,
  housing;

  /// Backend enum token (UPPER_SNAKE), e.g. `PUBLIC_SAFETY`.
  String get wire {
    switch (this) {
      case AuraTopic.publicSafety:
        return 'PUBLIC_SAFETY';
      case AuraTopic.artsCulture:
        return 'ARTS_CULTURE';
      default:
        return name.toUpperCase();
    }
  }

  /// Human-readable label.
  String get label {
    switch (this) {
      case AuraTopic.government:
        return 'Government';
      case AuraTopic.education:
        return 'Education';
      case AuraTopic.healthcare:
        return 'Healthcare';
      case AuraTopic.faith:
        return 'Faith';
      case AuraTopic.community:
        return 'Community';
      case AuraTopic.business:
        return 'Business';
      case AuraTopic.technology:
        return 'Technology';
      case AuraTopic.agriculture:
        return 'Agriculture';
      case AuraTopic.transportation:
        return 'Transportation';
      case AuraTopic.environment:
        return 'Environment';
      case AuraTopic.publicSafety:
        return 'Public Safety';
      case AuraTopic.artsCulture:
        return 'Arts & Culture';
      case AuraTopic.sports:
        return 'Sports';
      case AuraTopic.research:
        return 'Research';
      case AuraTopic.infrastructure:
        return 'Infrastructure';
      case AuraTopic.employment:
        return 'Employment';
      case AuraTopic.housing:
        return 'Housing';
    }
  }

  static AuraTopic? fromWire(String? wire) {
    if (wire == null) return null;
    final w = wire.trim().toUpperCase();
    if (w.isEmpty) return null;
    for (final t in AuraTopic.values) {
      if (t.wire == w) return t;
    }
    return null;
  }

  static List<AuraTopic> listFromWire(dynamic raw) {
    if (raw is! List) return const <AuraTopic>[];
    final out = <AuraTopic>[];
    for (final e in raw) {
      final t = fromWire(e?.toString());
      if (t != null && !out.contains(t)) out.add(t);
    }
    return out;
  }
}
