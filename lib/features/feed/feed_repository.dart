import 'package:dio/dio.dart';
import '../domain/post.dart';

class FeedPage {
  FeedPage({required this.items, required this.nextCursor});
  final List<Post> items;
  final String? nextCursor;
}

class FeedRepository {
  FeedRepository(this._dio);

  final Dio _dio;

  /// Expected backend (safe default):
  /// GET /posts?limit=20&cursor=...
  /// Returns: { data: [Post...], nextCursor: "..." } OR { data: [Post...] }
  Future<FeedPage> fetchFeed({int limit = 20, String? cursor}) async {
    final res = await _dio.get(
      '/posts',
      queryParameters: {
        'limit': limit,
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
      },
    );

    final raw = (res.data as Map).cast<String, dynamic>();
    final data = (raw['data'] as List? ?? const []).cast<dynamic>();

    final items = data.map((e) => Post.fromJson((e as Map).cast<String, dynamic>())).toList(growable: false);

    final nextCursor = raw['nextCursor'] as String?;
    return FeedPage(items: items, nextCursor: nextCursor);
  }
}
