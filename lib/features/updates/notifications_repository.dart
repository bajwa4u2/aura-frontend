import '../../app/route_targets.dart';
import 'dart:async';

import 'package:dio/dio.dart';

class NotificationsRepository {
  NotificationsRepository(this._dio);

  final Dio _dio;

  static const Duration _cacheTtl = Duration(seconds: 8);

  List<Map<String, dynamic>>? _cache;
  DateTime? _cacheAt;
  Future<_NotificationsPayload>? _inFlight;
  final Set<String> _readInFlight = <String>{};

  void clearCache() {
    _cache = null;
    _cacheAt = null;
    _inFlight = null;
  }

  Future<List<Map<String, dynamic>>> list({
    int limit = 30,
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
      final dedupedItems = _dedupItems(payload.items);
      if (useCache) {
        _cache = _cloneList(dedupedItems);
        _cacheAt = DateTime.now();
      }
      return _cloneList(dedupedItems);
    } finally {
      if (useCache) {
        _inFlight = null;
      }
    }
  }

  Future<String?> nextCursor({
    int limit = 30,
    String? cursor,
  }) async {
    final payload = await _fetch(limit: limit, cursor: cursor);
    return payload.nextCursor;
  }

  Future<int> unreadCount({bool forceRefresh = false}) async {
    final items = await list(limit: 30, forceRefresh: forceRefresh);
    return items.where((item) => _stringOf(item['readAt']).isEmpty).length;
  }

  Future<void> markRead(String id) async {
    final trimmed = id.trim();
    if (trimmed.isEmpty) return;
    if (_readInFlight.contains(trimmed) || _isCachedAsRead(trimmed)) return;

    _readInFlight.add(trimmed);
    try {
      await _dio.post('/notifications/$trimmed/read');
      _markCachedRead(trimmed);
    } finally {
      _readInFlight.remove(trimmed);
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

  bool _isCachedAsRead(String id) {
    final cache = _cache;
    if (cache == null) return false;
    for (final item in cache) {
      if (_stringOf(item['id']) == id && _stringOf(item['readAt']).isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  void _markCachedRead(String id) {
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

  List<Map<String, dynamic>> _dedupItems(List<Map<String, dynamic>> items) {
    final seen = <String>{};
    final out = <Map<String, dynamic>>[];

    for (final item in items) {
      final dedupKey = _stringOf(item['dedupKey']);
      if (dedupKey.isEmpty) {
        out.add(Map<String, dynamic>.from(item));
        continue;
      }
      if (seen.contains(dedupKey)) {
        continue;
      }
      seen.add(dedupKey);
      out.add(Map<String, dynamic>.from(item));
    }

    return out;
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
    root['results'],
    root['data'],
    data['items'],
    data['notifications'],
    data['results'],
    data['data'],
  ];

  List<Map<String, dynamic>> items = const [];
  for (final candidate in candidates) {
    if (candidate is List) {
      items = candidate
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
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
    items: items.map(_normalizeNotificationItem).toList(growable: false),
    nextCursor: nextCursor.isEmpty ? null : nextCursor,
  );
}

Map<String, dynamic> _normalizeNotificationItem(Map<String, dynamic> raw) {
  final item = Map<String, dynamic>.from(raw);
  final data = _mapOf(item['data']);
  final payload = _mapOf(data['payload']);
  final target = _mapOf(data['target']);
  final session = _mapOf(data['session']);
  final live = _mapOf(data['live']);

  final sessionMeta = (session['metadata'] is Map)
      ? Map<String, dynamic>.from(session['metadata'])
      : const {};

  final metaThreadId = _stringOf(sessionMeta['threadId']);
  final metaSpaceId = _stringOf(sessionMeta['spaceId']);

  final announcementId = _firstNonEmpty([
    _stringOf(item['announcementId']),
    _stringOf(data['announcementId']),
  ]);
  final announcementSlug = _firstNonEmpty([
    _stringOf(item['announcementSlug']),
    _stringOf(data['announcementSlug']),
    _stringOf(data['slug']),
  ]);

  final threadId = _firstNonEmpty([
    _stringOf(item['threadId']),
    _stringOf(data['threadId']),
    _stringOf(payload['threadId']),
    _stringOf(target['threadId']),
    _stringOf(live['threadId']),
    metaThreadId,
  ]);

  final spaceId = _firstNonEmpty([
    _stringOf(item['spaceId']),
    _stringOf(data['spaceId']),
    _stringOf(payload['spaceId']),
    _stringOf(target['spaceId']),
    _stringOf(live['spaceId']),
    _stringOf(item['surfaceId']),
    metaSpaceId,
    _stringOf(data['surfaceId']),
  ]);

  final sessionId = _firstNonEmpty([
    _stringOf(item['sessionId']),
    _stringOf(data['sessionId']),
    _stringOf(payload['sessionId']),
    _stringOf(session['id']),
    _stringOf(session['sessionId']),
    _stringOf(live['sessionId']),
    _stringOf(item['realtimeSessionId']),
    _stringOf(data['realtimeSessionId']),
  ]);

  final realtimeType = _firstNonEmpty([
    _stringOf(item['realtimeType']),
    _stringOf(data['realtimeType']),
    _stringOf(data['notificationKind']),
    _stringOf(payload['realtimeType']),
    _stringOf(payload['notificationKind']),
    sessionId.isNotEmpty ? 'REALTIME_INVITE' : '',
  ]);

  final deeplink = normalizeMemberFacingRoute(
    _firstNonEmpty([
      _stringOf(item['deeplink']),
      _stringOf(data['deeplink']),
      _stringOf(payload['deeplink']),
      _stringOf(data['link']),
      _stringOf(data['url']),
      threadId.isNotEmpty && spaceId.isNotEmpty
          ? '/me/correspondence/$spaceId/thread/$threadId'
          : '',
      threadId.isNotEmpty ? '/threads/$threadId' : '',
      spaceId.isNotEmpty ? '/spaces/$spaceId' : '',
      announcementSlug.isNotEmpty ? '/announcements/$announcementSlug' : '',
      announcementId.isNotEmpty ? '/announcements/$announcementId' : '',
    ]),
    fallback: '',
  );

  final dedupKey = _logicalDedupKey(
    threadId: threadId,
    spaceId: spaceId,
    sessionId: sessionId,
    realtimeType: realtimeType,
    announcementId: announcementId,
    announcementSlug: announcementSlug,
    type: _stringOf(item['type']),
    deeplink: deeplink,
  );

  final mergedData = <String, dynamic>{
    ...data,
    if (threadId.isNotEmpty) 'threadId': threadId,
    if (spaceId.isNotEmpty) 'spaceId': spaceId,
    if (sessionId.isNotEmpty) 'sessionId': sessionId,
    if (realtimeType.isNotEmpty) 'realtimeType': realtimeType,
    if (deeplink.isNotEmpty) 'deeplink': deeplink,
    if (dedupKey.isNotEmpty) 'dedupKey': dedupKey,
  };

  return <String, dynamic>{
    ...item,
    'data': mergedData,
    if (threadId.isNotEmpty) 'threadId': threadId,
    if (spaceId.isNotEmpty) 'spaceId': spaceId,
    if (sessionId.isNotEmpty) 'sessionId': sessionId,
    if (realtimeType.isNotEmpty) 'realtimeType': realtimeType,
    if (deeplink.isNotEmpty) 'deeplink': deeplink,
    if (dedupKey.isNotEmpty) 'dedupKey': dedupKey,
  };
}

String _logicalDedupKey({
  required String threadId,
  required String spaceId,
  required String sessionId,
  required String realtimeType,
  required String announcementId,
  required String announcementSlug,
  required String type,
  required String deeplink,
}) {
  final parts = <String>[
    if (type.isNotEmpty) type,
    if (realtimeType.isNotEmpty) realtimeType,
    if (sessionId.isNotEmpty) sessionId,
    if (threadId.isNotEmpty) threadId,
    if (spaceId.isNotEmpty) spaceId,
    if (announcementId.isNotEmpty) announcementId,
    if (announcementSlug.isNotEmpty) announcementSlug,
    if (deeplink.isNotEmpty) deeplink,
  ];
  return parts.join('|');
}

Map<String, dynamic> _mapOf(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.map((key, val) => MapEntry(key.toString(), val));
  return const <String, dynamic>{};
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

bool _hasText(String? value) => value != null && value.trim().isNotEmpty;
