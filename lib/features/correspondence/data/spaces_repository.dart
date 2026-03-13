import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/net/dio_provider.dart';

final spacesRepositoryProvider = Provider<SpacesRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return SpacesRepository(dio);
});

class SpacesRepository {
  SpacesRepository(this._dio);

  final Dio _dio;

  List<Map<String, dynamic>>? _cachedSpaces;
  DateTime? _cacheTime;

  static const Duration _cacheTTL = Duration(seconds: 30);

  Future<List<Map<String, dynamic>>> listMySpaces({
    int limit = 50,
    String? cursor,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh &&
        _cachedSpaces != null &&
        _cacheTime != null &&
        DateTime.now().difference(_cacheTime!) < _cacheTTL) {
      return _cachedSpaces!;
    }

    final cancelToken = CancelToken();

    final res = await _dio.get(
      '/spaces',
      queryParameters: {
        'limit': limit,
        if (_hasText(cursor)) 'cursor': cursor,
      },
      cancelToken: cancelToken,
    );

    final payload = _unwrapData(res.data);

    final items = _readListFromCommonKeys(
      payload,
      keys: const ['items', 'spaces', 'results', 'data'],
    );

    final spaces = items.map(_asMap).toList();

    _cachedSpaces = spaces;
    _cacheTime = DateTime.now();

    return spaces;
  }

  Future<Map<String, dynamic>> getSpace(String spaceId) async {
    final res = await _dio.get('/spaces/$spaceId');
    return _unwrapData(res.data);
  }

  Future<Map<String, dynamic>> createSpace({
    required String name,
    String? description,
    String visibility = 'PRIVATE',
    List<String> memberIds = const [],
  }) async {
    final body = <String, dynamic>{
      'name': name.trim(),
      'visibility': visibility.trim(),
      if (_hasText(description)) 'description': description!.trim(),
      if (memberIds.isNotEmpty) 'memberIds': memberIds,
    };

    final res = await _dio.post('/spaces', data: body);

    _invalidateCache();

    return _unwrapData(res.data);
  }

  Future<Map<String, dynamic>> updateSpace(
    String spaceId, {
    String? name,
    String? description,
    String? visibility,
  }) async {
    final body = <String, dynamic>{
      if (_hasText(name)) 'name': name!.trim(),
      if (_hasText(description)) 'description': description!.trim(),
      if (_hasText(visibility)) 'visibility': visibility!.trim(),
    };

    final res = await _dio.patch('/spaces/$spaceId', data: body);

    _invalidateCache();

    return _unwrapData(res.data);
  }

  Future<Map<String, dynamic>> inviteMember({
    required String spaceId,
    required String userId,
    String? role,
  }) async {
    final body = <String, dynamic>{
      'userId': userId.trim(),
      if (_hasText(role)) 'role': role!.trim(),
    };

    final res = await _dio.post('/spaces/$spaceId/invites', data: body);
    return _unwrapData(res.data);
  }

  Future<List<Map<String, dynamic>>> listInvites() async {
    final res = await _dio.get('/invites');

    final payload = _unwrapData(res.data);

    final items = _readListFromCommonKeys(
      payload,
      keys: const ['items', 'invites', 'results', 'data'],
    );

    return items.map(_asMap).toList();
  }

  Future<Map<String, dynamic>> respondToInvite({
    required String inviteId,
    required bool accept,
  }) async {
    final res = await _dio.post(
      '/invites/$inviteId/respond',
      data: {'action': accept ? 'accept' : 'decline'},
    );

    return _unwrapData(res.data);
  }

  Future<void> revokeInvite(String inviteId) async {
    await _dio.delete('/invites/$inviteId');
  }

  void _invalidateCache() {
    _cachedSpaces = null;
    _cacheTime = null;
  }
}

Map<String, dynamic> _unwrapData(dynamic raw) {
  final root = _asMap(raw);

  final data = root['data'];

  if (data is Map<String, dynamic>) return data;
  if (data is Map) return Map<String, dynamic>.from(data);

  return root;
}

List<dynamic> _readListFromCommonKeys(
  Map<String, dynamic> map, {
  required List<String> keys,
}) {
  for (final key in keys) {
    final value = map[key];

    if (value is List) {
      return value;
    }
  }

  return const [];
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;

  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }

  return <String, dynamic>{};
}

bool _hasText(String? value) {
  return value != null && value.trim().isNotEmpty;
}