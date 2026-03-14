import 'package:dio/dio.dart';

import '../domain/profile.dart';
import '../../feed/domain/post.dart';

class FollowStateDetail {
  const FollowStateDetail({
    required this.state,
    this.requestId,
    this.cooldownDaysRemaining,
  });

  final String state;
  final String? requestId;
  final int? cooldownDaysRemaining;
}

class ProfileRepository {
  ProfileRepository(this._dio);
  final Dio _dio;

  Map<String, dynamic> _asMap(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return Map<String, dynamic>.from(v);
    return <String, dynamic>{};
  }

  Map<String, dynamic> _unwrapMap(dynamic raw) {
    final root = _asMap(raw);
    final outerData = root['data'];

    if (outerData is Map && outerData['data'] is Map) {
      return Map<String, dynamic>.from(outerData['data'] as Map);
    }
    if (outerData is Map) {
      return Map<String, dynamic>.from(outerData);
    }
    return root;
  }

  List<Map<String, dynamic>> _unwrapItems(dynamic raw) {
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    final root = _asMap(raw);

    if (root['items'] is List) {
      return (root['items'] as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    final data = root['data'];
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    if (data is Map && data['items'] is List) {
      return (data['items'] as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    if (data is Map && data['data'] is List) {
      return (data['data'] as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    return const <Map<String, dynamic>>[];
  }

  String _errorMessage(Object e) {
    if (e is DioException) {
      final d = e.response?.data;
      if (d is Map) {
        final err = d['error'];
        if (err is Map && err['message'] is String) {
          return err['message'] as String;
        }
        if (d['message'] is String) return d['message'] as String;
      }
      if (e.message != null) return e.message!;
    }
    return e.toString();
  }

  Future<Profile> fetchProfile(String handle) async {
    final res = await _dio.get('/users/$handle');
    final map = _unwrapMap(res.data);
    return Profile.fromJson(map);
  }

  Future<Profile> getUser(String handle) => fetchProfile(handle);

  Future<Profile> fetchMe() async {
    final res = await _dio.get('/users/me');
    final map = _unwrapMap(res.data);
    return Profile.fromJson(map);
  }

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
    final map = _unwrapMap(res.data);
    return Profile.fromJson(map);
  }

  Future<List<Post>> getUserPosts(
    String handle, {
    int limit = 20,
    String? cursor,
  }) async {
    try {
      final res = await _dio.get(
        '/users/$handle/posts',
        queryParameters: {
          'limit': limit,
          if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
        },
      );

      final items = _unwrapItems(res.data);

      return items
          .map((e) => Post.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return const <Post>[];
    }
  }

  Future<String> getFollowState(String handle) async {
    final detail = await getFollowStateDetail(handle);
    return detail.state;
  }

  Future<FollowStateDetail> getFollowStateDetail(String handle) async {
    try {
      final res = await _dio.get('/users/$handle/follow/state');
      final map = _unwrapMap(res.data);

      final state = (map['state'] ?? '').toString().trim();
      final requestId = (map['requestId'] ?? '').toString().trim();

      final cooldownRaw = map['cooldownDaysRemaining'];
      int? cooldownDaysRemaining;
      if (cooldownRaw is int) {
        cooldownDaysRemaining = cooldownRaw;
      } else if (cooldownRaw != null) {
        cooldownDaysRemaining = int.tryParse(cooldownRaw.toString());
      }

      return FollowStateDetail(
        state: state.isEmpty ? 'none' : state,
        requestId: requestId.isEmpty ? null : requestId,
        cooldownDaysRemaining: cooldownDaysRemaining,
      );
    } catch (_) {
      return const FollowStateDetail(state: 'none');
    }
  }

  Future<bool> isFollowing(String handle) async {
    final state = await getFollowState(handle);
    return state == 'following';
  }

  Future<void> follow(String handle) async {
    try {
      await _dio.post('/users/$handle/follow/request');
      return;
    } catch (e) {
      final msg = _errorMessage(e).toLowerCase();
      if (msg.contains('not found') || msg.contains('cannot post')) {
        await _dio.post('/users/$handle/follow');
        return;
      }
      rethrow;
    }
  }

  Future<void> unfollow(String handle) async {
    try {
      await _dio.post('/users/$handle/follow/cancel');
    } catch (e) {
      final msg = _errorMessage(e).toLowerCase();

      if (msg.contains('not found') ||
          msg.contains('bad request') ||
          msg.contains('cannot')) {
        await _dio.post('/users/$handle/follow/cancel');
        return;
      }

      rethrow;
    }
  }

  Future<List<ProfileListItem>> getFollowers(String handle) async {
    try {
      final res = await _dio.get('/users/$handle/followers');
      final items = _unwrapItems(res.data);
      return items.map((e) => ProfileListItem.fromJson(e)).toList();
    } catch (_) {
      return const <ProfileListItem>[];
    }
  }

  Future<List<ProfileListItem>> getFollowing(String handle) async {
    try {
      final res = await _dio.get('/users/$handle/following');
      final items = _unwrapItems(res.data);
      return items.map((e) => ProfileListItem.fromJson(e)).toList();
    } catch (_) {
      return const <ProfileListItem>[];
    }
  }
}
