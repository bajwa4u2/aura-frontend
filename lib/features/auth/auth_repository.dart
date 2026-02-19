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
      '/v1/auth/register',
      data: {
        'email': email,
        'password': password,
        if (handle != null && handle.trim().isNotEmpty)
          'handle': handle.trim(),
        if (displayName != null && displayName.trim().isNotEmpty)
          'displayName': displayName.trim(),
      },
    );

    return _extractData(res);
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final res = await _dio.post(
      '/v1/auth/login',
      data: {
        'email': email,
        'password': password,
      },
    );

    final data = _extractData(res);

    final accessToken = data['accessToken'];
    final refreshToken = data['refreshToken'];

    if (accessToken == null || accessToken is! String) {
      throw Exception('Missing accessToken');
    }

    if (refreshToken == null || refreshToken is! String) {
      throw Exception('Missing refreshToken');
    }

    return data;
  }

  Map<String, dynamic> _extractData(Response res) {
    final body = res.data;

    if (body is Map<String, dynamic>) {
      if (body['success'] == true && body['data'] is Map<String, dynamic>) {
        return Map<String, dynamic>.from(body['data']);
      }
    }

    throw Exception('Unexpected API response shape');
  }
}
