import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../feed/data/unified_feed_providers.dart';
import '../feed/domain/feed_item.dart';
import '../public/data/public_institutions_repository.dart';
import 'models.dart';

/// Civic-signal derivation layer.
///
/// All providers here are pure cross-references over existing
/// providers (`globalPublicFeedProvider`,
/// `publicInstitutionsListProvider`). They never call a "civic signal"
/// backend endpoint — there isn't one, and the brief is explicit that
/// we do not invent metrics. When a backing provider is empty, the
/// derived list is empty too; UI consumers self-collapse.
///
/// Today only `CivicSignalType.institutionPost` can be backed
/// honestly. The other enum variants stay structurally ready for the
/// day backend signal endpoints (`/v1/discourse/issues`,
/// realtime-session DTOs with institution scope) ship sector-aware
/// data — see `civic_signals/models.dart` for the contract.

// ─────────────────────────────────────────────────────────────────────
// Recent institutional voices — directory strip
// ─────────────────────────────────────────────────────────────────────

/// Public-feed items authored as an institution voice. Cross-platform
/// directory strip uses this to surface "institutions are publicly
/// speaking right now" — purely derived from `globalPublicFeedProvider`.
///
/// Empty when the public feed contains no institution-authored items.
final recentInstitutionalVoicesProvider =
    FutureProvider<List<CivicSignal>>((ref) async {
  final page = await ref.watch(globalPublicFeedProvider.future);
  return _institutionalVoicesFrom(page.items);
});

// ─────────────────────────────────────────────────────────────────────
// Sector activity — sector page panel
// ─────────────────────────────────────────────────────────────────────

/// Sector-scoped activity: institution-authored public-feed items
/// whose author institution belongs to the given class.
///
/// Cross-references `globalPublicFeedProvider` with the per-sector
/// `publicInstitutionsListProvider(class: classId)`. No backend
/// changes; the join is a small client-side set membership check
/// against the sector's verified + on-the-platform cohorts.
///
/// Empty when (a) the public feed has no institution items, or (b)
/// none of the visible institutions belong to this sector. Both are
/// honest empty states — consumers self-collapse.
final sectorActivityProvider =
    FutureProvider.family<List<CivicSignal>, String>((ref, classId) async {
  if (classId.isEmpty) return const [];

  // Resolve the sector's institution set (verified + on-the-platform
  // cohorts the public directory exposes). This is the same query
  // surface the sector landing already runs, so Riverpod's cache
  // typically serves it for free.
  final sectorPage = await ref.watch(
    publicInstitutionsListProvider(
      PublicInstitutionsQuery(institutionClass: classId),
    ).future,
  );
  if (sectorPage.isEmpty) return const [];
  final sectorInstitutionIds = <String>{
    for (final i in sectorPage.verified) i.id,
    for (final i in sectorPage.other) i.id,
  };
  if (sectorInstitutionIds.isEmpty) return const [];

  final feed = await ref.watch(globalPublicFeedProvider.future);
  final voices = _institutionalVoicesFrom(feed.items);

  return voices
      .where((s) =>
          s.institutionId != null &&
          sectorInstitutionIds.contains(s.institutionId))
      .toList(growable: false);
});

// ─────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────

List<CivicSignal> _institutionalVoicesFrom(List<FeedItem> items) {
  final out = <CivicSignal>[];
  for (final item in items) {
    // `isInstitutionalVoice` covers both institution-authored posts
    // and institution announcements (both speak with institution
    // voice on the public feed).
    if (!item.isInstitutionalVoice) continue;
    if (item.author.id.isEmpty) continue;

    final body = item.body.replaceAll('\n', ' ').trim();
    final excerpt = body.length > 160 ? '${body.substring(0, 160)}…' : body;
    final titleSource =
        item.title?.trim().isNotEmpty == true ? item.title!.trim() : '';

    out.add(
      CivicSignal(
        id: item.id,
        type: CivicSignalType.institutionPost,
        targetRoute: item.targetRoute,
        title: titleSource.isNotEmpty ? titleSource : item.author.name,
        bodyExcerpt: excerpt,
        actorName: item.author.name,
        institutionId: item.author.id,
        institutionSlug: item.author.handleOrSlug.isEmpty
            ? null
            : item.author.handleOrSlug,
        // `FeedItem` doesn't carry the institution's ontology class
        // (the public feed projection didn't include it). Card
        // consumers fall back to "Institution" labelling when null.
        institutionClass: null,
        publishedAt: item.publishedAt ?? item.createdAt,
        source: item,
      ),
    );
  }
  return out;
}
