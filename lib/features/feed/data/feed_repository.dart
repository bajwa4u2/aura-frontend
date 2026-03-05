import 'package:dio/dio.dart';

import '../domain/post.dart';

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
        items: body.map((e) => Post.fromJson(Map<String, dynamic>.from(e))).toList(),
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
          items: list.map((e) => Post.fromJson(Map<String, dynamic>.from(e))).toList(),
          nextCursor: next,
        );
      }

      // Flat map containing list directly: { data: [..], nextCursor: "..." }
      final list = _pickListFromMap(root);
      final next = _pickCursorFromMap(root);
      return FeedPage(
        items: list.map((e) => Post.fromJson(Map<String, dynamic>.from(e))).toList(),
        nextCursor: next,
      );
    }

    return const FeedPage(items: <Post>[], nextCursor: null);
  }
}

class FeedRepository {
  final Dio dio;
  FeedRepository(this.dio);

  int _clampLimit(int limit) {
    final n = limit;
    if (n <= 0) return 20;
    if (n > 50) return 50;
    return n;
  }

  bool _isSoftFailure(DioException e) {
    final code = e.response?.statusCode;
    // 401: not logged in
    // 403: logged in but blocked (future followers/private feed rules)
    // 404: visibility contract may hide rows as not-found
    return code == 401 || code == 403 || code == 404;
  }

  Future<FeedPage> fetchFeed({String? cursor, int limit = 20}) async {
    final take = _clampLimit(limit);

    try {
      final res = await dio.get(
        '/posts/feed',
        queryParameters: {
          'limit': take,
          if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
        },
      );
      return FeedPage.fromResponse(res.data);
    } on DioException catch (e) {
      if (_isSoftFailure(e)) {
        return const FeedPage(items: <Post>[], nextCursor: null);
      }
      rethrow;
    }
  }
}