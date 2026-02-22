import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/net/dio_provider.dart';

class AuthRepository {
  AuthRepository(this._dio);

  final Dio _dio;

  Map<String, dynamic> _asMap(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return Map<String, dynamic>.from(v);
    return <String, dynamic>{};
  }

  Map<String, dynamic> _unwrap(dynamic raw) {
    final m = _asMap(raw);
    if (m.isEmpty) throw Exception('Unexpected response');

    // Locked envelope (Aura Contract v1): { ok: true, data: ... }
    if (m['ok'] == true && m.containsKey('data')) {
      final inner = m['data'];
      if (inner is Map) return Map<String, dynamic>.from(inner as Map);
      return <String, dynamic>{'value': inner};
    }

    // Legacy fallback: { data: {...} }
    final data = m['data'];
    if (data is Map) return Map<String, dynamic>.from(data as Map);

    return m;
  }

  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String? handle,
    String? displayName,
  }) async {
    final res = await _dio.post(
      '/auth/register',
      data: <String, dynamic>{
        'email': email,
        'password': password,
        'firstName': firstName,
        'lastName': lastName,
        if (handle != null && handle.trim().isNotEmpty) 'handle': handle.trim(),
        if (displayName != null && displayName.trim().isNotEmpty) 'displayName': displayName.trim(),
      },
    );

    return _unwrap(res.data);
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final res = await _dio.post(
      '/auth/login',
      data: <String, dynamic>{
        'email': email,
        'password': password,
      },
    );
    return _unwrap(res.data);
  }

  Future<Map<String, dynamic>> me() async {
    final res = await _dio.get('/auth/me');
    return _unwrap(res.data);
  }

  Future<void> verifyEmail({required String token}) async {
    await _dio.post(
      '/auth/verify-email',
      data: <String, dynamic>{'token': token},
    );
  }

  /// Silent security behavior should be enforced on backend.
  /// Frontend treats success as "email sent if it exists".
  Future<void> resendVerification({required String email}) async {
    await _dio.post(
      '/auth/resend-verification',
      data: <String, dynamic>{'email': email},
    );
  }

  Future<void> forgotPassword({required String email}) async {
    await _dio.post(
      '/auth/forgot-password',
      data: <String, dynamic>{'email': email},
    );
  }

  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    await _dio.post(
      '/auth/reset-password',
      data: <String, dynamic>{
        'token': token,
        'newPassword': newPassword,
      },
    );
  }
}

/// Riverpod provider for AuthRepository
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final dio = ref.read(dioProvider);
  return AuthRepository(dio);
});