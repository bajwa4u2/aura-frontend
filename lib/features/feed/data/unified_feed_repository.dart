import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/net/dio_provider.dart';
import '../domain/feed_item.dart';

/// Single client for the unified `/feed/*` endpoints. All methods return
/// [FeedPage] / [FeedItem] — no domain-specific shapes leak past this layer.
class UnifiedFeedRepository {
  UnifiedFeedRepository(this._dio);

  final dynamic _dio;

  Future<FeedPage> globalPublic({String? cursor, int? limit}) async {
    return _list('/feed/public', cursor: cursor, limit: limit);
  }

  Future<FeedPage> memberHome({String? cursor, int? limit}) async {
    return _list('/feed/member', cursor: cursor, limit: limit);
  }

  Future<FeedPage> institutionExplore({
    required String institutionId,
    required String scope,
    String? cursor,
    int? limit,
  }) async {
    final id = institutionId.trim();
    if (id.isEmpty) throw Exception('Institution id is missing.');
    return _list(
      '/feed/institutions/$id/explore',
      query: <String, dynamic>{'scope': scope},
      cursor: cursor,
      limit: limit,
    );
  }

  Future<FeedPage> institutionProfile({
    required String institutionId,
    String? cursor,
    int? limit,
  }) async {
    final id = institutionId.trim();
    if (id.isEmpty) throw Exception('Institution id is missing.');
    return _list(
      '/feed/institutions/$id/profile',
      cursor: cursor,
      limit: limit,
    );
  }

  Future<FeedItem?> itemDetail({
    required FeedItemType type,
    required String id,
  }) async {
    final cleanId = id.trim();
    if (cleanId.isEmpty) return null;
    final res = await _dio.get('/feed/items/${type.wire}/$cleanId');
    final body = res.data;
    if (body is Map) {
      // Accept both the bare item and a `{ ok, data: {...} }` envelope.
      final root = Map<String, dynamic>.from(body);
      final container = root['data'] is Map
          ? Map<String, dynamic>.from(root['data'] as Map)
          : root;
      return FeedItem.fromJson(container);
    }
    return null;
  }

  Future<FeedRepliesPage> itemReplies({
    required FeedItemType type,
    required String id,
    String? cursor,
    int? limit,
  }) async {
    final cleanId = id.trim();
    if (cleanId.isEmpty) return const FeedRepliesPage(items: <FeedReply>[]);
    final q = <String, dynamic>{};
    if (cursor != null && cursor.trim().isNotEmpty) q['cursor'] = cursor.trim();
    if (limit != null) q['limit'] = limit;
    final res = await _dio.get(
      '/feed/items/${type.wire}/$cleanId/replies',
      queryParameters: q.isEmpty ? null : q,
    );
    return FeedRepliesPage.fromJson(res.data);
  }

  Future<FeedPage> _list(
    String path, {
    Map<String, dynamic>? query,
    String? cursor,
    int? limit,
  }) async {
    final q = <String, dynamic>{};
    if (query != null) q.addAll(query);
    if (cursor != null && cursor.trim().isNotEmpty) q['cursor'] = cursor.trim();
    if (limit != null) q['limit'] = limit;
    final res = await _dio.get(
      path,
      queryParameters: q.isEmpty ? null : q,
    );
    return FeedPage.fromJson(res.data);
  }
}

final unifiedFeedRepositoryProvider = Provider<UnifiedFeedRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return UnifiedFeedRepository(dio);
});
