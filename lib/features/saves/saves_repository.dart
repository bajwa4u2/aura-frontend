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

  bool _isNotFound(DioException e) => e.response?.statusCode == 404;

  bool _extractSaved(dynamic data) {
    if (data is bool) return data;
    if (data is Map) {
      final v1 = data['saved'];
      if (v1 is bool) return v1;
      final v2 = data['isSaved'];
      if (v2 is bool) return v2;

      // tolerate nested wrappers
      final inner = data['data'];
      if (inner is Map) {
        final a = inner['saved'];
        if (a is bool) return a;
        final b = inner['isSaved'];
        if (b is bool) return b;
      }
    }
    return false;
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
          return items.map((e) => Post.fromJson(e as Map<String, dynamic>)).toList();
        }
      }

      return <Post>[];
    } on DioException catch (e) {
      // If auth failed mid-flight (token expired, session revoked), fail soft.
      if (_isAuthFailure(e)) return <Post>[];
      rethrow;
    }
  }

  /// Canonical (new) contract:
  /// GET /v1/saves/:postId  -> { saved: bool }
  ///
  /// Back-compat (old) contract:
  /// GET /v1/saves/for/:postId -> bool | { saved: bool }
  Future<bool> isSaved(String postId) async {
    if (!_isAuthed()) return false;

    final pid = postId.trim();
    if (pid.isEmpty) return false;

    // 1) New endpoint
    try {
      final res = await _dio.get('/saves/$pid');
      return _extractSaved(res.data);
    } on DioException catch (e) {
      if (_isAuthFailure(e)) return false;

      // Visibility contract or route mismatch: treat 404 as not saved,
      // but also try legacy route if this is just an API version mismatch.
      if (_isNotFound(e)) {
        // Try legacy route once (safe back-compat).
        try {
          final res2 = await _dio.get('/saves/for/$pid');
          return _extractSaved(res2.data);
        } on DioException catch (e2) {
          if (_isAuthFailure(e2)) return false;
          if (_isNotFound(e2)) return false;
          rethrow;
        }
      }

      rethrow;
    }
  }

  /// Canonical (new) contract:
  /// POST /v1/saves/:postId/toggle -> { saved: bool }
  ///
  /// Back-compat (old) contract:
  /// POST /v1/saves/toggle/:postId -> bool | { saved: bool }
  Future<bool> toggle(String postId) async {
    if (!_isAuthed()) return false;

    final pid = postId.trim();
    if (pid.isEmpty) return false;

    // 1) New endpoint
    try {
      final res = await _dio.post('/saves/$pid/toggle');
      return _extractSaved(res.data) ? true : _extractSaved(res.data) == false ? false : true;
    } on DioException catch (e) {
      if (_isAuthFailure(e)) return false;

      // If the new route isn't available on some env, try legacy.
      if (_isNotFound(e)) {
        try {
          final res2 = await _dio.post('/saves/toggle/$pid');
          return _extractSaved(res2.data) ? true : _extractSaved(res2.data) == false ? false : true;
        } on DioException catch (e2) {
          if (_isAuthFailure(e2)) return false;
          if (_isNotFound(e2)) return false;
          rethrow;
        }
      }

      rethrow;
    }
  }
}