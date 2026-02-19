import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class AuthRepository {
  AuthRepository(this._dio);

  final Dio _dio;

  Map<String, dynamic> _unwrap(dynamic raw) {
    if (raw is! Map) throw Exception('Unexpected response');

    final m = Map<String, dynamic>.from(raw as Map);

    // New canonical envelope: { success: true, data: ... }
    if (m['success'] == true) {
      final inner = m['data'];
      if (inner is Map) return Map<String, dynamic>.from(inner as Map);
      if (inner is List) return {'items': inner};
      // If success=true but data is primitive, still return something stable
      return {'value': inner};
    }

    // Legacy shapes we still tolerate:
    // - { data: {...} }
    // - { user: {...} }
    final inner = m['data'] ?? m['user'];
    if (inner is Map) return Map<String, dynamic>.from(inner as Map);

    return m;
  }

  /// Register
  /// - Web: uses httpOnly refresh cookie; response typically { user, accessToken } under data envelope
  /// - Non-web: requests body transport so we also receive refreshToken in body
  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    String? handle,
    String? displayName,
  }) async {
    final wantsBodyTransport = !kIsWeb;

    final res = await _dio.post(
      '/auth/register',
      data: {
        'email': email,
        'password': password,
        if (handle != null && handle.trim().isNotEmpty) 'handle': handle.trim(),
        if (displayName != null && displayName.trim().isNotEmpty) 'displayName': displayName.trim(),
      },
      options: wantsBodyTransport ? Options(headers: {'x-token-transport': 'body'}) : null,
    );

    return _unwrap(res.data);
  }

  /// Login
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final wantsBodyTransport = !kIsWeb;

    final res = await _dio.post(
      '/auth/login',
      data: {'email': email, 'password': password},
      options: wantsBodyTransport ? Options(headers: {'x-token-transport': 'body'}) : null,
    );

    return _unwrap(res.data);
  }

  /// Refresh access token
  Future<Map<String, dynamic>> refresh({String? refreshToken}) async {
    final headers = <String, dynamic>{};
    dynamic body = <String, dynamic>{};

    if (!kIsWeb) {
      final rt = (refreshToken ?? '').trim();
      if (rt.isEmpty) {
        throw StateError('Missing refreshToken (non-web refresh requires body token)');
      }
      headers['x-token-transport'] = 'body';
      body = {'refreshToken': rt};
    }

    final res = await _dio.post(
      '/auth/refresh',
      data: body,
      options: headers.isEmpty ? null : Options(headers: headers),
    );

    return _unwrap(res.data);
  }

  Future<Map<String, dynamic>> logout({
    required String userId,
    String? refreshToken,
  }) async {
    final data = <String, dynamic>{
      'userId': userId.trim(),
      if (!kIsWeb && refreshToken != null && refreshToken.trim().isNotEmpty) 'refreshToken': refreshToken.trim(),
    };

    final res = await _dio.post('/auth/logout', data: data);
    return _unwrap(res.data);
  }

  Future<Map<String, dynamic>> logoutAll({required String userId}) async {
    final res = await _dio.post('/auth/logout-all', data: {'userId': userId.trim()});
    return _unwrap(res.data);
  }

  Future<Map<String, dynamic>> me() async {
    final res = await _dio.get('/auth/me');
    return _unwrap(res.data);
  }
}
