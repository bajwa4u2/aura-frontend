import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/session_providers.dart';
import '../../core/net/dio_provider.dart';
import '../feed/domain/post.dart';

final savesRepositoryProvider = Provider<SavesRepository>((ref) {
  return SavesRepository(
    ref,
    ref.read(dioProvider),
  );
});

class SavesRepository {
  SavesRepository(this._ref, this._dio);

  final Ref _ref;
  final Dio _dio;

  bool _isAuthed() {
    final status = _ref.read(authStatusProvider);
    return status == AuthStatus.authed;
  }

  bool _isAuthFailure(DioException e) {
    final code = e.response?.statusCode;
    return code == 401 || code == 403;
  }

  /// GET /v1/saves?limit=24&cursor=...
  Future<List<Post>> listSaved({int limit = 24, String? cursor}) async {
    // Hard gate: never call protected endpoints when not authed.
    if (!_isAuthed()) return <Post>[];

    try {
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
          return items
              .map((e) => Post.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      }

      return <Post>[];
    } on DioException catch (e) {
      // If auth failed mid-flight (token expired, session revoked), fail soft.
      if (_isAuthFailure(e)) return <Post>[];
      rethrow;
    }
  }

  /// GET /v1/saves/for/:postId
  Future<bool> isSaved(String postId) async {
    if (!_isAuthed()) return false;

    try {
      final res = await _dio.get('/saves/for/$postId');
      final data = res.data;
      if (data is bool) return data;
      if (data is Map && data['saved'] is bool) return data['saved'] as bool;
      return false;
    } on DioException catch (e) {
      if (_isAuthFailure(e)) return false;
      rethrow;
    }
  }

  /// POST /v1/saves/toggle/:postId
  Future<bool> toggle(String postId) async {
    if (!_isAuthed()) return false;

    try {
      final res = await _dio.post('/saves/toggle/$postId');
      final data = res.data;
      if (data is bool) return data;
      if (data is Map && data['saved'] is bool) return data['saved'] as bool;
      return true;
    } on DioException catch (e) {
      if (_isAuthFailure(e)) return false;
      rethrow;
    }
  }
}