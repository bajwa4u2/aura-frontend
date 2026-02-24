import 'package:dio/dio.dart';

import '../post_model.dart';

class FeedPage {
  const FeedPage({
    required this.items,
    required this.nextCursor,
  });

  final List<Post> items;
  final String? nextCursor;

  static String? _pickCursorFromMap(Map<String, dynamic> m) {
    final v = (m['nextCursor'] ?? m['cursor'] ?? m['next']);
    if (v == null) return null;
    final s = v.toString();
    return s.isEmpty ? null : s;
  }

  static List<dynamic> _pickListFromMap(Map<String, dynamic> m) {
    final v = (m['data'] ?? m['items']);
    if (v is List) return v;
    return const <dynamic>[];
  }

  factory FeedPage.fromResponse(dynamic body) {
    // Case 1: raw list
    if (body is List) {
      return FeedPage(
        items: body
            .map((e) => Post.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        nextCursor: null,
      );
    }

    // Case 2: map (maybe envelope)
    if (body is Map) {
      final root = Map<String, dynamic>.from(body);

      // Envelope shape: { ok: true, data: <payload> }
      if (root.containsKey('ok') && root.containsKey('data')) {
        return FeedPage.fromResponse(root['data']);
      }

      // Nested data: { data: { data: [..], nextCursor: "..." } }
      if (root['data'] is Map) {
        final inner = Map<String, dynamic>.from(root['data'] as Map);
        final list = _pickListFromMap(inner);
        final next = _pickCursorFromMap(inner);
        return FeedPage(
          items: list
              .map((e) => Post.fromJson(Map<String, dynamic>.from(e)))
              .toList(),
          nextCursor: next,
        );
      }

      // Flat map containing list directly: { data: [..], nextCursor: "..." }
      final list = _pickListFromMap(root);
      final next = _pickCursorFromMap(root);
      return FeedPage(
        items: list
            .map((e) => Post.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        nextCursor: next,
      );
    }

    return const FeedPage(items: <Post>[], nextCursor: null);
  }
}

class FeedRepository {
  final Dio dio;
  FeedRepository(this.dio);

  Future<FeedPage> fetchFeed({String? cursor, int limit = 20}) async {
    try {
      final res = await dio.get(
        '/posts/feed',
        queryParameters: {
          'limit': limit,
          if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
        },
      );
      return FeedPage.fromResponse(res.data);
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 401) {
        return const FeedPage(items: <Post>[], nextCursor: null);
      }
      rethrow;
    }
  }

  Future<FeedPage> fetchAuthedFeed({String? cursor, int limit = 20}) async {
    return fetchFeed(cursor: cursor, limit: limit);
  }

  Future<Post> create(String text) async {
    final res = await dio.post('/posts', data: {'text': text});
    final body = res.data;
    if (body is Map && body['post'] is Map) {
      return Post.fromJson(Map<String, dynamic>.from(body['post']));
    }
    return Post.fromJson(Map<String, dynamic>.from(body));
  }
}