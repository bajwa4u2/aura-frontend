import 'package:aura/core/net/dio_provider.dart';
import 'package:aura/features/auth/auth_controller.dart';
import 'package:aura/features/auth/presentation/auth_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What the sign-in screen SHOWS for each failure of the real sign-in path.
/// Before this, the controller's sentence was re-mapped by keyword on the
/// screen, so "Aura could not be reached…", the rate-limit wait and the
/// unavailable-account sentence all became "We could not sign you in".
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Dio failing(DioExceptionType type, {int? status, Object? data}) {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test/v1'));
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      handler.reject(DioException(
        requestOptions: options,
        type: type,
        response: status == null
            ? null
            : Response(requestOptions: options, statusCode: status, data: data),
      ));
    }));
    return dio;
  }

  Future<String> shown(Dio dio) async {
    SharedPreferences.setMockInitialValues({});
    final container =
        ProviderContainer(overrides: [dioProvider.overrideWithValue(dio)]);
    addTearDown(container.dispose);
    try {
      await container
          .read(authControllerProvider)
          .login(email: 'person@example.com', password: 'a-password');
    } catch (e) {
      return humanizeLoginError(e);
    }
    fail('sign-in should have failed');
  }

  test('no connection', () async {
    expect(await shown(failing(DioExceptionType.connectionError)),
        startsWith('Aura could not be reached.'));
  });

  test('rate limited, with the wait', () async {
    expect(
      await shown(failing(DioExceptionType.badResponse, status: 429, data: {
        'ok': false,
        'error': {
          'code': 'RATE_LIMITED',
          'details': {'retryAfterSeconds': 600},
        },
      })),
      'Too many sign-in attempts from this connection. Please try again in about 10 minutes.',
    );
  });

  test('unavailable account and server failure', () async {
    expect(await shown(failing(DioExceptionType.badResponse, status: 403)),
        'This account is not available right now.');
    expect(await shown(failing(DioExceptionType.badResponse, status: 503)),
        'Something went wrong on our side. Please try again in a moment.');
  });

  test('wrong password still reads as wrong password', () async {
    expect(await shown(failing(DioExceptionType.badResponse, status: 401)),
        'The email or password does not look right.');
  });
}
