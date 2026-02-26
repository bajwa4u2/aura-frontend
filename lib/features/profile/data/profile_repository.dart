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
  Future<Profile> updateMe({
    String? displayName,
    String? bio,
    String? avatarUrl,
  }) async {
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

  String _errorMessage(Object e) {
    if (e is DioException) {
      final d = e.response?.data;
      if (d is Map) {
        final err = d['error'];
        if (err is Map && err['message'] is String) return err['message'] as String;
        if (d['message'] is String) return d['message'] as String;
      }
      if (e.message != null) return e.message!;
    }
    return e.toString();
  }

  /// POST /users/:handle/follow/request
  ///
  /// Aura follow requires a request (backend contract).
  /// We also keep a fallback to /follow for compatibility if the backend changes.
  Future<void> follow(String handle) async {
    try {
      await _dio.post('/users/$handle/follow/request');
      return;
    } catch (e) {
      // Fallback for older/alternate backend contract
      final msg = _errorMessage(e).toLowerCase();
      if (msg.contains('not found') || msg.contains('cannot post')) {
        await _dio.post('/users/$handle/follow');
        return;
      }
      rethrow;
    }
  }

  /// DELETE follow / cancel follow request
  ///
  /// First try direct unfollow:
  ///   DELETE /users/:handle/follow
  /// If backend is request-based, fall back to cancel request:
  ///   DELETE /users/:handle/follow/request
  Future<void> unfollow(String handle) async {
    try {
      await _dio.delete('/users/$handle/follow');
      return;
    } catch (e) {
      final msg = _errorMessage(e).toLowerCase();

      // If backend is request-based, cancel request instead
      if (msg.contains('requires a request') ||
          msg.contains('follow request') ||
          msg.contains('/follow/request') ||
          msg.contains('bad request') ||
          msg.contains('cannot delete')) {
        await _dio.delete('/users/$handle/follow/request');
        return;
      }

      // If it’s a hard 404 on /follow, try /follow/request too.
      if (msg.contains('not found') || msg.contains('cannot delete')) {
        await _dio.delete('/users/$handle/follow/request');
        return;
      }

      rethrow;
    }
  }
}