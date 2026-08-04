import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aura/core/errors/app_error.dart';
import 'package:aura/core/errors/app_error_mapper.dart';

RequestOptions _req(String path) => RequestOptions(path: path);

DioException _badResponse({
  required int statusCode,
  required dynamic data,
  String path = '/posts/draft/publish',
}) {
  final requestOptions = _req(path);
  return DioException(
    requestOptions: requestOptions,
    type: DioExceptionType.badResponse,
    response: Response(
      requestOptions: requestOptions,
      statusCode: statusCode,
      data: data,
    ),
  );
}

void main() {
  group('AppErrorMapper — canonical envelope parsing', () {
    test('extracts message, code, requestId, and issues from a Map envelope', () {
      final err = _badResponse(
        statusCode: 400,
        data: {
          'ok': false,
          'error': {
            'code': 'VALIDATION_ERROR',
            'message': 'Validation failed',
            'details': {
              'issues': ['text must be longer than 0 characters', 'topic is required'],
            },
            'requestId': 'req_123',
            'timestamp': '2026-08-04T00:00:00Z',
            'path': '/posts/draft/publish',
          },
        },
      );

      final appError = AppErrorMapper.from(err);

      expect(appError.type, AppErrorType.validation);
      expect(appError.message, 'Validation failed');
      expect(appError.code, 'VALIDATION_ERROR');
      expect(appError.requestId, 'req_123');
      expect(appError.issues, ['text must be longer than 0 characters', 'topic is required']);
      expect(appError.hasIssues, isTrue);
    });

    test('parses a JSON-string response body identically to a decoded Map', () {
      final err = _badResponse(
        statusCode: 400,
        data:
            '{"ok":false,"error":{"code":"VALIDATION_ERROR","message":"Validation failed","details":{"issues":["too short"]},"requestId":"req_9"}}',
      );

      final appError = AppErrorMapper.from(err);

      expect(appError.message, 'Validation failed');
      expect(appError.code, 'VALIDATION_ERROR');
      expect(appError.requestId, 'req_9');
      expect(appError.issues, ['too short']);
    });

    test('falls back to a generic message for a non-JSON (HTML/proxy) body without crashing', () {
      final err = _badResponse(
        statusCode: 502,
        data: '<html><body><h1>502 Bad Gateway</h1></body></html>',
      );

      final appError = AppErrorMapper.from(err);

      expect(appError.type, AppErrorType.server);
      expect(appError.message, isNot(contains('<html>')));
      expect(appError.message, isNotEmpty);
    });

    test('falls back to a generic message for a JSON array body without crashing', () {
      final err = _badResponse(statusCode: 400, data: ['unexpected', 'array']);

      final appError = AppErrorMapper.from(err);

      expect(appError.type, AppErrorType.validation);
      expect(appError.message, 'Some information needs attention.');
    });

    test('falls back to a generic message when data is null', () {
      final err = _badResponse(statusCode: 500, data: null);

      final appError = AppErrorMapper.from(err);

      expect(appError.type, AppErrorType.server);
      expect(appError.message, 'Something went wrong on our side. Try again.');
    });

    test('never surfaces a raw object stringification in message', () {
      final err = _badResponse(
        statusCode: 400,
        data: {
          'error': {'code': 'VALIDATION_ERROR', 'message': 'Validation failed'},
        },
      );

      final appError = AppErrorMapper.from(err);

      expect(appError.message, isNot(contains('Instance of')));
      expect(appError.toString(), isNot(contains('Instance of')));
      expect(appError.toString(), appError.message);
    });
  });

  group('AppErrorMapper — status/type classification', () {
    test('401 maps to authRequired with a sign-in action', () {
      final err = _badResponse(statusCode: 401, data: {'error': {'message': 'nope'}});
      final appError = AppErrorMapper.from(err, feature: 'publish this');

      expect(appError.isAuthRequired, isTrue);
      expect(appError.message, 'Sign in to publish this.');
      expect(appError.action?.route, '/login');
    });

    test('an auth-coded 400 also maps to authRequired even without a 401 status', () {
      final err = _badResponse(
        statusCode: 400,
        data: {
          'error': {'code': 'TOKEN_EXPIRED', 'message': 'Token expired'},
        },
      );
      final appError = AppErrorMapper.from(err);

      expect(appError.isAuthRequired, isTrue);
    });

    test('403 maps to forbidden and prefers the backend message when present', () {
      final err = _badResponse(
        statusCode: 403,
        data: {
          'error': {'message': 'Only institution owners or admins can perform this action.'},
        },
      );
      final appError = AppErrorMapper.from(err);

      expect(appError.type, AppErrorType.forbidden);
      expect(appError.message, 'Only institution owners or admins can perform this action.');
    });

    test('404 maps to notFound', () {
      final err = _badResponse(statusCode: 404, data: {'error': {'message': 'gone'}});
      expect(AppErrorMapper.from(err).type, AppErrorType.notFound);
    });

    test('409 maps to a validation-shaped conflict message', () {
      final err = _badResponse(
        statusCode: 409,
        data: {
          'error': {
            'message': 'This decision has already been used to publish. Request a fresh review.',
          },
        },
      );
      final appError = AppErrorMapper.from(err);

      expect(appError.message, 'This decision has already been used to publish. Request a fresh review.');
    });

    test('connectionTimeout maps to timeout', () {
      final requestOptions = _req('/posts/draft/publish');
      final err = DioException(
        requestOptions: requestOptions,
        type: DioExceptionType.connectionTimeout,
      );
      expect(AppErrorMapper.from(err).type, AppErrorType.timeout);
    });

    test('connectionError maps to network (offline)', () {
      final requestOptions = _req('/posts/draft/publish');
      final err = DioException(
        requestOptions: requestOptions,
        type: DioExceptionType.connectionError,
      );
      expect(AppErrorMapper.from(err).type, AppErrorType.network);
    });

    test('cancel maps to cancelled', () {
      final requestOptions = _req('/posts/draft/publish');
      final err = DioException(
        requestOptions: requestOptions,
        type: DioExceptionType.cancel,
      );
      expect(AppErrorMapper.from(err).type, AppErrorType.cancelled);
    });
  });

  group('AppErrorMapper — non-Dio errors', () {
    test('wraps a plain object without crashing or leaking its toString', () {
      final appError = AppErrorMapper.from(Object());
      expect(appError.type, AppErrorType.unknown);
      expect(appError.message, 'Something went wrong. Try again.');
    });

    test('an already-mapped AppError passes through unchanged', () {
      const original = AppError(type: AppErrorType.validation, message: 'Custom');
      expect(identical(AppErrorMapper.from(original), original), isTrue);
    });
  });
}
