import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class AuthRepository {
  AuthRepository(this._dio);

  final Dio _dio;

  /// Register
  /// - Web: uses httpOnly refresh cookie; response typically { user, accessToken }
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

    final data = res.data;
    if (data is Map) return Map<String, dynamic>.from(data as Map);
    throw Exception('Unexpected response');
  }

  /// Login
  /// - Web: uses httpOnly refresh cookie; response typically { user, accessToken }
  /// - Non-web: requests body transport so we also receive refreshToken in body
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

    final data = res.data;
    if (data is Map) return Map<String, dynamic>.from(data as Map);
    throw Exception('Unexpected response');
  }

  /// Refresh access token
  /// - Web: cookie-only refresh; returns { accessToken }
  /// - Non-web: send refreshToken in body + request body transport, returns { accessToken, refreshToken, ... }
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

    final out = res.data;
    if (out is Map) return Map<String, dynamic>.from(out as Map);
    throw Exception('Unexpected response');
  }

  /// Logout requires userId + refresh token (cookie or body)
  Future<Map<String, dynamic>> logout({
    required String userId,
    String? refreshToken,
  }) async {
    final data = <String, dynamic>{
      'userId': userId.trim(),
      if (!kIsWeb && refreshToken != null && refreshToken.trim().isNotEmpty) 'refreshToken': refreshToken.trim(),
    };

    final res = await _dio.post('/auth/logout', data: data);

    final out = res.data;
    if (out is Map) return Map<String, dynamic>.from(out as Map);
    return {'ok': true};
  }

  Future<Map<String, dynamic>> logoutAll({required String userId}) async {
    final res = await _dio.post('/auth/logout-all', data: {'userId': userId.trim()});

    final out = res.data;
    if (out is Map) return Map<String, dynamic>.from(out as Map);
    return {'ok': true};
  }

  /// GET /auth/me returns: { data: ... }
  Future<Map<String, dynamic>> me() async {
    final res = await _dio.get('/auth/me');

    final raw = res.data;
    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw as Map);
      final inner = map['data'];
      if (inner is Map) return Map<String, dynamic>.from(inner as Map);
      // fallback if backend shape changes
      return map;
    }

    throw Exception('Unexpected response');
  }
}
