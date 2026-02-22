import 'package:dio/dio.dart';

import '../domain/profile.dart';
import '../../feed/domain/post.dart';

class ProfileRepository {
  ProfileRepository(this._dio);
  final Dio _dio;

  /// GET /users/:handle
  Future<Profile> fetchProfile(String handle) async {
    final res = await _dio.get('/users/$handle');

    // Accept either {data:{...}} or raw {...}
    final body = res.data;
    if (body is Map && body['data'] is Map) {
      return Profile.fromJson(Map<String, dynamic>.from(body['data']));
    }
    if (body is Map) {
      return Profile.fromJson(Map<String, dynamic>.from(body));
    }
    throw StateError('Unexpected profile response');
  }

  /// Backwards-compatible alias for older screens
  Future<Profile> getUser(String handle) => fetchProfile(handle);

  /// GET /users/me
  Future<Profile> fetchMe() async {
    final res = await _dio.get('/users/me');
    final body = res.data;
    if (body is Map && body['data'] is Map) {
      return Profile.fromJson(Map<String, dynamic>.from(body['data']));
    }
    if (body is Map) {
      return Profile.fromJson(Map<String, dynamic>.from(body));
    }
    throw StateError('Unexpected me response');
  }

  /// PATCH /users/me
  /// Updates: displayName, bio, avatarUrl
  Future<Profile> updateMe({String? displayName, String? bio, String? avatarUrl}) async {
    final payload = <String, dynamic>{
      if (displayName != null) 'displayName': displayName,
      if (bio != null) 'bio': bio,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
    };

    final res = await _dio.patch('/users/me', data: payload);
    final body = res.data;
    if (body is Map && body['data'] is Map) {
      return Profile.fromJson(Map<String, dynamic>.from(body['data']));
    }
    if (body is Map && body['user'] is Map) {
      return Profile.fromJson(Map<String, dynamic>.from(body['user']));
    }
    if (body is Map) {
      return Profile.fromJson(Map<String, dynamic>.from(body));
    }
    throw StateError('Unexpected update response');
  }

  /// If your backend has a posts-by-author route, set it here.
  /// If not, this still compiles and returns empty.
  Future<List<Post>> getUserPosts(String handle, {int limit = 20, String? cursor}) async {
    try {
      final res = await _dio.get(
        '/users/$handle/posts',
        queryParameters: {
          'limit': limit,
          if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
        },
      );

      final body = res.data;
      final list = (body is Map ? (body['data'] as List?) : null) ?? const <dynamic>[];
      return list.map((e) => Post.fromJson(Map<String, dynamic>.from(e))).toList();
    } catch (_) {
      return const <Post>[];
    }
  }

  /// If your backend exposes follow state, use it. Otherwise return false.
  Future<bool> isFollowing(String handle) async {
    try {
      final res = await _dio.get('/users/$handle/following');
      final body = res.data;
      if (body is Map) return body['isFollowing'] == true || body['following'] == true;
      return false;
    } catch (_) {
      return false;
    }
  }

  /// POST /users/:handle/follow
  Future<void> follow(String handle) async {
    await _dio.post('/users/$handle/follow');
  }

  /// DELETE /users/:handle/follow
  Future<void> unfollow(String handle) async {
    await _dio.delete('/users/$handle/follow');
  }
}
