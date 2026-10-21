import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aura/core/net/dio_provider.dart';
import 'package:aura/features/auth/auth_controller.dart';

/// A device with no internet must be told so, not that sign-in failed
/// (21 Oct 2026: a phone with no connection showed "We could not sign you in
/// right now", which reads as a broken account).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Dio dioFailingWith(DioExceptionType type, {int? status}) {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test/v1'));
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      handler.reject(DioException(
        requestOptions: options,
        type: type,
        response: status == null
            ? null
            : Response(requestOptions: options, statusCode: status),
      ));
    }));
    return dio;
  }

  Future<String> signInError(Dio dio) async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer(
      overrides: [dioProvider.overrideWithValue(dio)],
    );
    addTearDown(container.dispose);
    try {
      await container
          .read(authControllerProvider)
          .login(email: 'person@example.com', password: 'a-password');
    } catch (e) {
      return e.toString();
    }
    fail('sign-in should have failed');
  }

  for (final type in [
    DioExceptionType.connectionError,
    DioExceptionType.connectionTimeout,
    DioExceptionType.unknown,
  ]) {
    test('no connection ($type) says the device could not reach Aura', () async {
      final message = await signInError(dioFailingWith(type));
      expect(message, contains('Aura could not be reached'));
      expect(message, isNot(contains('could not sign you in right now')));
    });
  }

  test('a refused password still says the email or password is wrong', () async {
    final message = await signInError(
      dioFailingWith(DioExceptionType.badResponse, status: 401),
    );
    expect(message, contains('The email or password does not look right.'));
  });
}
