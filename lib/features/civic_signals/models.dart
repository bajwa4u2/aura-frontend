/// Civic signal models.
///
/// These are **derivation-only** types. There is no separate backend
/// "civic signal" endpoint. Providers in
/// `lib/features/civic_signals/providers.dart` cross-reference existing
/// providers (the public feed, the institution directory, the
/// ontology) to assemble these typed views — no fabricated metrics,
/// no invented scores.
///
/// The enum reserves slots for future signal kinds (live sessions,
/// public discussions, accountability flags). Today the only signal
/// type the codebase can honestly back is `institutionPost` —
/// everything else is structurally ready but intentionally not
/// rendered until backing data exists.
library;

import '../feed/domain/feed_item.dart';

enum CivicSignalType {
  /// A public-feed post authored as an institution voice.
  institutionPost,

  /// (Future) A public discussion that has drawn institution replies.
  /// Not rendered today — requires a sector-scoped discourse-issue
  /// aggregation that the backend hasn't shipped.
  publicDiscussion,

  /// (Future) A discoverable live session anchored to an institution
  /// in this sector. Requires the realtime session DTO to carry
  /// institution-scoped or sector-scoped fields.
  liveSession,

  /// (Future) An accountability tag (COMMITMENT / UPDATE / RESOLVED)
  /// surfaced inline with the institution context. Backed by the
  /// existing `accountabilityTag` projection but currently rendered
  /// via the AccountabilityTrailRailModule, not as a sector signal.
  accountabilityFlag,
}

/// One unit of civic activity surfaced on a discovery surface.
///
/// Carries enough to render a compact card and route to the
/// underlying post / live session / institution without a second
/// fetch. The `source` retains the raw feed item so callers can
/// reuse existing routing helpers.
class CivicSignal {
  const CivicSignal({
    required this.id,
    required this.type,
    required this.targetRoute,
    required this.title,
    required this.bodyExcerpt,
    required this.actorName,
    required this.institutionId,
    required this.institutionSlug,
    required this.institutionClass,
    required this.publishedAt,
    required this.source,
  });

  /// Stable id (re-uses the underlying feed-item id).
  final String id;

  final CivicSignalType type;

  /// Canonical route for the signal (e.g., the feed item's
  /// `targetRoute`). Shell-context adapters (`FeedRouting.adaptTargetRoute`)
  /// should be applied at the caller when rendering inside a
  /// non-public shell.
  final String targetRoute;

  /// Short title for the card (institution name or feed item title).
  final String title;

  /// One-line excerpt for the card body.
  final String bodyExcerpt;

  /// Display name of the actor (typically the institution name).
  final String actorName;

  /// Institution id (when the signal is institution-authored). Null
  /// for future signal kinds that aren't institution-attributed.
  final String? institutionId;

  /// Institution slug (when known).
  final String? institutionSlug;

  /// Curated ontology class wire token. Null for institutions that
  /// haven't been classified yet.
  final String? institutionClass;

  /// Publication / activity timestamp.
  final DateTime? publishedAt;

  /// Raw source the signal was derived from. Kept so consumers can
  /// reuse existing card / routing helpers without re-fetching.
  final FeedItem source;
}
