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

  final announcementId = _firstNonEmpty([
    _stringOf(item['announcementId']),
    _stringOf(data['announcementId']),
  ]);
  final announcementSlug = _firstNonEmpty([
    _stringOf(item['announcementSlug']),
    _stringOf(data['announcementSlug']),
    _stringOf(data['slug']),
  ]);
  final deeplink = _firstNonEmpty([
    _stringOf(item['deeplink']),
    _stringOf(data['deeplink']),
    announcementSlug.isNotEmpty ? '/announcements/$announcementSlug' : '',
    announcementId.isNotEmpty ? '/announcements/$announcementId' : '',
  ]);

  final mergedData = <String, dynamic>{
    ...data,
    if (announcementId.isNotEmpty) 'announcementId': announcementId,
    if (announcementSlug.isNotEmpty) 'announcementSlug': announcementSlug,
    if (deeplink.isNotEmpty) 'deeplink': deeplink,
  };

  return {
    ...item,
    if (announcementId.isNotEmpty) 'announcementId': announcementId,
    if (announcementSlug.isNotEmpty) 'announcementSlug': announcementSlug,
    if (deeplink.isNotEmpty) 'deeplink': deeplink,
    'data': mergedData,
  };
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

bool _hasText(String? value) => value != null && value.trim().isNotEmpty;
