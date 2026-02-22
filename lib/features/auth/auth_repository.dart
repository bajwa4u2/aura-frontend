import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class AuthRepository {
  AuthRepository(this._dio);

  final Dio _dio;

  Map<String, dynamic> _unwrap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    throw Exception('Unexpected response');
  }

  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String? handle,
    String? displayName,
  }) async {
    final wantsBodyTransport = !kIsWeb;

    final res = await _dio.post(
      '/v1/auth/register',
      data: {
        'email': email.trim(),
        'password': password,
        'firstName': firstName.trim(),
        'lastName': lastName.trim(),
        if (handle != null && handle.trim().isNotEmpty) 'handle': handle.trim(),
        if (displayName != null && displayName.trim().isNotEmpty) 'displayName': displayName.trim(),
      },
      options: wantsBodyTransport ? Options(headers: {'x-token-transport': 'body'}) : null,
    );

    return _unwrap(res.data);
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final wantsBodyTransport = !kIsWeb;

    final res = await _dio.post(
      '/v1/auth/login',
      data: {'email': email.trim(), 'password': password},
      options: wantsBodyTransport ? Options(headers: {'x-token-transport': 'body'}) : null,
    );

    return _unwrap(res.data);
  }

  Future<Map<String, dynamic>> refresh({
    required String refreshToken,
  }) async {
    final wantsBodyTransport = !kIsWeb;

    final res = await _dio.post(
      '/v1/auth/refresh',
      data: {'refreshToken': refreshToken},
      options: wantsBodyTransport ? Options(headers: {'x-token-transport': 'body'}) : null,
    );

    return _unwrap(res.data);
  }

  Future<Map<String, dynamic>> logout({
    required String refreshToken,
  }) async {
    final wantsBodyTransport = !kIsWeb;

    final res = await _dio.post(
      '/v1/auth/logout',
      data: {'refreshToken': refreshToken},
      options: wantsBodyTransport ? Options(headers: {'x-token-transport': 'body'}) : null,
    );

    return _unwrap(res.data);
  }

  Future<Map<String, dynamic>> resendVerification({
    required String email,
  }) async {
    final res = await _dio.post(
      '/v1/auth/resend-verification',
      data: {'email': email.trim()},
    );

    return _unwrap(res.data);
  }

  Future<Map<String, dynamic>> verifyEmail({
    required String token,
  }) async {
    final res = await _dio.post(
      '/v1/auth/verify-email',
      data: {'token': token.trim()},
    );

    return _unwrap(res.data);
  }
}