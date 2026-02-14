import 'package:dio/dio.dart';

import '../feed/domain/post.dart';

class SavesRepository {
  SavesRepository(this._dio);
  final Dio _dio;

  /// GET /saves?limit=...
  Future<List<Post>> listSaved({int limit = 20}) async {
    final res = await _dio.get('/saves', queryParameters: {'limit': limit});
    final data = res.data;

    final List items = (data is Map && data['data'] is List)
        ? (data['data'] as List)
        : const [];

    return items
        .whereType<Map>()
        .map((e) => Post.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  /// POST /saves/:postId/toggle
  Future<void> toggleSave(String postId) async {
    await _dio.post('/saves/$postId/toggle');
  }

  /// GET /saves/:postId -> { saved: true } (fallback supported)
  Future<bool> isSaved(String postId) async {
    final res = await _dio.get('/saves/$postId');
    final body = res.data;
    if (body is Map) {
      final v = body['saved'] ?? body['isSaved'] ?? body['data'];
      if (v is bool) return v;
      if (v is Map) {
        final inner = v['saved'] ?? v['isSaved'];
        if (inner is bool) return inner;
      }
    }
    return false;
  }
}
