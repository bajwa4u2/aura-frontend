/// AXR-1 — Universal Governed Tagging: suggestion sources.
///
/// `@` suggestions come from the platform's existing server-ranked
/// `/search` endpoint (members + verified institutions — the same ranking
/// the Search screen trusts; no parallel ranking is introduced). `#`
/// suggestions come from the closed governed topic taxonomy and resolve
/// locally, instantly, with no network round trip.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/search/providers.dart';
import '../../features/search/search_repository.dart';
import '../../features/topics/topic.dart';
import 'tag_entities.dart';

final tagSuggestServiceProvider = Provider<TagSuggestService>((ref) {
  return TagSuggestService(ref.watch(searchRepositoryProvider));
});

class TagSuggestService {
  TagSuggestService(this._search);

  final SearchRepository _search;

  static const int maxSuggestions = 8;

  /// Ranked suggestions for [query] under [sigil]. Empty query with `@`
  /// returns nothing (typing one more character is cheaper than an
  /// unranked firehose); empty query with `#` lists the taxonomy.
  Future<List<TagSuggestion>> suggest(String sigil, String query) async {
    if (sigil == '#') return _topics(query);
    if (sigil == '@') return _entities(query);
    return const [];
  }

  List<TagSuggestion> _topics(String query) {
    final q = query.trim().toLowerCase();
    const all = AuraTopic.values;
    final matches = q.isEmpty
        ? all
        : all
              .where(
                (t) =>
                    t.label.toLowerCase().startsWith(q) ||
                    t.wire.toLowerCase().startsWith(q),
              )
              .toList();
    return matches
        .take(maxSuggestions)
        .map(
          (t) => TagSuggestion(
            kind: TagKind.topic,
            canonicalId: t.wire,
            display: t.label,
            // No spaces inside a token — taxonomy labels with spaces
            // insert their compact form (e.g. #PublicSafety).
            insertText: '#${t.label.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')}',
            subtitle: 'Topic',
          ),
        )
        .toList();
  }

  Future<List<TagSuggestion>> _entities(String query) async {
    final q = query.trim();
    if (q.isEmpty) return const [];

    final SearchResult result;
    try {
      result = await _search.search(q, limit: maxSuggestions);
    } catch (_) {
      // Autocomplete is assistive; a failed lookup silently yields no
      // suggestions rather than surfacing an error into the composer.
      return const [];
    }

    final out = <TagSuggestion>[];
    for (final u in result.users) {
      final handle = (u['handle'] ?? '').toString().trim();
      if (handle.isEmpty) continue;
      final displayName = (u['displayName'] ?? '').toString().trim();
      out.add(
        TagSuggestion(
          kind: TagKind.member,
          canonicalId: (u['id'] ?? '').toString(),
          display: displayName.isEmpty ? handle : displayName,
          insertText: '@${displayName.isEmpty ? handle : displayName}',
          subtitle: '@$handle',
          imageUrl: (u['avatarUrl'] ?? '').toString().trim().isEmpty
              ? null
              : (u['avatarUrl'] as Object).toString(),
        ),
      );
    }
    for (final i in result.institutions) {
      final slug = (i['slug'] ?? '').toString().trim();
      if (slug.isEmpty) continue;
      final name = (i['name'] ?? '').toString().trim();
      out.add(
        TagSuggestion(
          kind: TagKind.institution,
          canonicalId: (i['id'] ?? '').toString(),
          display: name.isEmpty ? slug : name,
          insertText: '@${name.isEmpty ? slug : name}',
          subtitle: '@$slug · Institution',
          imageUrl: (i['logoUrl'] ?? '').toString().trim().isEmpty
              ? null
              : (i['logoUrl'] as Object).toString(),
        ),
      );
    }
    // Server ranking already ordered each list; interleaving members
    // first matches the platform's identity-first emphasis.
    return out.take(maxSuggestions).toList();
  }
}
