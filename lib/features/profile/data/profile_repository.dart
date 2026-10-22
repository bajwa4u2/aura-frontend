import 'package:aura/core/net/api_envelope.dart';
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

class FollowRequestInboxItem {
  const FollowRequestInboxItem({
    required this.id,
    required this.createdAt,
    required this.requester,
  });

  final String id;
  final DateTime? createdAt;
  final ProfileListItem requester;

  factory FollowRequestInboxItem.fromJson(Map<String, dynamic> json) {
    final requesterRaw = json['requester'];
    final requesterMap = requesterRaw is Map<String, dynamic>
        ? requesterRaw
        : requesterRaw is Map
        ? Map<String, dynamic>.from(requesterRaw)
        : <String, dynamic>{};

    final createdAtRaw = (json['createdAt'] ?? '').toString().trim();

    return FollowRequestInboxItem(
      id: (json['id'] ?? '').toString().trim(),
      createdAt: createdAtRaw.isEmpty ? null : DateTime.tryParse(createdAtRaw),
      requester: ProfileListItem.fromJson(requesterMap),
    );
  }
}

class FollowRequestOutboxItem {
  const FollowRequestOutboxItem({
    required this.id,
    required this.createdAt,
    required this.target,
  });

  final String id;
  final DateTime? createdAt;
  final ProfileListItem target;

  factory FollowRequestOutboxItem.fromJson(Map<String, dynamic> json) {
    final targetRaw = json['target'];
    final targetMap = targetRaw is Map<String, dynamic>
        ? targetRaw
        : targetRaw is Map
        ? Map<String, dynamic>.from(targetRaw)
        : <String, dynamic>{};

    final createdAtRaw = (json['createdAt'] ?? '').toString().trim();

    return FollowRequestOutboxItem(
      id: (json['id'] ?? '').toString().trim(),
      createdAt: createdAtRaw.isEmpty ? null : DateTime.tryParse(createdAtRaw),
      target: ProfileListItem.fromJson(targetMap),
    );
  }
}

class ProfileRepository {
  ProfileRepository(this._dio);

  final Dio _dio;

  /// The object an answer carries, through the one envelope reader: a
  /// broken answer throws instead of becoming an empty profile.
  Map<String, dynamic> _unwrapMap(dynamic raw) => unwrapEnvelopeMap(raw);

  /// The list an answer carries (the list itself, or under `items`).
  /// Anything else throws: an empty list must mean there is nothing.
  List<Map<String, dynamic>> _unwrapItems(dynamic raw) {
    final data = unwrapEnvelope(raw);
    if (data is List) return unwrapEnvelopeList(raw);
    if (data is Map && data['items'] is List) {
      return unwrapEnvelopeList(raw, key: 'items');
    }
    throw const ApiEnvelopeException('profile list: no items');
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
  }

  Future<String> getFollowState(String handle) async {
    final detail = await getFollowStateDetail(handle);
    return detail.state;
  }

  Future<FollowStateDetail> getFollowStateDetail(String handle) async {
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
    await _dio.post('/users/$handle/follow/cancel');
  }

  Future<List<ProfileListItem>> getFollowers(String handle) async {
    final res = await _dio.get('/users/$handle/followers');
    final items = _unwrapItems(res.data);
    return items.map((e) => ProfileListItem.fromJson(e)).toList();
  }

  Future<List<ProfileListItem>> getFollowing(String handle) async {
    final res = await _dio.get('/users/$handle/following');
    final items = _unwrapItems(res.data);
    return items.map((e) => ProfileListItem.fromJson(e)).toList();
  }

  Future<List<FollowRequestInboxItem>> getFollowRequestsInbox() async {
    final res = await _dio.get('/users/me/follow/requests/inbox');
    final items = _unwrapItems(res.data);
    return items
        .map((e) => FollowRequestInboxItem.fromJson(e))
        .where((e) => e.id.isNotEmpty)
        .toList();
  }

  Future<List<FollowRequestOutboxItem>> getFollowRequestsOutbox() async {
    final res = await _dio.get('/users/me/follow/requests/outbox');
    final items = _unwrapItems(res.data);
    return items
        .map((e) => FollowRequestOutboxItem.fromJson(e))
        .where((e) => e.id.isNotEmpty)
        .toList();
  }

  Future<void> acceptFollowRequest(String id) async {
    await _dio.post('/users/me/follow/requests/$id/accept');
  }

  Future<void> declineFollowRequest(String id) async {
    await _dio.post('/users/me/follow/requests/$id/decline');
  }
}
