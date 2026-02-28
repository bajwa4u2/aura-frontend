import 'package:dio/dio.dart';

import '../feed/domain/post.dart';

class SavesRepository {
  SavesRepository(this._dio);
  final Dio _dio;

  /// Canonical: GET /saves/me?limit=...
  /// Response envelope: { ok: true, data: { items: [...], nextCursor: <postId|null> } }
  Future<List<Post>> listSaved({int limit = 20}) async {
    final res = await _dio.get('/saves/me', queryParameters: {'limit': limit});
    final raw = res.data;

    final Map data = (raw is Map && raw['data'] is Map) ? (raw['data'] as Map) : const {};
    final List items = (data['items'] is List) ? (data['items'] as List) : const [];

    return items
        .whereType<Map>()
        .map((e) => Post.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  Future<void> toggleSave(String postId) async {
    await _dio.post('/saves/$postId/toggle');
  }

  Future<bool> isSaved(String postId) async {
    final res = await _dio.get('/saves/$postId');
    final raw = res.data;

    final Map data = (raw is Map && raw['data'] is Map) ? (raw['data'] as Map) : const {};
    final v = data['saved'];
    return v is bool ? v : false;
  }
}
