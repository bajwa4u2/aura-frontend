import 'package:dio/dio.dart';
import '../feed/domain/post.dart';

class AuthorProfile {
  final Map<String, dynamic> user;
  final List<Post> posts;

  AuthorProfile({required this.user, required this.posts});
}

class ProfileRepository {
  ProfileRepository(this._dio);
  final Dio _dio;

  Future<Map<String, dynamic>> getUser(String handle) async {
    final res = await _dio.get('/posts/users/$handle');
    final data = res.data;
    return (data is Map && data['user'] is Map) ? (data['user'] as Map).cast<String, dynamic>() : <String, dynamic>{};
  }

  Future<List<Post>> getUserPosts(String handle, {int limit = 20}) async {
    final res = await _dio.get('/posts/users/$handle/posts', queryParameters: {'limit': limit});
    final data = res.data;
    final List items = (data is Map && data['data'] is List) ? (data['data'] as List) : const [];
    return items.whereType<Map>().map((e) => Post.fromJson(e.cast<String, dynamic>())).toList();
  }

  Future<bool> isFollowing(String handle) async {
    final res = await _dio.get('/follows/is-following/$handle');
    return (res.data is Map && res.data['following'] == true);
  }

  Future<void> follow(String handle) async {
    await _dio.post('/follows/$handle');
  }

  Future<void> unfollow(String handle) async {
    await _dio.delete('/follows/$handle');
  }
}
