import 'package:dio/dio.dart';

import '../domain/announcement.dart';

class AnnouncementsRepository {
  AnnouncementsRepository(this._dio);

  final Dio _dio;

  List<Announcement>? _cachedList;
  List<Announcement>? _cachedPinned;

  DateTime? _listFetchedAt;
  DateTime? _pinnedFetchedAt;

  Future<List<Announcement>>? _listInFlight;
  Future<List<Announcement>>? _pinnedInFlight;

  static const _ttl = Duration(seconds: 30);

  bool _isFresh(DateTime? t) {
    if (t == null) return false;
    return DateTime.now().difference(t) < _ttl;
  }

  Map<String, dynamic> _asMap(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return Map<String, dynamic>.from(v);
    return {};
  }

  List<Map<String, dynamic>> _asList(dynamic v) {
    if (v is List) {
      return v
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return [];
  }

  Map<String, dynamic> _unwrapMap(dynamic raw) {
    final root = _asMap(raw);

    dynamic inner = root;

    if (inner.containsKey('ok') && inner.containsKey('data')) {
      inner = inner['data'];
    }

    if (inner is Map && inner['data'] is Map) {
      inner = inner['data'];
    }

    if (inner is Map && inner['item'] is Map) {
      inner = inner['item'];
    }

    if (inner is Map) {
      return Map<String, dynamic>.from(inner);
    }

    return {};
  }

  List<Map<String, dynamic>> _unwrapList(dynamic raw) {
    final root = _asMap(raw);

    if (root.containsKey('ok') && root.containsKey('data')) {
      return _unwrapList(root['data']);
    }

    if (root['items'] is List) {
      return _asList(root['items']);
    }

    if (root['data'] is List) {
      return _asList(root['data']);
    }

    if (root['item'] is Map) {
      return [_asMap(root['item'])];
    }

    return [];
  }

  Future<List<Announcement>> list() {
    if (_cachedList != null && _isFresh(_listFetchedAt)) {
      return Future.value(_cachedList);
    }

    if (_listInFlight != null) return _listInFlight!;

    _listInFlight = _fetchList();
    return _listInFlight!;
  }

  Future<List<Announcement>> _fetchList() async {
    final res = await _dio.get('/announcements');

    final items = _unwrapList(res.data)
        .map((e) => Announcement.fromJson(e))
        .toList();

    _cachedList = items;
    _listFetchedAt = DateTime.now();
    _listInFlight = null;

    return items;
  }

  Future<List<Announcement>> pinned() {
    if (_cachedPinned != null && _isFresh(_pinnedFetchedAt)) {
      return Future.value(_cachedPinned);
    }

    if (_pinnedInFlight != null) return _pinnedInFlight!;

    _pinnedInFlight = _fetchPinned();
    return _pinnedInFlight!;
  }

  Future<List<Announcement>> _fetchPinned() async {
    final res = await _dio.get('/announcements/pinned');

    final items = _unwrapList(res.data)
        .map((e) => Announcement.fromJson(e))
        .toList();

    _cachedPinned = items;
    _pinnedFetchedAt = DateTime.now();
    _pinnedInFlight = null;

    return items;
  }

  Future<Announcement?> getBySlug(String slug) async {
    final s = slug.trim();
    if (s.isEmpty) return null;

    final res = await _dio.get('/announcements/$s');
    final m = _unwrapMap(res.data);

    if (m.isEmpty) return null;

    return Announcement.fromJson(m);
  }

  Future<Announcement> createDraft({
    required String title,
    required String summary,
    String? excerpt,
    String? bodyMarkdown,
  }) async {
    final res = await _dio.post(
      '/admin/announcements',
      data: {
        'title': title,
        'summary': summary,
        if (excerpt != null && excerpt.isNotEmpty) 'excerpt': excerpt,
        if (bodyMarkdown != null && bodyMarkdown.isNotEmpty)
          'bodyMarkdown': bodyMarkdown,
      },
    );

    final m = _unwrapMap(res.data);
    return Announcement.fromJson(m);
  }

  Future<void> publish(String id) async {
    await _dio.post('/admin/announcements/$id/publish');
    _invalidateCache();
  }

  Future<void> unpublish(String id) async {
    await _dio.post('/admin/announcements/$id/unpublish');
    _invalidateCache();
  }

  Future<void> pin(String id) async {
    await _dio.post('/admin/announcements/$id/pin');
    _invalidateCache();
  }

  Future<void> unpin(String id) async {
    await _dio.post('/admin/announcements/$id/unpin');
    _invalidateCache();
  }

  Future<void> remove(String id) async {
    await _dio.delete('/admin/announcements/$id');
    _invalidateCache();
  }

  void _invalidateCache() {
    _cachedList = null;
    _cachedPinned = null;
    _listFetchedAt = null;
    _pinnedFetchedAt = null;
    _listInFlight = null;
    _pinnedInFlight = null;
  }
}