import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/net/dio_provider.dart';

class SavesRepository {
  SavesRepository(this._dio);
  final Dio _dio;

  /// GET /saves?limit=..&cursor=..
  Future<dynamic> listSaved({int limit = 24, String? cursor}) async {
    final res = await _dio.get(
      '/saves',
      queryParameters: {
        'limit': limit,
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
      },
    );

    final data = res.data;
    if (data is Map && data['items'] != null) return data['items'];
    return data;
  }

  /// GET /saves/for/:postId
  Future<bool> isSaved(String postId) async {
    final res = await _dio.get('/saves/for/$postId');
    final data = res.data;

    if (data is Map) {
      final v = data['saved'] ?? data['isSaved'];
      if (v is bool) return v;
    }
    if (data is bool) return data;

    return false;
  }

  /// POST /saves/toggle/:postId
  Future<bool> toggle(String postId) async {
    final res = await _dio.post('/saves/toggle/$postId');
    final data = res.data;

    if (data is Map) {
      final v = data['saved'] ?? data['isSaved'];
      if (v is bool) return v;
    }
    if (data is bool) return data;

    return true;
  }
}

final savesRepositoryProvider = Provider<SavesRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return SavesRepository(dio);
});