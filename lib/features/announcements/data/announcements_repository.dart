import 'package:dio/dio.dart';

import '../domain/announcement.dart';

Map _asMap(dynamic v) => (v is Map) ? v : const {};
List _asList(dynamic v) => (v is List) ? v : const [];

Map<String, dynamic> _mapFrom(dynamic v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return Map<String, dynamic>.from(v);
  return <String, dynamic>{};
}

List<Map<String, dynamic>> _listOfMaps(dynamic v) {
  final l = _asList(v);
  return l.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
}

/// Unwraps single item maps from common API envelopes.
/// Handles:
/// - { ok:true, data:{ item:{...} } }
/// - { ok:true, data:{...} }
/// - { data:{ item:{...} } }
/// - { item:{...} }
/// - { ...item... }
Map<String, dynamic> _unwrapMap(dynamic raw) {
  final root = _mapFrom(raw);

  // Prefer { ok:true, data: ... } but don't require ok.
  final data = root['data'];

  if (data is Map) {
    final dataMap = _mapFrom(data);

    // { data: { item: {...} } }
    final item = dataMap['item'];
    if (item is Map) return _mapFrom(item);

    // { data: {...actual item...} }
    // (but avoid returning list containers)
    if (dataMap.containsKey('id') || dataMap.containsKey('slug') || dataMap.containsKey('title')) {
      return dataMap;
    }
  }

  // { item: {...} }
  final item = root['item'];
  if (item is Map) return _mapFrom(item);

  // root itself might already be the item
  if (root.containsKey('id') || root.containsKey('slug') || root.containsKey('title')) {
    return root;
  }

  return <String, dynamic>{};
}

/// Unwraps list items from common API envelopes.
/// Handles:
/// - { ok:true, data:{ items:[...] , nextCursor } }
/// - { ok:true, data:[...] }
/// - { data:{ items:[...] } }
/// - { items:[...] }
/// - { ok:true, data:{ item:{...} } }  -> returns [item]
List<Map<String, dynamic>> _unwrapList(dynamic raw) {
  final root = _mapFrom(raw);

  final data = root['data'];

  if (data is List) {
    return _listOfMaps(data);
  }

  if (data is Map) {
    final dataMap = _mapFrom(data);

    // { data: { items:[...] } }
    final items = dataMap['items'];
    if (items is List) return _listOfMaps(items);

    // { data: { item:{...} } } (fallback)
    final item = dataMap['item'];
    if (item is Map) return [_mapFrom(item)];
  }

  // { items:[...] }
  final items = root['items'];
  if (items is List) return _listOfMaps(items);

  // { item:{...} }
  final item = root['item'];
  if (item is Map) return [_mapFrom(item)];

  return <Map<String, dynamic>>[];
}

class AnnouncementsRepository {
  AnnouncementsRepository(this._dio);
  final Dio _dio;

  Future<List<Announcement>> list() async {
    final res = await _dio.get('/announcements');
    final items = _unwrapList(res.data);
    return items.map((e) => Announcement.fromJson(e)).toList();
  }

  /// Backend returns { item } (or { ok:true, data:{ item } }), normalize to List (0 or 1)
  Future<List<Announcement>> pinned() async {
    final res = await _dio.get('/announcements/pinned');
    final items = _unwrapList(res.data);
    return items.map((e) => Announcement.fromJson(e)).toList();
  }

  Future<Announcement?> getBySlug(String slug) async {
    final s = slug.trim();
    if (s.isEmpty) return null;

    final res = await _dio.get('/announcements/$s');
    final m = _unwrapMap(res.data);
    if (m.isEmpty) return null;

    return Announcement.fromJson(m);
  }
}