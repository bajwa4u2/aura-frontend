import 'package:dio/dio.dart';
import '../feed/domain/post.dart';

class SearchResult {
  final List<Map<String, dynamic>> users; // maps from backend
  final List<Post> posts;

  const SearchResult({required this.users, required this.posts});
}

class SearchRepository {
  SearchRepository(this._dio);
  final Dio _dio;

  Future<SearchResult> search(String q, {int limit = 20}) async {
    final query = q.trim();
    if (query.isEmpty) return const SearchResult(users: [], posts: []);

    final res = await _dio.get(
      '/v1/posts/search',
      queryParameters: {'q': query, 'limit': limit},
    );

    final data = res.data;
    final usersRaw = (data is Map && data['users'] is List) ? (data['users'] as List) : const [];
    final postsRaw = (data is Map && data['posts'] is List) ? (data['posts'] as List) : const [];

    final users = usersRaw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    final posts = postsRaw
        .whereType<Map>()
        .map((e) => Post.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    return SearchResult(users: users, posts: posts);
  }
}
