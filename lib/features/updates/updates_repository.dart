import 'dart:async';

import 'package:dio/dio.dart';

class UpdatesRepository {
  UpdatesRepository(this._dio);

  final Dio _dio;

  static const Duration _cacheTtl = Duration(seconds: 20);

  List<Map<String, dynamic>>? _cache;
  DateTime? _cacheAt;
  Future<List<Map<String, dynamic>>>? _inFlight;

  void clearCache() {
    _cache = null;
    _cacheAt = null;
    _inFlight = null;
  }

  Future<List<Map<String, dynamic>>> listUpdates({
    int limit = 24,
    bool forceRefresh = false,
  }) async {
    final now = DateTime.now();

    if (!forceRefresh &&
        _cache != null &&
        _cacheAt != null &&
        now.difference(_cacheAt!) < _cacheTtl) {
      return _cloneList(_cache!);
    }

    if (!forceRefresh && _inFlight != null) {
      return _inFlight!;
    }

    final future = _fetchAndNormalize(limit: limit);
    _inFlight = future;

    try {
      final items = await future;
      _cache = _cloneList(items);
      _cacheAt = DateTime.now();
      return _cloneList(items);
    } finally {
      _inFlight = null;
    }
  }

  Future<List<Map<String, dynamic>>> _fetchAndNormalize({required int limit}) async {
    final res = await _dio.get(
      '/updates',
      queryParameters: <String, dynamic>{'limit': limit},
    );

    final items = _extractItems(res.data);
    return List<Map<String, dynamic>>.generate(
      items.length,
      (index) => _normalizeItem(items[index], index),
      growable: false,
    );
  }

  List<Map<String, dynamic>> _cloneList(List<Map<String, dynamic>> items) {
    return items.map((e) => Map<String, dynamic>.from(e)).toList(growable: false);
  }

  List<Map<String, dynamic>> _extractItems(dynamic raw) {
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: false);
    }

    if (raw is Map) {
      final root = Map<String, dynamic>.from(raw);
      final data = root['data'] is Map ? Map<String, dynamic>.from(root['data']) : <String, dynamic>{};

      final candidates = <dynamic>[
        root['items'],
        root['data'],
        root['results'],
        root['updates'],
        root['announcements'],
        data['items'],
        data['data'],
        data['results'],
        data['updates'],
        data['announcements'],
      ];

      for (final candidate in candidates) {
        if (candidate is List) {
          return candidate
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList(growable: false);
        }
      }
    }

    return const <Map<String, dynamic>>[];
  }

  Map<String, dynamic> _normalizeItem(Map<String, dynamic> raw, int index) {
    final actor = _extractActor(raw);
    final type = _extractFirstString(raw, const [
      ['type'],
      ['eventType'],
      ['kind'],
      ['action'],
    ]).toLowerCase();

    final title = _extractFirstString(raw, const [
      ['title'],
      ['subject'],
      ['headline'],
      ['post', 'title'],
      ['target', 'title'],
    ]);

    final text = _cleanText(_extractFirstString(raw, const [
      ['message'],
      ['text'],
      ['body'],
      ['content'],
      ['excerpt'],
      ['summary'],
      ['post', 'content'],
      ['target', 'text'],
    ]));

    final createdAt = _extractFirstString(raw, const [
      ['createdAt'],
      ['updatedAt'],
      ['timestamp'],
      ['time'],
      ['insertedAt'],
    ]);

    final id = _extractFirstString(raw, const [
      ['id'],
      ['notificationId'],
      ['updateId'],
      ['postId'],
      ['target', 'id'],
      ['post', 'id'],
    ]);

    final targetUrl = _extractFirstString(raw, const [
      ['url'],
      ['path'],
      ['targetUrl'],
      ['target', 'url'],
      ['target', 'path'],
    ]);

    return <String, dynamic>{
      'id': id.isNotEmpty ? id : 'update_$index',
      'type': type.isNotEmpty ? type : 'update',
      'actor': actor,
      'headline': _buildHeadline(type: type, title: title, text: text),
      'detail': _buildDetail(type: type, title: title, text: text),
      'createdAt': createdAt,
      'targetUrl': targetUrl,
      'raw': raw,
    };
  }

  Map<String, dynamic> _extractActor(Map<String, dynamic> raw) {
    final actorCandidates = <Map<String, dynamic>>[];

    for (final key in const ['actor', 'author', 'user', 'profile', 'institution']) {
      final value = raw[key];
      if (value is Map) {
        actorCandidates.add(Map<String, dynamic>.from(value));
      }
    }

    for (final actor in actorCandidates) {
      final displayName = _extractFirstString(actor, const [
        ['displayName'],
        ['name'],
        ['fullName'],
        ['title'],
        ['handle'],
      ]).trim();

      final handle = _extractFirstString(actor, const [
        ['handle'],
        ['username'],
        ['slug'],
      ]).trim();

      if (displayName.isNotEmpty || handle.isNotEmpty) {
        return <String, dynamic>{
          'displayName': displayName.isNotEmpty ? displayName : handle,
          'handle': handle,
        };
      }
    }

    return const <String, dynamic>{
      'displayName': 'Aura',
      'handle': '',
    };
  }

  String _buildHeadline({
    required String type,
    required String title,
    required String text,
  }) {
    switch (type) {
      case 'announcement':
        return 'Announcement';
      case 'institution_verified':
        return 'Institution verified';
      case 'post_published':
      case 'post':
        return 'Published';
      case 'release':
        return 'Release';
      default:
        break;
    }

    if (title.isNotEmpty) return title;
    if (text.isNotEmpty) return 'Update';
    return 'Aura update';
  }

  String _buildDetail({
    required String type,
    required String title,
    required String text,
  }) {
    if (text.isNotEmpty) return text;
    if (title.isNotEmpty && title != _buildHeadline(type: type, title: title, text: text)) {
      return title;
    }

    switch (type) {
      case 'announcement':
        return 'A new announcement is available.';
      case 'institution_verified':
        return 'Standing changed.';
      case 'post_published':
      case 'post':
        return 'A new piece has been published.';
      case 'release':
        return 'A product change was recorded.';
      default:
        return 'A new change was recorded.';
    }
  }

  String _extractFirstString(
    Map<String, dynamic> source,
    List<List<String>> paths,
  ) {
    for (final path in paths) {
      dynamic current = source;
      for (final segment in path) {
        if (current is Map && current.containsKey(segment)) {
          current = current[segment];
        } else {
          current = null;
          break;
        }
      }
      if (current == null) continue;
      final value = current.toString().trim();
      if (value.isNotEmpty && value.toLowerCase() != 'null') {
        return value;
      }
    }
    return '';
  }

  String _cleanText(String input) {
    final compact = input.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (compact.isEmpty) return '';
    const maxLength = 160;
    if (compact.length <= maxLength) return compact;
    return '${compact.substring(0, maxLength - 1).trim()}…';
  }

  Future<void> markRead(String id) async {}

  Future<void> markAllRead() async {}
}
