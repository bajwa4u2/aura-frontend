import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/net/dio_provider.dart';
import '../domain/feed_item.dart';

/// Single client for the unified `/feed/*` endpoints. All methods return
/// [FeedPage] / [FeedItem] — no domain-specific shapes leak past this layer.
class UnifiedFeedRepository {
  UnifiedFeedRepository(this._dio);

  final dynamic _dio;

  Future<FeedPage> globalPublic({
    String? cursor,
    int? limit,
    String? actor,
    String? topic,
    String? source,
  }) async {
    return _list('/feed/public',
        cursor: cursor,
        limit: limit,
        actor: actor,
        query: _filterQuery(topic, source));
  }

  /// Build the optional viewer-filter query (topic + source/type). Returns
  /// null when neither is set so default feeds are byte-identical to before.
  Map<String, dynamic>? _filterQuery(String? topic, String? source) {
    final q = <String, dynamic>{};
    if (topic != null && topic.trim().isNotEmpty) q['topic'] = topic.trim();
    if (source != null && source.trim().isNotEmpty) q['source'] = source.trim();
    return q.isEmpty ? null : q;
  }

  Future<FeedPage> memberHome({
    String? cursor,
    int? limit,
    String? actor,
    String? topic,
    String? source,
  }) async {
    return _list('/feed/member',
        cursor: cursor,
        limit: limit,
        actor: actor,
        query: _filterQuery(topic, source));
  }

  Future<FeedPage> institutionExplore({
    required String institutionId,
    required String scope,
    String? cursor,
    int? limit,
    String? actor,
  }) async {
    final id = institutionId.trim();
    if (id.isEmpty) throw Exception('Institution id is missing.');
    return _list(
      '/feed/institutions/$id/explore',
      query: <String, dynamic>{'scope': scope},
      cursor: cursor,
      limit: limit,
      actor: actor,
    );
  }

  Future<FeedPage> institutionProfile({
    required String institutionId,
    String? cursor,
    int? limit,
    String? actor,
  }) async {
    final id = institutionId.trim();
    if (id.isEmpty) throw Exception('Institution id is missing.');
    return _list(
      '/feed/institutions/$id/profile',
      cursor: cursor,
      limit: limit,
      actor: actor,
    );
  }

  Future<FeedItem?> itemDetail({
    required FeedItemType type,
    required String id,
    String? actor,
  }) async {
    final cleanId = id.trim();
    if (cleanId.isEmpty) return null;
    final q = <String, dynamic>{};
    if (actor != null && actor.trim().isNotEmpty) q['actor'] = actor.trim();
    try {
      final res = await _dio.get(
        '/feed/items/${type.wire}/$cleanId',
        queryParameters: q.isEmpty ? null : q,
      );
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
    } on DioException catch (e) {
      // 404 is a normal "this thread no longer exists / is no longer
      // visible" outcome. Returning null lets the screen render the
      // graceful empty state instead of leaking a raw DioException
      // (and the minified Dart class names that come with it) into
      // production UI. Other statuses are still thrown so the caller
      // can render an appropriate retry state.
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
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
    try {
      final res = await _dio.get(
        '/feed/items/${type.wire}/$cleanId/replies',
        queryParameters: q.isEmpty ? null : q,
      );
      return FeedRepliesPage.fromJson(res.data);
    } on DioException catch (e) {
      // Parent already 404'd or replies not visible — return an empty
      // page so the screen never re-fires this request in a tight loop
      // and never leaks the raw DioException to the user.
      if (e.response?.statusCode == 404) {
        return const FeedRepliesPage(items: <FeedReply>[]);
      }
      rethrow;
    }
  }

  Future<FeedPage> _list(
    String path, {
    Map<String, dynamic>? query,
    String? cursor,
    int? limit,
    String? actor,
  }) async {
    final q = <String, dynamic>{};
    if (query != null) q.addAll(query);
    if (cursor != null && cursor.trim().isNotEmpty) q['cursor'] = cursor.trim();
    if (limit != null) q['limit'] = limit;
    if (actor != null && actor.trim().isNotEmpty) q['actor'] = actor.trim();
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
