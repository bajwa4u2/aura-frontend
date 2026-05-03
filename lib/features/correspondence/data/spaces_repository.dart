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

  static const Duration _spacesTtl = Duration(seconds: 60);
  static const Duration _invitesTtl = Duration(seconds: 30);

  List<Map<String, dynamic>>? _cache;
  DateTime? _cacheAt;
  Future<List<Map<String, dynamic>>>? _inFlight;

  List<Map<String, dynamic>>? _invitesCache;
  DateTime? _invitesCacheAt;
  Future<List<Map<String, dynamic>>>? _invitesInFlight;

  void clearCache() {
    _cache = null;
    _cacheAt = null;
    _inFlight = null;
    _invitesCache = null;
    _invitesCacheAt = null;
    _invitesInFlight = null;
  }

  Future<List<Map<String, dynamic>>> listMySpaces({
    int limit = 50,
    String? cursor,
    bool forceRefresh = false,
  }) async {
    final now = DateTime.now();
    final useCache = !_hasText(cursor);

    if (useCache &&
        !forceRefresh &&
        _cache != null &&
        _cacheAt != null &&
        now.difference(_cacheAt!) < _spacesTtl) {
      return _cloneList(_cache!);
    }

    if (useCache && !forceRefresh && _inFlight != null) {
      return _inFlight!;
    }

    final future = _fetchSpaces(limit: limit, cursor: cursor);
    if (useCache) {
      _inFlight = future;
    }

    try {
      final spaces = await future;
      if (useCache) {
        _cache = _cloneList(spaces);
        _cacheAt = DateTime.now();
      }
      return _cloneList(spaces);
    } finally {
      if (useCache) {
        _inFlight = null;
      }
    }
  }

  Future<List<Map<String, dynamic>>> _fetchSpaces({
    required int limit,
    String? cursor,
  }) async {
    final res = await _dio.get(
      '/spaces',
      queryParameters: {
        'limit': limit,
        if (_hasText(cursor)) 'cursor': cursor,
      },
    );

    final payload = _unwrapData(res.data);

    final items = _readListFromCommonKeys(
      payload,
      keys: const ['items', 'spaces', 'results', 'data'],
    );

    return items.map(_asMap).toList(growable: false);
  }

  List<Map<String, dynamic>> _cloneList(List<Map<String, dynamic>> items) {
    return items.map((e) => Map<String, dynamic>.from(e)).toList(growable: false);
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
      'type': 'PRIVATE',               // required by backend
      'title': name.trim(),            // backend uses title not name
      'visibility': visibility.trim(),
      if (_hasText(description)) 'description': description!.trim(),
      if (memberIds.isNotEmpty) 'participantIds': memberIds,
    };

    final res = await _dio.post('/spaces', data: body);

    return _unwrapData(res.data);
  }

  Future<Map<String, dynamic>> updateSpace(
    String spaceId, {
    String? name,
    String? description,
    String? visibility,
    bool? archived,
  }) async {
    final body = <String, dynamic>{
      if (_hasText(name)) 'title': name!.trim(),
      if (_hasText(description)) 'description': description!.trim(),
      if (_hasText(visibility)) 'visibility': visibility!.trim(),
      if (archived != null) 'archived': archived,
    };

    final res = await _dio.patch('/spaces/$spaceId', data: body);

    return _unwrapData(res.data);
  }

  Future<Map<String, dynamic>> inviteMember({
    required String spaceId,
    required String userId,
    String? role,
  }) async {
    final body = <String, dynamic>{
      'invitedUserId': userId.trim(),
      'roleOffered': _hasText(role) ? role!.trim() : 'MEMBER',
    };

    final res = await _dio.post('/spaces/$spaceId/invites', data: body);
    return _unwrapData(res.data);
  }

  Future<List<Map<String, dynamic>>> listInvites({
    bool forceRefresh = false,
  }) async {
    final now = DateTime.now();

    if (!forceRefresh &&
        _invitesCache != null &&
        _invitesCacheAt != null &&
        now.difference(_invitesCacheAt!) < _invitesTtl) {
      return _cloneList(_invitesCache!);
    }

    if (!forceRefresh && _invitesInFlight != null) {
      return _invitesInFlight!;
    }

    final future = _fetchInvites();
    _invitesInFlight = future;
    try {
      final invites = await future;
      _invitesCache = _cloneList(invites);
      _invitesCacheAt = DateTime.now();
      return _cloneList(invites);
    } finally {
      if (identical(_invitesInFlight, future)) {
        _invitesInFlight = null;
      }
    }
  }

  Future<List<Map<String, dynamic>>> _fetchInvites() async {
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
    await _dio.post('/invites/$inviteId/revoke');
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
