import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/net/dio_provider.dart';

class SavesRepository {
  SavesRepository(this._dio);

  final Dio _dio;

  Future<Map<String, dynamic>> listMine({int? limit, String? cursor}) async {
    final res = await _dio.get(
      '/saves',
      queryParameters: {
        if (limit != null) 'limit': limit,
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
      },
    );

    final data = res.data;
    if (data is Map<String, dynamic>) return data;
    throw Exception('Invalid response for /saves');
  }

  Future<bool> isSaved(String postId) async {
    final res = await _dio.get('/saves/for/$postId');
    final data = res.data;
    if (data is Map && data['saved'] is bool) return data['saved'] as bool;
    // if backend returns boolean directly, tolerate that too
    if (data is bool) return data;
    throw Exception('Invalid response for /saves/for/:postId');
  }

  Future<Map<String, dynamic>> toggle(String postId) async {
    final res = await _dio.post('/saves/toggle/$postId');
    final data = res.data;
    if (data is Map<String, dynamic>) return data;
    throw Exception('Invalid response for /saves/toggle/:postId');
  }
}

final savesRepositoryProvider = Provider<SavesRepository>((ref) {
  final dio = ref.read(dioProvider);
  return SavesRepository(dio);
});