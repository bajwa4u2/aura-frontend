import 'package:dio/dio.dart';

class AuthRepository {
  AuthRepository(this._dio);

  final Dio _dio;

  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    String? handle,
    String? displayName,
  }) async {
    final res = await _dio.post(
      '/auth/register',
      data: {
        'email': email,
        'password': password,
        if (handle != null && handle.trim().isNotEmpty) 'handle': handle.trim(),
        if (displayName != null && displayName.trim().isNotEmpty) 'displayName': displayName.trim(),
      },
    );

    final data = res.data;
    if (data is Map) return Map<String, dynamic>.from(data as Map);
    throw Exception('Unexpected response');
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final res = await _dio.post(
      '/auth/login',
      data: {'email': email, 'password': password},
    );

    final data = res.data;
    if (data is Map) return Map<String, dynamic>.from(data as Map);
    throw Exception('Unexpected response');
  }

  Future<Map<String, dynamic>> refresh({
    String? refreshToken,
    bool bodyTransport = false,
  }) async {
    // If bodyTransport=true, send refreshToken in body and ask server for body transport.
    final headers = <String, dynamic>{};
    dynamic data = <String, dynamic>{};

    if (bodyTransport) {
      if (refreshToken == null || refreshToken.trim().isEmpty) {
        throw StateError('Missing refreshToken for body transport');
      }
      headers['x-token-transport'] = 'body';
      data = {'refreshToken': refreshToken.trim()};
    }

    final res = await _dio.post(
      '/auth/refresh',
      data: data,
      options: Options(headers: headers),
    );

    final out = res.data;
    if (out is Map) return Map<String, dynamic>.from(out as Map);
    throw Exception('Unexpected response');
  }

  Future<void> logout({String? refreshToken}) async {
    dynamic data = <String, dynamic>{};
    if (refreshToken != null && refreshToken.trim().isNotEmpty) {
      data = {'refreshToken': refreshToken.trim()};
    }
    await _dio.post('/auth/logout', data: data);
  }

  Future<void> logoutAll() async {
    await _dio.post('/auth/logout-all');
  }
}
