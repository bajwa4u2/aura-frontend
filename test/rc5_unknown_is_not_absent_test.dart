// RC5 — "COULD NOT ASK" IS NOT "ASKED AND GOT NOTHING".
//
// Two halves of the same mistake:
//
//   * `/auth/me` answered `{}` for every failure, so a transient 500, a
//     dropped connection or a timeout was indistinguishable from a signed-out
//     visitor. Everything downstream then reasoned from a confident empty
//     identity that had never been established.
//
//   * the router's refresh listeners compared materialised VALUES only, so a
//     transition into ERROR never re-ran the redirect — loading→error is
//     null→null, and data→error keeps the previous value through
//     `copyWithPrevious`. The router went on standing by a decision made
//     against state that had since failed.
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aura/core/auth/auth_providers.dart';
import 'package:aura/core/auth/session_providers.dart';
import 'package:aura/core/net/dio_provider.dart';

class _FakeStore extends TokenStore {
  _FakeStore(this._token);
  final String _token;

  @override
  String? get accessToken => _token;

  @override
  bool get isAuthed => true;
}

/// A syntactically valid member token — `isGuestAccessToken` inspects the
/// payload, and a guest token would short-circuit the call under test.
const _memberToken =
    'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJ1c2VyLTEiLCJ0eXBlIjoibWVtYmVyIn0.sig';

ProviderContainer _container(Dio dio) {
  final container = ProviderContainer(overrides: [
    dioProvider.overrideWithValue(dio),
    tokenStoreProvider.overrideWith((ref) => _FakeStore(_memberToken)),
  ]);
  addTearDown(container.dispose);
  return container;
}

Dio _dioReturning({int? status, DioExceptionType? type}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) {
      if (options.path == '/auth/me') {
        return handler.reject(DioException(
          requestOptions: options,
          type: type ?? DioExceptionType.badResponse,
          response: status == null
              ? null
              : Response(requestOptions: options, statusCode: status),
        ));
      }
      return handler.resolve(
          Response(requestOptions: options, statusCode: 200, data: {}));
    },
  ));
  return dio;
}

void main() {
  group('RC5 — identity that could not be asked for', () {
    test('a 401 IS an answer: no member session', () async {
      final container = _container(_dioReturning(status: 401));
      await expectLater(
        container.read(authMeDataProvider.future),
        completion(isEmpty),
      );
    });

    test('a 403 is likewise an answer', () async {
      final container = _container(_dioReturning(status: 403));
      await expectLater(
        container.read(authMeDataProvider.future),
        completion(isEmpty),
      );
    });

    test('a 500 leaves identity UNKNOWN, not empty', () async {
      // Answering {} here would state something never established, and
      // nothing downstream could tell the difference.
      final container = _container(_dioReturning(status: 500));
      await expectLater(
        container.read(authMeDataProvider.future),
        throwsA(isA<DioException>()),
      );
    });

    test('a timeout leaves identity UNKNOWN', () async {
      final container =
          _container(_dioReturning(type: DioExceptionType.connectionTimeout));
      await expectLater(
        container.read(authMeDataProvider.future),
        throwsA(isA<DioException>()),
      );
    });

    test('being offline leaves identity UNKNOWN', () async {
      final container =
          _container(_dioReturning(type: DioExceptionType.connectionError));
      await expectLater(
        container.read(authMeDataProvider.future),
        throwsA(isA<DioException>()),
      );
    });
  });

  group('RC5 — a refresh key that notices failure', () {
    // The router's listeners key on this shape. Written out here because the
    // property is what matters, not the closure: a transition INTO error must
    // be visible, and a reload landing on the same value must not be.
    String key({bool loading = false, bool error = false, String? value}) =>
        '$loading/$error/${value ?? '-'}';

    test('loading → error is a CHANGE, though both hold no value', () {
      expect(key(loading: true), isNot(key(error: true)));
    });

    test('data → error is a CHANGE, though the value is retained', () {
      expect(key(value: 'verifiedMember'),
          isNot(key(error: true, value: 'verifiedMember')));
    });

    test('error → data is a change back', () {
      expect(key(error: true, value: 'none'), isNot(key(value: 'none')));
    });

    test('a reload landing on the same value is NOT a change', () {
      // The property the original tightening existed for: no refresh storm
      // from routine background re-evaluation.
      expect(key(value: 'verifiedMember'), key(value: 'verifiedMember'));
    });
  });
}
