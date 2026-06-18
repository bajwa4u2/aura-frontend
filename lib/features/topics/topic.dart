/// Content Topics taxonomy — the LEFT-side feed filter dimension
/// ("what is the content about?"). Mirrors the backend `Topic` enum.
///
/// Primary Topic is human-selected and authoritative; Secondary Topics are
/// optional, machine-suggested, and human-editable. This file is the single
/// source of truth for the topic list, wire tokens, and labels on the client.
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

/// Deterministic, on-device topic suggester — "machine assistance" for the
/// Secondary Topics flow. Analyzes the content text and proposes topics by
/// keyword association. The creator always decides (accept / remove / add);
/// this never sets or overrides the Primary Topic.
///
/// Kept client-side and deterministic so the compose flow has no network
/// dependency, latency, or failure mode. Can be swapped for a server AI
/// endpoint later without changing the component contract.
class AuraTopicSuggester {
  static const Map<AuraTopic, List<String>> _keywords = {
    AuraTopic.government: ['government', 'council', 'policy', 'mayor', 'ministry', 'municipal', 'election', 'permit', 'ordinance', 'regulation'],
    AuraTopic.education: ['school', 'student', 'teacher', 'university', 'college', 'curriculum', 'tuition', 'scholarship', 'classroom', 'education'],
    AuraTopic.healthcare: ['health', 'hospital', 'clinic', 'patient', 'doctor', 'nurse', 'vaccine', 'medical', 'care', 'wellness'],
    AuraTopic.faith: ['faith', 'church', 'mosque', 'temple', 'prayer', 'worship', 'congregation', 'religious', 'parish', 'sermon'],
    AuraTopic.community: ['community', 'neighborhood', 'volunteer', 'resident', 'local', 'gathering', 'outreach', 'civic', 'town', 'block'],
    AuraTopic.business: ['business', 'market', 'company', 'startup', 'commerce', 'retail', 'trade', 'economy', 'merchant', 'enterprise'],
    AuraTopic.technology: ['technology', 'software', 'digital', 'app', 'data', 'platform', 'cyber', 'ai', 'internet', 'device'],
    AuraTopic.agriculture: ['farm', 'crop', 'harvest', 'livestock', 'agriculture', 'irrigation', 'soil', 'farmer', 'grain', 'cattle'],
    AuraTopic.transportation: ['transport', 'transit', 'bus', 'rail', 'road', 'traffic', 'vehicle', 'commute', 'highway', 'freight'],
    AuraTopic.environment: ['environment', 'climate', 'pollution', 'recycling', 'conservation', 'emissions', 'wildlife', 'sustainability', 'water', 'energy'],
    AuraTopic.publicSafety: ['safety', 'police', 'fire', 'emergency', 'crime', 'rescue', 'hazard', 'patrol', 'disaster', 'security'],
    AuraTopic.artsCulture: ['art', 'music', 'theater', 'culture', 'museum', 'festival', 'heritage', 'exhibit', 'gallery', 'performance'],
    AuraTopic.sports: ['sport', 'team', 'match', 'tournament', 'athlete', 'league', 'game', 'coach', 'stadium', 'championship'],
    AuraTopic.research: ['research', 'study', 'science', 'experiment', 'survey', 'findings', 'analysis', 'lab', 'journal', 'data'],
    AuraTopic.infrastructure: ['infrastructure', 'bridge', 'construction', 'utility', 'pipeline', 'grid', 'sewer', 'maintenance', 'roadwork', 'facility'],
    AuraTopic.employment: ['job', 'employment', 'hiring', 'worker', 'wage', 'labor', 'career', 'recruit', 'workforce', 'union'],
    AuraTopic.housing: ['housing', 'rent', 'home', 'tenant', 'landlord', 'mortgage', 'apartment', 'affordable', 'eviction', 'shelter'],
  };

  /// Suggest up to [max] secondary topics from the content, excluding
  /// [exclude] (typically the already-chosen Primary Topic). Ranked by
  /// keyword-hit count; ties broken by enum order for determinism.
  static List<AuraTopic> suggest(
    String text, {
    AuraTopic? exclude,
    int max = 3,
  }) {
    final lower = ' ${text.toLowerCase()} ';
    if (lower.trim().isEmpty) return const <AuraTopic>[];
    final scored = <AuraTopic, int>{};
    for (final entry in _keywords.entries) {
      if (entry.key == exclude) continue;
      var score = 0;
      for (final kw in entry.value) {
        if (lower.contains(kw)) score++;
      }
      if (score > 0) scored[entry.key] = score;
    }
    final ranked = scored.keys.toList()
      ..sort((a, b) {
        final byScore = scored[b]!.compareTo(scored[a]!);
        if (byScore != 0) return byScore;
        return a.index.compareTo(b.index);
      });
    return ranked.take(max).toList();
  }
}
