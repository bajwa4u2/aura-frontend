import 'package:dio/dio.dart';

import '../domain/announcement.dart';

Map _asMap(dynamic v) => (v is Map) ? v : const {};
List _asList(dynamic v) => (v is List) ? v : const [];

Map<String, dynamic> _unwrapMap(dynamic raw) {
  final root = _asMap(raw);

  // Common API wrapper: { data: {...} }
  final data = root['data'];
  if (data is Map) return Map<String, dynamic>.from(data);

  // Your announcements endpoints: { item: {...} }
  final item = root['item'];
  if (item is Map) return Map<String, dynamic>.from(item);

  // Fallback: treat root as the map
  try {
    return Map<String, dynamic>.from(root.cast<String, dynamic>());
  } catch (_) {
    return <String, dynamic>{};
  }
}

List<Map<String, dynamic>> _unwrapList(dynamic raw) {
  final root = _asMap(raw);

  // Common wrapper: { data: [...] } or { data: { items: [...] } }
  final data = root['data'];
  if (data is List) {
    return data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }
  if (data is Map) {
    final items = data['items'];
    if (items is List) {
      return items.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
  }

  // Your list endpoint: { items: [...] }
  final items = root['items'];
  if (items is List) {
    return items.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  // Your pinned endpoint: { item: {...} }
  final item = root['item'];
  if (item is Map) {
    return [Map<String, dynamic>.from(item)];
  }

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

  /// Backend returns { item }, we normalize to List (0 or 1)
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