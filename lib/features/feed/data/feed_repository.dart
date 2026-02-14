import 'package:dio/dio.dart';
import '../domain/post.dart';

class FeedPage {
  const FeedPage({
    required this.items,
    required this.nextCursor,
  });

  final List<Post> items;
  final String? nextCursor;

  factory FeedPage.fromResponse(dynamic body) {
    if (body is List) {
      return FeedPage(
        items: body.map((e) => Post.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
        nextCursor: null,
      );
    }

    if (body is Map) {
      final map = Map<String, dynamic>.from(body as Map);

      final list = (map['data'] as List?) ?? (map['items'] as List?) ?? const <dynamic>[];
      final next = (map['nextCursor'] ?? map['cursor'] ?? map['next'] ?? '')?.toString();

      return FeedPage(
        items: list.map((e) => Post.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
        nextCursor: (next != null && next.isNotEmpty) ? next : null,
      );
    }

    return const FeedPage(items: <Post>[], nextCursor: null);
  }
}

class FeedRepository {
  final Dio dio;
  FeedRepository(this.dio);

  /// Feed shown on Home.
  /// If server requires auth and user is not logged in, return empty quietly.
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
      return Post.fromJson(Map<String, dynamic>.from(body['post'] as Map));
    }
    return Post.fromJson(Map<String, dynamic>.from(body as Map));
  }
}
