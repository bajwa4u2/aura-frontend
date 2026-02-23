import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/net/dio_provider.dart';

class AuthRepository {
  final Dio _dio;

  AuthRepository(this._dio);

  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String handle,
    required String displayName,
    required String firstName,
    required String lastName,
  }) async {
    final res = await _dio.post(
      '/auth/register',
      data: {
        'email': email.trim(),
        'password': password,
        'handle': handle.trim(),
        'displayName': displayName.trim(),
        'firstName': firstName.trim(),
        'lastName': lastName.trim(),
      },
    );

    return _unwrap(res);
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final res = await _dio.post(
      '/auth/login',
      data: {
        'email': email.trim(),
        'password': password,
      },
    );

    return _unwrap(res);
  }

  Future<Map<String, dynamic>> resendVerificationEmail({
    required String email,
  }) async {
    final res = await _dio.post(
      '/auth/resend-verification',
      data: {'email': email.trim()},
    );

    return _unwrap(res);
  }

  Future<Map<String, dynamic>> verifyEmail({
    required String token,
  }) async {
    final res = await _dio.post(
      '/auth/verify-email',
      data: {'token': token},
    );

    return _unwrap(res);
  }

  Future<Map<String, dynamic>> forgotPassword({
    required String email,
  }) async {
    final res = await _dio.post(
      '/auth/forgot-password',
      data: {'email': email.trim()},
    );

    return _unwrap(res);
  }

  Future<Map<String, dynamic>> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    final res = await _dio.post(
      '/auth/reset-password',
      data: {
        'token': token,
        'password': newPassword,
      },
    );

    return _unwrap(res);
  }

  Map<String, dynamic> _unwrap(Response res) {
    final body = res.data;

    if (body is Map && body.containsKey('data')) {
      return Map<String, dynamic>.from(body['data'] ?? {});
    }

    if (body is Map<String, dynamic>) {
      return body;
    }

    return {};
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return AuthRepository(dio);
});