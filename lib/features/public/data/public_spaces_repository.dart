import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/net/dio_provider.dart';
import '../../feed/domain/feed_item.dart';
import '../domain/space.dart';

/// Frontend client for `/v1/public-spaces` (Public-UX Phase 3 backend).
///
/// All methods accept the existing `Dio` instance from `dioProvider`,
/// which already owns the `/v1` base URL. Each method tolerates both
/// the wrapped (`{ data: ... }`) and unwrapped response shapes the
/// backend ResponseWrapInterceptor may produce.
class PublicSpacesRepository {
  PublicSpacesRepository(this._dio);

  final Dio _dio;

  Future<List<PubSpace>> listSpaces() async {
    final res = await _dio.get<dynamic>('/public-spaces');
    final raw = _unwrapList(res.data);
    return raw
        .map((e) => _spaceFromJson(Map<String, dynamic>.from(e as Map)))
        .toList(growable: false);
  }

  Future<PubSpace?> getBySlug(String slug) async {
    final s = slug.trim().toLowerCase();
    if (s.isEmpty) return null;
    try {
      final res = await _dio.get<dynamic>('/public-spaces/$s');
      final m = _unwrapMap(res.data);
      if (m.isEmpty) return null;
      return _spaceFromJson(m);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  /// `(space, items, nextCursor, hasMore)` view for the space detail
  /// screen. Items are deserialized as `FeedItem` so `DiscourseCard`
  /// renders them with no special-casing.
  Future<PublicSpaceFeedPage> feedForSlug(
    String slug, {
    String? cursor,
    int limit = 20,
  }) async {
    final s = slug.trim().toLowerCase();
    if (s.isEmpty) {
      throw Exception('Space slug is required.');
    }
    final res = await _dio.get<dynamic>(
      '/public-spaces/$s/feed',
      queryParameters: {
        'limit': limit,
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
      },
    );
    final body = _unwrapMap(res.data);
    final spaceMap = body['space'] is Map
        ? Map<String, dynamic>.from(body['space'] as Map)
        : <String, dynamic>{};
    final itemsRaw = body['items'];
    final items = itemsRaw is List
        ? itemsRaw
            .whereType<Map>()
            .map((e) => FeedItem.fromJson(Map<String, dynamic>.from(e)))
            .toList(growable: false)
        : const <FeedItem>[];
    return PublicSpaceFeedPage(
      space: _spaceFromJson(spaceMap),
      items: items,
      nextCursor: body['nextCursor']?.toString(),
      hasMore: body['hasMore'] == true,
    );
  }

  Future<PublicSpaceSummary> summaryForSlug(String slug) async {
    final s = slug.trim().toLowerCase();
    if (s.isEmpty) {
      throw Exception('Space slug is required.');
    }
    final res = await _dio.get<dynamic>('/public-spaces/$s/summary');
    final body = _unwrapMap(res.data);
    final spaceMap = body['space'] is Map
        ? Map<String, dynamic>.from(body['space'] as Map)
        : <String, dynamic>{};
    final activeCount = (body['activeDiscussionCount'] as num?)?.toInt() ?? 0;
    final participantCount =
        (body['participantCount'] as num?)?.toInt() ?? 0;
    final institutionCount =
        (body['institutionCount'] as num?)?.toInt() ?? 0;
    return PublicSpaceSummary(
      space: _spaceFromJson(spaceMap),
      activeDiscussionCount: activeCount,
      participantCount: participantCount,
      institutionCount: institutionCount,
    );
  }

  // ─── Wire decode helpers ────────────────────────────────────────────────

  PubSpace _spaceFromJson(Map<String, dynamic> m) {
    final iconKey = (m['iconKey'] ?? '').toString();
    final slug = (m['slug'] ?? '').toString();
    return PubSpace(
      id: (m['id'] ?? '').toString(),
      slug: slug,
      name: (m['name'] ?? '').toString(),
      description: (m['description'] ?? '').toString(),
      icon: _iconForKey(iconKey, slug),
      tag: slug,
    );
  }

  /// Resolve the backend `iconKey` to a Material `IconData`. Tries the
  /// explicit key first, then a slug-based lookup, then a generic
  /// forum icon as last resort.
  static IconData _iconForKey(String iconKey, String slug) {
    final byKey = _kIconByKey[iconKey];
    if (byKey != null) return byKey;
    final bySlug = _kIconBySlug[slug.toLowerCase()];
    if (bySlug != null) return bySlug;
    return Icons.forum_outlined;
  }

  static Map<String, dynamic> _unwrapMap(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      final inner = raw['data'];
      if (inner is Map<String, dynamic>) return inner;
      if (inner is Map) return Map<String, dynamic>.from(inner);
      return raw;
    }
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return const {};
  }

  static List<dynamic> _unwrapList(dynamic raw) {
    if (raw is Map) {
      final inner = raw['data'];
      if (inner is List) return inner;
      final items = raw['items'];
      if (items is List) return items;
    }
    if (raw is List) return raw;
    return const [];
  }
}

/// Result of `/public-spaces/:slug/feed`.
class PublicSpaceFeedPage {
  const PublicSpaceFeedPage({
    required this.space,
    required this.items,
    required this.nextCursor,
    required this.hasMore,
  });

  final PubSpace space;
  final List<FeedItem> items;
  final String? nextCursor;
  final bool hasMore;
}

/// Identity summary returned by `/public-spaces/:slug/summary`.
class PublicSpaceSummary {
  const PublicSpaceSummary({
    required this.space,
    required this.activeDiscussionCount,
    required this.participantCount,
    required this.institutionCount,
  });

  final PubSpace space;
  final int activeDiscussionCount;
  final int participantCount;
  final int institutionCount;
}

/// Mapping from the backend's `iconKey` strings (which match Material
/// icon names) to the actual `IconData`. The migration seed values use
/// these tokens — adding a new space requires adding a key here too.
const Map<String, IconData> _kIconByKey = {
  'account_balance_outlined': Icons.account_balance_outlined,
  'eco_outlined': Icons.eco_outlined,
  'memory_rounded': Icons.memory_rounded,
  'school_outlined': Icons.school_outlined,
  'local_hospital_outlined': Icons.local_hospital_outlined,
  'place_outlined': Icons.place_outlined,
};

/// Slug-based fallback so unknown iconKeys still render with the right
/// glyph for the seeded curated spaces.
const Map<String, IconData> _kIconBySlug = {
  'civic': Icons.account_balance_outlined,
  'climate': Icons.eco_outlined,
  'technology': Icons.memory_rounded,
  'education': Icons.school_outlined,
  'health': Icons.local_hospital_outlined,
  'local': Icons.place_outlined,
};

final publicSpacesRepositoryProvider =
    Provider<PublicSpacesRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return PublicSpacesRepository(dio);
});

final publicSpacesListProvider =
    FutureProvider<List<PubSpace>>((ref) async {
  final repo = ref.watch(publicSpacesRepositoryProvider);
  return repo.listSpaces();
});

final publicSpaceFeedProvider =
    FutureProvider.family<PublicSpaceFeedPage, String>((ref, slug) async {
  final repo = ref.watch(publicSpacesRepositoryProvider);
  return repo.feedForSlug(slug);
});

final publicSpaceSummaryProvider =
    FutureProvider.family<PublicSpaceSummary, String>((ref, slug) async {
  final repo = ref.watch(publicSpacesRepositoryProvider);
  return repo.summaryForSlug(slug);
});
