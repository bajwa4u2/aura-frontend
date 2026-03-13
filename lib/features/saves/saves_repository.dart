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

  Set<String>? _savedPostIdsCache;
  bool _loadingCache = false;

  bool _isAuthed() {
    final status = _ref.read(authStatusProvider);
    return status == AuthStatus.authed;
  }

  bool _isAuthFailure(DioException e) {
    final code = e.response?.statusCode;
    return code == 401 || code == 403;
  }

  void _clearSavedCache() {
    _savedPostIdsCache = null;
    _loadingCache = false;
  }

  bool _extractSaved(dynamic data) {
    if (data is bool) return data;

    if (data is Map) {
      final v1 = data['saved'];
      if (v1 is bool) return v1;

      final v2 = data['isSaved'];
      if (v2 is bool) return v2;

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

  List<Map<String, dynamic>> _extractItems(dynamic data) {
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    if (data is Map<String, dynamic>) {
      final items = data['items'];
      if (items is List) {
        return items
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }

      final directData = data['data'];
      if (directData is List) {
        return directData
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }

      if (directData is Map) {
        final nestedItems = directData['items'];
        if (nestedItems is List) {
          return nestedItems
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }

        final nestedData = directData['data'];
        if (nestedData is List) {
          return nestedData
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      }
    }

    return <Map<String, dynamic>>[];
  }

  String? _extractSavedPostId(Map<String, dynamic> item) {
    final postId = (item['postId'] ?? '').toString().trim();
    if (postId.isNotEmpty) return postId;

    final nestedPost = item['post'];
    if (nestedPost is Map) {
      final nestedPostId = (nestedPost['id'] ?? '').toString().trim();
      if (nestedPostId.isNotEmpty) return nestedPostId;
    }

    final directId = (item['id'] ?? '').toString().trim();
    if (directId.isNotEmpty) return directId;

    return null;
  }

  Set<String> _buildSavedPostIdsCache(List<Map<String, dynamic>> items) {
    final ids = <String>{};

    for (final item in items) {
      final id = _extractSavedPostId(item);
      if (id != null && id.isNotEmpty) {
        ids.add(id);
      }
    }

    return ids;
  }

  Future<List<Map<String, dynamic>>> _fetchSavedRaw({
    int limit = 100,
    String? cursor,
  }) async {
    if (!_isAuthed()) return <Map<String, dynamic>>[];

    try {
      final res = await _dio.get(
        '/saves/me',
        queryParameters: {
          'limit': limit,
          if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
        },
      );

      return _extractItems(res.data);
    } on DioException catch (e) {
      if (_isAuthFailure(e)) return <Map<String, dynamic>>[];
      rethrow;
    }
  }

  Future<void> _ensureSavedCacheLoaded() async {
    if (_savedPostIdsCache != null || _loadingCache) return;

    _loadingCache = true;

    try {
      final items = await _fetchSavedRaw(limit: 200);
      _savedPostIdsCache = _buildSavedPostIdsCache(items);
    } finally {
      _loadingCache = false;
    }
  }

  /// Canonical saved-list read.
  Future<List<Post>> listSaved({int limit = 24, String? cursor}) async {
    final items = await _fetchSavedRaw(limit: limit, cursor: cursor);

    _savedPostIdsCache = _buildSavedPostIdsCache(items);

    return items
        .map((e) => Post.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Safe saved-state check.
  Future<bool> isSaved(String postId) async {
    if (!_isAuthed()) return false;

    final pid = postId.trim();
    if (pid.isEmpty) return false;

    try {
      await _ensureSavedCacheLoaded();
      return _savedPostIdsCache?.contains(pid) ?? false;
    } on DioException catch (e) {
      if (_isAuthFailure(e)) {
        _clearSavedCache();
        return false;
      }
      rethrow;
    }
  }

  /// Toggle save state
  /// POST /v1/saves/:postId/toggle -> { saved: bool }
  Future<bool> toggle(String postId) async {
    if (!_isAuthed()) return false;

    final pid = postId.trim();
    if (pid.isEmpty) return false;

    try {
      final res = await _dio.post('/saves/$pid/toggle');
      final saved = _extractSaved(res.data);

      _savedPostIdsCache ??= <String>{};

      if (saved) {
        _savedPostIdsCache!.add(pid);
      } else {
        _savedPostIdsCache!.remove(pid);
      }

      return saved;
    } on DioException catch (e) {
      if (_isAuthFailure(e)) {
        _clearSavedCache();
        return false;
      }
      rethrow;
    }
  }
}