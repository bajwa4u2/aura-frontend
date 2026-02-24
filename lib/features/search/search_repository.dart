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
      '/posts/search',
      queryParameters: {'q': query, 'limit': limit},
    );

    final root = res.data;

    // Your backend currently returns:
    // { ok: true, data: { data: [posts...] } }
    //
    // But we keep compatibility with a future combined search response:
    // { users: [...], posts: [...] }

    List usersRaw = const [];
    List postsRaw = const [];

    if (root is Map) {
      // Future/alt shape: { users: [], posts: [] }
      if (root['users'] is List) usersRaw = root['users'] as List;
      if (root['posts'] is List) postsRaw = root['posts'] as List;

      // Current shape: { ok: true, data: { data: [] } }
      final outerData = root['data'];
      if (postsRaw.isEmpty && outerData is Map && outerData['data'] is List) {
        postsRaw = outerData['data'] as List;
      }
    }

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