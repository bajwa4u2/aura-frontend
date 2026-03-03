import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/net/dio_provider.dart';
import '../feed/domain/post.dart';

final savesRepositoryProvider = Provider<SavesRepository>((ref) {
  return SavesRepository(ref.read(dioProvider));
});

class SavesRepository {
  SavesRepository(this._dio);

  final Dio _dio;

  /// GET /v1/saves?limit=24&cursor=...
  Future<List<Post>> listSaved({int limit = 24, String? cursor}) async {
    final res = await _dio.get(
      '/saves',
      queryParameters: {
        'limit': limit,
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
      },
    );

    final data = res.data;
    if (data is List) {
      return data.map((e) => Post.fromJson(e as Map<String, dynamic>)).toList();
    }

    // If backend returns { items: [...] }, support that too.
    if (data is Map<String, dynamic>) {
      final items = data['items'];
      if (items is List) {
        return items.map((e) => Post.fromJson(e as Map<String, dynamic>)).toList();
      }
    }

    return <Post>[];
  }

  /// GET /v1/saves/for/:postId
  Future<bool> isSaved(String postId) async {
    final res = await _dio.get('/saves/for/$postId');
    final data = res.data;
    if (data is bool) return data;
    if (data is Map && data['saved'] is bool) return data['saved'] as bool;
    return false;
  }

  /// POST /v1/saves/toggle/:postId
  Future<bool> toggle(String postId) async {
    final res = await _dio.post('/saves/toggle/$postId');
    final data = res.data;
    if (data is bool) return data;
    if (data is Map && data['saved'] is bool) return data['saved'] as bool;
    return true;
  }
}