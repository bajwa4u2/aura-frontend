import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/net/dio_provider.dart';

/// THE THREE DOMAINS THAT NOW HAVE DISCOVERY OF THEIR OWN.
///
/// Spaces were a hardcoded client registry, Institutions a directory listing,
/// and Articles a reverse-chronological dump. Each now comes from a
/// viewer-scoped endpoint that composes relevance over an eligible set, so
/// what arrives here is already ordered and already permitted — this layer
/// reads it and does not re-rank or re-filter.
///
/// A CLIENT THAT RANKS IS A CLIENT THAT LIES. Ordering belongs to the
/// relevance authority; filtering belongs to the eligibility authority. Doing
/// either here would produce a surface whose behaviour cannot be explained
/// from the server's answer, and client-side filtering is not security.
///
/// People keeps its own established projection in people_discovery.dart.

class DiscoveredSpace {
  const DiscoveredSpace({
    required this.id,
    required this.slug,
    required this.name,
    required this.description,
    required this.iconKey,
    required this.participantCount,
    required this.postCount,
    required this.lastActivityAt,
    required this.viewerFollows,
    required this.reason,
  });

  final String id;
  final String slug;
  final String name;
  final String description;
  final String iconKey;

  /// Derived participation — never asserted, and zero is a truthful answer.
  final int participantCount;
  final int postCount;
  final DateTime? lastActivityAt;

  final bool viewerFollows;
  final String? reason;

  bool get hasActivity => postCount > 0;

  static DiscoveredSpace fromJson(Map<String, dynamic> j) => DiscoveredSpace(
        id: _s(j['id']),
        slug: _s(j['slug']),
        name: _s(j['name']),
        description: _s(j['description']),
        iconKey: _s(j['iconKey']),
        participantCount: _i(j['participantCount']),
        postCount: _i(j['postCount']),
        lastActivityAt: _date(j['lastActivityAt']),
        viewerFollows: j['viewerFollows'] == true,
        reason: _ns(j['reason']),
      );
}

class DiscoveredInstitution {
  const DiscoveredInstitution({
    required this.id,
    required this.slug,
    required this.name,
    required this.tagline,
    required this.description,
    required this.logoUrl,
    required this.city,
    required this.country,
    required this.institutionClass,
    required this.domainTags,
    required this.verified,
    required this.memberCount,
    required this.viewerFollows,
    required this.reason,
  });

  final String id;
  final String slug;
  final String name;
  final String? tagline;
  final String? description;
  final String? logoUrl;
  final String? city;
  final String? country;
  final String? institutionClass;
  final List<String> domainTags;
  final bool verified;
  final int memberCount;
  final bool viewerFollows;
  final String? reason;

  /// Where this institution operates, as one readable line, or nothing when
  /// Aura does not know. A half-known location reads worse than none.
  String? get place {
    final c = (city ?? '').trim();
    final k = (country ?? '').trim();
    if (c.isNotEmpty && k.isNotEmpty) return '$c, $k';
    if (c.isNotEmpty) return c;
    if (k.isNotEmpty) return k;
    return null;
  }

  static DiscoveredInstitution fromJson(Map<String, dynamic> j) =>
      DiscoveredInstitution(
        id: _s(j['id']),
        slug: _s(j['slug']),
        name: _s(j['name']),
        tagline: _ns(j['tagline']),
        description: _ns(j['description']),
        logoUrl: _ns(j['logoUrl']),
        city: _ns(j['city']),
        country: _ns(j['country']),
        institutionClass: _ns(j['institutionClass']),
        domainTags: (j['domainTags'] as List<dynamic>? ?? const [])
            .map((e) => e.toString())
            .toList(),
        verified: j['verified'] == true,
        memberCount: _i(j['memberCount']),
        viewerFollows: j['viewerFollows'] == true,
        reason: _ns(j['reason']),
      );
}

class DiscoveredArticle {
  const DiscoveredArticle({
    required this.id,
    required this.slug,
    required this.title,
    required this.coverMediaId,
    required this.coverUrl,
    required this.publishedAt,
    required this.readingMinutes,
    required this.authorName,
    required this.authorHandle,
    required this.authorAvatarUrl,
    required this.reason,
  });

  final String id;
  final String? slug;
  final String title;
  final String? coverMediaId;

  /// The governed delivery URL, resolved by the server exactly as the article
  /// reader resolves it. Never composed here: a media id is an identity, not
  /// an address.
  final String? coverUrl;
  final DateTime? publishedAt;
  final int readingMinutes;
  final String? authorName;
  final String? authorHandle;
  final String? authorAvatarUrl;
  final String? reason;

  static DiscoveredArticle fromJson(Map<String, dynamic> j) {
    final author = j['author'] is Map
        ? Map<String, dynamic>.from(j['author'] as Map)
        : const <String, dynamic>{};
    return DiscoveredArticle(
      id: _s(j['id']),
      slug: _ns(j['slug']),
      title: _s(j['title']),
      coverMediaId: _ns(j['coverMediaId']),
      coverUrl: _ns(j['coverUrl']),
      publishedAt: _date(j['publishedAt']),
      readingMinutes: _i(j['readingMinutes']),
      authorName: _ns(author['displayName']),
      authorHandle: _ns(author['handle']),
      authorAvatarUrl: _ns(author['avatarUrl']),
      reason: _ns(j['reason']),
    );
  }
}

class DiscoverPage<T> {
  const DiscoverPage({required this.items, required this.total});
  final List<T> items;
  final int total;

  bool get isEmpty => items.isEmpty;
  bool hasMoreAfter(int shown) => total > shown;
}

class DiscoverRepository {
  DiscoverRepository(this._ref);
  final Ref _ref;

  Future<DiscoverPage<T>> _page<T>(
    String path,
    T Function(Map<String, dynamic>) parse, {
    Map<String, dynamic>? query,
  }) async {
    final res = await _ref.read(dioProvider).get(path, queryParameters: query);
    final root = res.data;
    Map<String, dynamic> body = const {};
    if (root is Map) {
      body = Map<String, dynamic>.from(root);
      final data = body['data'];
      if (data is Map) body = Map<String, dynamic>.from(data);
    }
    final raw = body['items'];
    return DiscoverPage(
      items: raw is List
          ? raw
              .whereType<Map>()
              .map((e) => parse(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
      total: _i(body['total']),
    );
  }

  Future<DiscoverPage<DiscoveredSpace>> spaces({
    int limit = 6,
    int offset = 0,
    bool includeFollowed = false,
  }) =>
      _page('/discover/spaces', DiscoveredSpace.fromJson, query: {
        'limit': limit,
        'offset': offset,
        if (includeFollowed) 'includeFollowed': '1',
      });

  Future<DiscoverPage<DiscoveredInstitution>> institutions({
    int limit = 4,
    int offset = 0,
    String? institutionClass,
    String? domainTag,
    bool includeFollowed = false,
  }) =>
      _page('/discover/institutions', DiscoveredInstitution.fromJson, query: {
        'limit': limit,
        'offset': offset,
        if ((institutionClass ?? '').isNotEmpty) 'class': institutionClass,
        if ((domainTag ?? '').isNotEmpty) 'domainTag': domainTag,
        if (includeFollowed) 'includeFollowed': '1',
      });

  Future<DiscoverPage<DiscoveredArticle>> articles({
    int limit = 3,
    int offset = 0,
  }) =>
      _page('/discover/articles', DiscoveredArticle.fromJson,
          query: {'limit': limit, 'offset': offset});
}

final discoverRepositoryProvider =
    Provider<DiscoverRepository>((ref) => DiscoverRepository(ref));

/// Landing previews. Deliberately NOT autoDispose: leaving Discover to look at
/// something and coming back should not re-fetch every domain and lose the
/// dashboard the person was reading.
final discoverSpacesPreviewProvider =
    FutureProvider<DiscoverPage<DiscoveredSpace>>(
  (ref) => ref.read(discoverRepositoryProvider).spaces(limit: 4),
);

final discoverInstitutionsPreviewProvider =
    FutureProvider<DiscoverPage<DiscoveredInstitution>>(
  (ref) => ref.read(discoverRepositoryProvider).institutions(limit: 2),
);

final discoverArticlesPreviewProvider =
    FutureProvider<DiscoverPage<DiscoveredArticle>>(
  (ref) => ref.read(discoverRepositoryProvider).articles(limit: 3),
);

String _s(dynamic v) => (v ?? '').toString();
String? _ns(dynamic v) {
  final s = (v ?? '').toString().trim();
  return s.isEmpty ? null : s;
}

int _i(dynamic v) {
  if (v is int) return v;
  return int.tryParse((v ?? '').toString()) ?? 0;
}

DateTime? _date(dynamic v) {
  final s = (v ?? '').toString().trim();
  return s.isEmpty ? null : DateTime.tryParse(s);
}
