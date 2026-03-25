import 'dart:async';

import 'package:dio/dio.dart';

class NotificationsRepository {
  NotificationsRepository(this._dio);

  final Dio _dio;

  static const Duration _cacheTtl = Duration(seconds: 8);

  List<Map<String, dynamic>>? _cache;
  DateTime? _cacheAt;
  Future<_NotificationsPayload>? _inFlight;

  void clearCache() {
    _cache = null;
    _cacheAt = null;
    _inFlight = null;
  }

  Future<List<Map<String, dynamic>>> list({
    int limit = 20,
    String? cursor,
    bool forceRefresh = false,
  }) async {
    final now = DateTime.now();
    final useCache = (cursor == null || cursor.trim().isEmpty);

    if (useCache &&
        !forceRefresh &&
        _cache != null &&
        _cacheAt != null &&
        now.difference(_cacheAt!) < _cacheTtl) {
      return _cloneList(_cache!);
    }

    if (useCache && !forceRefresh && _inFlight != null) {
      final payload = await _inFlight!;
      return _cloneList(payload.items);
    }

    final future = _fetch(limit: limit, cursor: cursor);
    if (useCache) {
      _inFlight = future;
    }

    try {
      final payload = await future;
      if (useCache) {
        _cache = _cloneList(payload.items);
        _cacheAt = DateTime.now();
      }
      return _cloneList(payload.items);
    } finally {
      if (useCache) {
        _inFlight = null;
      }
    }
  }

  Future<String?> nextCursor({
    int limit = 20,
    String? cursor,
  }) async {
    final payload = await _fetch(limit: limit, cursor: cursor);
    return payload.nextCursor;
  }

  Future<int> unreadCount({bool forceRefresh = false}) async {
    final items = await list(limit: 50, forceRefresh: forceRefresh);
    return items.where((item) => _stringOf(item['readAt']).isEmpty).length;
  }

  Future<void> markRead(String id) async {
    await _dio.post('/notifications/$id/read');
    if (_cache != null) {
      _cache = _cache!
          .map(
            (item) => _stringOf(item['id']) == id
                ? {
                    ...item,
                    'readAt': item['readAt'] ?? DateTime.now().toIso8601String(),
                  }
                : item,
          )
          .toList(growable: false);
    }
  }

  Future<void> markAllRead() async {
    await _dio.post('/notifications/read-all');
    if (_cache != null) {
      final now = DateTime.now().toIso8601String();
      _cache = _cache!
          .map(
            (item) => {
              ...item,
              'readAt': _stringOf(item['readAt']).isEmpty ? now : item['readAt'],
            },
          )
          .toList(growable: false);
    }
  }

  Future<_NotificationsPayload> _fetch({
    required int limit,
    String? cursor,
  }) async {
    final res = await _dio.get(
      '/notifications',
      queryParameters: {
        'limit': limit,
        if (_hasText(cursor)) 'cursor': cursor,
      },
    );

    return _normalizePayload(res.data);
  }

  List<Map<String, dynamic>> _cloneList(List<Map<String, dynamic>> items) {
    return items.map((e) => Map<String, dynamic>.from(e)).toList();
  }
}

class _NotificationsPayload {
  const _NotificationsPayload({
    required this.items,
    required this.nextCursor,
  });

  final List<Map<String, dynamic>> items;
  final String? nextCursor;
}

_NotificationsPayload _normalizePayload(dynamic raw) {
  final root = _mapOf(raw);
  final data = _mapOf(root['data']);

  final candidates = <dynamic>[
    root['items'],
    root['notifications'],
    root['communications'],
    root['results'],
    root['data'],
    data['items'],
    data['notifications'],
    data['communications'],
    data['results'],
    data['data'],
  ];

  List<Map<String, dynamic>> items = const [];
  for (final candidate in candidates) {
    if (candidate is List) {
      items = candidate
          .whereType<Map>()
          .map((e) => _normalizeItem(Map<String, dynamic>.from(e)))
          .toList(growable: false);
      break;
    }
  }

  final nextCursor = _firstNonEmpty([
    _stringOf(root['nextCursor']),
    _stringOf(root['cursor']),
    _stringOf(data['nextCursor']),
    _stringOf(data['cursor']),
  ]);

  return _NotificationsPayload(
    items: items,
    nextCursor: nextCursor.isEmpty ? null : nextCursor,
  );
}

Map<String, dynamic> _normalizeItem(Map<String, dynamic> raw) {
  final actor = _extractActor(raw);
  final data = _extractData(raw);
  final post = _extractPost(raw);

  final normalized = <String, dynamic>{
    ...raw,
    'id': _firstNonEmpty([
      _stringOf(raw['id']),
      _stringOf(raw['notificationId']),
      _stringOf(raw['communicationId']),
    ]),
    'type': _firstNonEmpty([
      _stringOf(raw['type']),
      _stringOf(raw['eventType']),
      _stringOf(raw['kind']),
      _stringOf(data['type']),
      _stringOf(data['eventType']),
    ]).toUpperCase(),
    'createdAt': _firstNonEmpty([
      _stringOf(raw['createdAt']),
      _stringOf(raw['sentAt']),
      _stringOf(raw['updatedAt']),
    ]),
    'readAt': _firstNonEmpty([
      _stringOf(raw['readAt']),
      _stringOf(raw['openedAt']),
      _stringOf(raw['seenAt']),
    ]),
    'actor': actor,
    'data': data,
    'post': post,
    'postId': _firstNonEmpty([
      _stringOf(raw['postId']),
      _stringOf(post['id']),
      _stringOf(data['postId']),
      _stringOf(data['targetPostId']),
    ]),
    'spaceId': _firstNonEmpty([
      _stringOf(raw['spaceId']),
      _stringOf(data['spaceId']),
      _stringOf(data['targetSpaceId']),
    ]),
    'threadId': _firstNonEmpty([
      _stringOf(raw['threadId']),
      _stringOf(data['threadId']),
      _stringOf(data['targetThreadId']),
    ]),
    'announcementId': _firstNonEmpty([
      _stringOf(raw['announcementId']),
      _stringOf(data['announcementId']),
      _stringOf(data['targetAnnouncementId']),
    ]),
    'targetUrl': _firstNonEmpty([
      _stringOf(raw['targetUrl']),
      _stringOf(data['targetUrl']),
      _stringOf(data['url']),
      _stringOf(data['path']),
    ]),
  };

  return normalized;
}

Map<String, dynamic> _extractActor(Map<String, dynamic> raw) {
  final actorCandidates = <Map<String, dynamic>>[];

  for (final key in const ['actor', 'sender', 'author', 'user', 'profile']) {
    final value = raw[key];
    if (value is Map) {
      actorCandidates.add(Map<String, dynamic>.from(value));
    }
  }

  final data = _extractData(raw);
  final fallbackActor = <String, dynamic>{
    'displayName': _firstNonEmpty([
      _stringOf(data['actorName']),
      _stringOf(data['senderName']),
      _stringOf(data['displayName']),
    ]),
    'handle': _firstNonEmpty([
      _stringOf(data['actorHandle']),
      _stringOf(data['senderHandle']),
      _stringOf(data['handle']),
    ]),
    'avatarUrl': _firstNonEmpty([
      _stringOf(data['actorAvatarUrl']),
      _stringOf(data['senderAvatarUrl']),
      _stringOf(data['avatarUrl']),
    ]),
  };

  if (_hasAnyText(fallbackActor.values)) {
    actorCandidates.add(fallbackActor);
  }

  for (final actor in actorCandidates) {
    final displayName = _firstNonEmpty([
      _stringOf(actor['displayName']),
      _stringOf(actor['name']),
      _stringOf(actor['fullName']),
      _stringOf(actor['title']),
      _stringOf(actor['handle']),
    ]);

    final handle = _firstNonEmpty([
      _stringOf(actor['handle']),
      _stringOf(actor['username']),
      _stringOf(actor['slug']),
    ]);

    final avatarUrl = _firstNonEmpty([
      _stringOf(actor['avatarUrl']),
      _stringOf(actor['imageUrl']),
      _stringOf(actor['photoUrl']),
    ]);

    if (displayName.isNotEmpty || handle.isNotEmpty || avatarUrl.isNotEmpty) {
      return <String, dynamic>{
        'displayName': displayName,
        'handle': handle,
        'avatarUrl': avatarUrl,
      };
    }
  }

  return const <String, dynamic>{
    'displayName': '',
    'handle': '',
    'avatarUrl': '',
  };
}

Map<String, dynamic> _extractData(Map<String, dynamic> raw) {
  final direct = _mapOf(raw['data']);
  if (direct.isNotEmpty) return direct;

  final payload = _mapOf(raw['payload']);
  if (payload.isNotEmpty) return payload;

  final metadata = _mapOf(raw['metadata']);
  if (metadata.isNotEmpty) return metadata;

  return const {};
}

Map<String, dynamic> _extractPost(Map<String, dynamic> raw) {
  final post = _mapOf(raw['post']);
  if (post.isNotEmpty) return post;

  final data = _extractData(raw);
  final nestedPost = _mapOf(data['post']);
  if (nestedPost.isNotEmpty) return nestedPost;

  return const {};
}

Map<String, dynamic> _mapOf(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, val) => MapEntry(key.toString(), val));
  }
  return const {};
}

String _stringOf(dynamic value) {
  if (value == null) return '';
  return value.toString().trim();
}

String _firstNonEmpty(List<String> values) {
  for (final value in values) {
    if (value.trim().isNotEmpty) return value.trim();
  }
  return '';
}

bool _hasAnyText(Iterable<dynamic> values) {
  for (final value in values) {
    if (_stringOf(value).isNotEmpty) return true;
  }
  return false;
}

bool _hasText(String? value) => value != null && value.trim().isNotEmpty;
