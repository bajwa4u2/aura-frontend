import 'package:aura/core/errors/app_error_mapper.dart';
import 'package:aura/core/errors/report_silently.dart';
import 'package:aura/core/net/api_envelope.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

DioException _dio({
  int? status,
  Object? data,
  DioExceptionType type = DioExceptionType.badResponse,
}) {
  final req = RequestOptions(path: '/x');
  return DioException(
    requestOptions: req,
    type: type,
    response: status == null
        ? null
        : Response(requestOptions: req, statusCode: status, data: data),
  );
}

Map<String, dynamic> _err(String code, [String message = '']) => {
      'ok': false,
      'error': {'code': code, 'message': message},
    };

void main() {
  group('unwrapEnvelope reads exactly the backend envelope', () {
    test('ok: true returns data', () {
      expect(unwrapEnvelope({'ok': true, 'data': 3}), 3);
      expect(unwrapEnvelopeMap({'ok': true, 'data': {'a': 1}}), {'a': 1});
      expect(
        unwrapEnvelopeList({'ok': true, 'data': {'items': [{'id': 'p1'}]}},
            key: 'items'),
        [
          {'id': 'p1'}
        ],
      );
    });

    test('anything else throws instead of becoming an empty answer', () {
      expect(() => unwrapEnvelope(null), throwsA(isA<ApiEnvelopeException>()));
      expect(() => unwrapEnvelope({'items': []}),
          throwsA(isA<ApiEnvelopeException>()));
      expect(() => unwrapEnvelope({'ok': true}),
          throwsA(isA<ApiEnvelopeException>()));
      expect(() => unwrapEnvelopeList({'ok': true, 'data': {'rows': []}},
          key: 'items'), throwsA(isA<ApiEnvelopeException>()));
      expect(
        () => unwrapEnvelope(_err('FORBIDDEN')),
        throwsA(isA<ApiEnvelopeException>()
            .having((e) => e.code, 'code', 'FORBIDDEN')),
      );
    });
  });

  group('reportSilently', () {
    tearDown(() => ReportSilentlySink.sink = (_, __, ___) {});

    test('hands the failure to the installed sink', () {
      final seen = <String>[];
      ReportSilentlySink.sink = (e, st, context) => seen.add(context);
      reportSilently(StateError('x'), StackTrace.current, 'here');
      expect(seen, ['here']);
    });

    test('a failing sink never becomes a second failure', () {
      ReportSilentlySink.sink = (_, __, ___) => throw StateError('sink');
      expect(() => reportSilently(StateError('x'), null, 'here'),
          returnsNormally);
    });
  });

  group('authErrorMessage keeps every sign-in sentence', () {
    String signIn(DioException e) =>
        authErrorMessage(e, AuthOperation.signIn);

    test('no answer: Aura could not be reached', () {
      expect(signIn(_dio(type: DioExceptionType.connectionError)),
          startsWith('Aura could not be reached.'));
    });

    test('rate limited: says for how long', () {
      expect(
        signIn(_dio(status: 429, data: {
          'ok': false,
          'error': {
            'code': 'RATE_LIMITED',
            'details': {'retryAfterSeconds': 30},
          },
        })),
        'Too many sign-in attempts from this connection. Please try again in about 30 seconds.',
      );
    });

    test('wrong password, unverified, unavailable, fallback', () {
      expect(signIn(_dio(status: 401)),
          'The email or password does not look right.');
      expect(signIn(_dio(status: 403, data: _err('EMAIL_NOT_VERIFIED'))),
          'Please verify your email first, then try signing in again.');
      expect(signIn(_dio(status: 403)),
          'This account is not available right now.');
      expect(signIn(_dio(status: 418)),
          'We could not sign you in right now. Please try again.');
      expect(authErrorMessage(StateError('x'), AuthOperation.signIn),
          'We could not sign you in right now. Please try again.');
    });
  });

  group('authErrorMessage keeps the other account sentences', () {
    test('register: age refusal is the server sentence', () {
      expect(
        authErrorMessage(
            _dio(status: 400, data: _err('ACCOUNT_AGE_INELIGIBLE', 'Too young.')),
            AuthOperation.register),
        'Too young.',
      );
      expect(
        authErrorMessage(_dio(status: 409, data: _err('X', 'Email already used')),
            AuthOperation.register),
        'That email is already in use. Try signing in instead.',
      );
    });

    test('shared answers: network, rate limit, server', () {
      expect(
        authErrorMessage(_dio(type: DioExceptionType.connectionTimeout),
            AuthOperation.forgotPassword),
        'We could not reach the server. Check your connection and try again.',
      );
      expect(authErrorMessage(_dio(status: 429), AuthOperation.verifyEmail),
          'Too many attempts in a short time. Please wait a little and try again.');
      expect(authErrorMessage(_dio(status: 503), AuthOperation.resetPassword),
          'Something went wrong on our side. Please try again in a moment.');
    });

    test('code and link specifics', () {
      expect(authErrorMessage(_dio(status: 401), AuthOperation.verifyCode),
          'That code is incorrect. Please check and try again.');
      expect(
        authErrorMessage(_dio(status: 400, data: _err('X', 'Please wait 30s')),
            AuthOperation.resendCode),
        'Please wait 30s',
      );
      expect(authErrorMessage(_dio(status: 400), AuthOperation.resetPassword),
          'That reset link is no longer valid. Please request a new one.');
      expect(authErrorMessage(_dio(status: 404), AuthOperation.forgotPassword),
          'We could not find an account with that email.');
    });

    test('account management uses the caller fallback', () {
      expect(
        authErrorMessage(_dio(status: 400), AuthOperation.account,
            fallback: 'Could not revoke session.'),
        'Could not revoke session.',
      );
    });
  });
}
