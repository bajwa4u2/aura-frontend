import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_providers.dart';
import '../../../core/auth/token_store.dart';
import '../../../core/net/dio_provider.dart';

class AuthController {
  AuthController(this.ref);

  final Ref ref;

  Future<void> login(
    BuildContext context, {
    required String email,
    required String password,
    String? redirectTo,
  }) async {
    final dio = ref.read(dioProvider);

    try {
      final res = await dio.post(
        '/v1/auth/login',
        data: {
          'email': email.trim(),
          'password': password,
        },
      );

      final data = res.data;

      if (data is! Map || data['success'] != true) {
        throw Exception('Unexpected login response');
      }

      final payload = data['data'] as Map<String, dynamic>;
      final accessToken = payload['accessToken'] as String?;
      final refreshToken = payload['refreshToken'] as String?;

      if (accessToken == null || refreshToken == null) {
        throw Exception('Missing tokens');
      }

      await ref.read(tokenStoreProvider).saveTokens(
            accessToken: accessToken,
            refreshToken: refreshToken,
          );

      ref.invalidate(isAuthedProvider);
      ref.invalidate(emailVerifiedProvider);

      final dest = (redirectTo != null && redirectTo.startsWith('/'))
          ? redirectTo
          : '/home';

      context.go(dest);
    } on DioException catch (e) {
      final responseData = e.response?.data;
      String? code;

      if (responseData is Map) {
        code = responseData['error']?['code'] as String?;
      }

      if (code == 'EMAIL_NOT_VERIFIED') {
        final dest = (redirectTo != null && redirectTo.startsWith('/'))
            ? redirectTo
            : '/home';

        context.go(
          '/verify-email?redirect=${Uri.encodeComponent(dest)}',
        );
        return;
      }

      final message =
          responseData is Map ? responseData['error']?['message'] : null;

      throw Exception(message ?? 'Login failed');
    } catch (e) {
      rethrow;
    }
  }

  Future<void> logout(BuildContext context) async {
    final dio = ref.read(dioProvider);

    try {
      await dio.post('/v1/auth/logout');
    } catch (_) {}

    await ref.read(tokenStoreProvider).clear();

    ref.invalidate(isAuthedProvider);
    ref.invalidate(emailVerifiedProvider);

    context.go('/login');
  }
}