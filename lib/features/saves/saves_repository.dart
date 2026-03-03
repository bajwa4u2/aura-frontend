import 'package:dio/dio.dart';

import '../feed/domain/post.dart';

class SavesRepository {
  SavesRepository(this._dio);
  final Dio _dio;

  /// Canonical (clean REST):
  ///   GET /saves?limit=...
  /// Backend controller: @Get() on /v1/saves
  Future<List<Post>> listSaved({int limit = 20}) async {
    final res = await _dio.get('/saves', queryParameters: {'limit': limit});
    final raw = res.data;

    // Accept envelope: { ok: true, data: { items: [...] } }
    // Also tolerate direct list (defensive).
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => Post.fromJson(e.cast<String, dynamic>()))
          .toList();
    }

    final Map data = (raw is Map && raw['data'] is Map) ? (raw['data'] as Map) : const {};
    final List items = (data['items'] is List) ? (data['items'] as List) : const [];

    return items
        .whereType<Map>()
        .map((e) => Post.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  /// Backend: POST /v1/saves/toggle/:postId
  Future<void> toggleSave(String postId) async {
    await _dio.post('/saves/toggle/$postId');
  }

  /// Backend: GET /v1/saves/for/:postId
  /// Expected: { ok: true, data: { saved: bool } } OR { saved: bool }
  Future<bool> isSaved(String postId) async {
    final res = await _dio.get('/saves/for/$postId');
    final raw = res.data;

    if (raw is Map) {
      if (raw['saved'] is bool) return raw['saved'] as bool;

      final d = raw['data'];
      if (d is Map && d['saved'] is bool) return d['saved'] as bool;
    }

    return false;
  }
}