import 'package:dio/dio.dart';
import '../feed/domain/post.dart';

class SearchResult {
  final List<Map<String, dynamic>> users;
  final List<Map<String, dynamic>> institutions;
  final List<Post> posts;

  const SearchResult({
    required this.users,
    required this.institutions,
    required this.posts,
  });
}

class SearchRepository {
  SearchRepository(this._dio);
  final Dio _dio;

  Future<SearchResult> search(String q, {int limit = 20}) async {
    final query = q.trim();
    if (query.isEmpty) {
      return const SearchResult(
        users: [],
        institutions: [],
        posts: [],
      );
    }

    final res = await _dio.get(
      '/search',
      queryParameters: {
        'q': query,
        'limit': limit,
      },
    );

    final root = res.data;

    List usersRaw = const [];
    List institutionsRaw = const [];
    List postsRaw = const [];

    if (root is Map) {
      if (root['users'] is List) {
        usersRaw = root['users'];
      }

      if (root['institutions'] is List) {
        institutionsRaw = root['institutions'];
      }

      if (root['posts'] is List) {
        postsRaw = root['posts'];
      }
    }

    final users = usersRaw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    final institutions = institutionsRaw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    final posts = postsRaw
        .whereType<Map>()
        .map((e) => Post.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    return SearchResult(
      users: users,
      institutions: institutions,
      posts: posts,
    );
  }
}