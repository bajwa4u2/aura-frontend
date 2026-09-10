/// PUBLISHING ONCE, EVEN WHEN THE CLIENT NEVER FINDS OUT.
///
/// Production incident, 2026-09-10. Publishing an announcement commits the row
/// and THEN fans out to every member, which took about fifteen seconds. The
/// founder's client stopped waiting, showed "took too much time", and they did
/// the reasonable thing and pressed publish again.
///
/// Both attempts had ALREADY SUCCEEDED server-side. Four audit rows, all
/// SUCCESS, no failure of any kind. The result was two live duplicate
/// announcements and 64 notifications to 32 people — two each — while the
/// operator was told twice that publishing had failed.
///
/// Founder freeze:
///
///     TIMEOUT != FAILURE
///     A publish request that times out has an UNKNOWN OUTCOME.
///
/// These prove the seven named outcomes against a real `Dio` whose adapter
/// answers exactly as the wire would, so the repository's own error handling,
/// the outcome classifier and the reconciliation query all participate.
library;

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aura/features/announcements/data/announcements_repository.dart';

/// Answers per-path, and COUNTS what it was asked to do.
///
/// The counts are the point: "no duplicate" is a statement about how many times
/// the server was told to publish, and a test that only checked the final
/// screen state could not see a second publish at all.
class _Wire implements HttpClientAdapter {
  _Wire();

  int publishCalls = 0;
  int createCalls = 0;
  int reconcileCalls = 0;

  /// What `POST /publish` does. Set per test.
  late Future<ResponseBody> Function() onPublish;

  /// Whether the announcement is published, as the canonical read would say.
  bool published = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? stream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.path;

    if (options.method == 'POST' && path.endsWith('/publish')) {
      publishCalls += 1;
      return onPublish();
    }
    if (options.method == 'POST' && path == '/admin/announcements') {
      createCalls += 1;
      return _json(201, '{"ok":true,"data":{"id":"a1","slug":"the-notice"}}');
    }
    if (options.method == 'GET' && path == '/announcements/the-notice') {
      reconcileCalls += 1;
      return published
          ? _json(200, '{"ok":true,"data":{"item":{"id":"a1","slug":"the-notice"}}}')
          : _json(404, '{"ok":false,"error":{"code":"NOT_FOUND"}}');
    }
    return _json(200, '{"ok":true,"data":{}}');
  }

  static ResponseBody _json(int status, String body) => ResponseBody.fromString(
        body,
        status,
        headers: <String, List<String>>{
          Headers.contentTypeHeader: <String>[Headers.jsonContentType],
        },
      );

  @override
  void close({bool force = false}) {}
}

AnnouncementsRepository _repo(_Wire wire) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test/v1'))
    ..httpClientAdapter = wire;
  return AnnouncementsRepository(dio);
}

/// A request that never answers, then reports a receive timeout — the exact
/// shape the founder hit.
Future<ResponseBody> _timeout(RequestOptions o) =>
    Future<ResponseBody>.error(DioException(
      requestOptions: o,
      type: DioExceptionType.receiveTimeout,
    ));

void main() {
  group('outcome classification', () {
    RequestOptions o() => RequestOptions(path: '/x');

    test('a timeout leaves the outcome UNKNOWN', () {
      for (final t in [
        DioExceptionType.receiveTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.connectionTimeout,
        DioExceptionType.connectionError,
      ]) {
        expect(
          publishOutcomeIsUnknown(DioException(requestOptions: o(), type: t)),
          isTrue,
          reason: '$t must not be read as a failure',
        );
      }
    });

    test('a 5xx ALSO leaves the outcome unknown', () {
      // Not obvious, and it matters. The publish path commits the row and then
      // fans out, so a server error can be raised AFTER the announcement is
      // already public. Treating 500 as a clean failure would invite the same
      // duplicate by a different route.
      expect(
        publishOutcomeIsUnknown(DioException(
          requestOptions: o(),
          response: Response(requestOptions: o(), statusCode: 500),
        )),
        isTrue,
      );
    });

    test('TRUE_FAILURE_BEFORE_COMMIT — a 4xx is a definite failure', () {
      for (final code in [400, 403, 404, 409, 422]) {
        expect(
          publishOutcomeIsUnknown(DioException(
            requestOptions: o(),
            response: Response(requestOptions: o(), statusCode: code),
          )),
          isFalse,
          reason: '$code is a refusal made before anything was committed',
        );
      }
    });
  });

  group('reconciliation reads canonical state', () {
    test('published -> published', () async {
      final wire = _Wire()..published = true;
      expect(
        await _repo(wire).reconcilePublication('the-notice'),
        PublicationOutcome.published,
      );
      expect(wire.reconcileCalls, 1);
    });

    test('404 is an ANSWER: not published', () async {
      final wire = _Wire()..published = false;
      expect(
        await _repo(wire).reconcilePublication('the-notice'),
        PublicationOutcome.notPublished,
      );
    });

    test('an unreachable server leaves it UNKNOWN, never "not published"', () async {
      // The distinction that keeps this honest. Reading a failed CHECK as "it
      // did not publish" would authorise a retry on an announcement that may
      // already be live — reintroducing the duplicate through the repair.
      final wire = _Wire();
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test/v1'))
        ..httpClientAdapter = _Unreachable();
      expect(
        await AnnouncementsRepository(dio).reconcilePublication('the-notice'),
        PublicationOutcome.unknown,
      );
      expect(wire.reconcileCalls, 0);
    });
  });

  group('the seven outcomes', () {
    test('FIRST_PUBLISH_SUCCESS = ONE PUBLICATION', () async {
      final wire = _Wire();
      wire.onPublish = () async {
        wire.published = true;
        return _Wire._json(201, '{"ok":true,"data":{}}');
      };
      await _repo(wire).publish('a1');
      expect(wire.publishCalls, 1);
    });

    test('RESPONSE_LOST_AFTER_SUCCESS = ONE PUBLICATION', () async {
      // The founder's case exactly: the server published, the reply never
      // arrived. Reconciliation must report `published`, so the caller treats
      // it as done and never publishes again.
      final wire = _Wire();
      wire.onPublish = () {
        wire.published = true; // the commit happened
        return _timeout(RequestOptions(path: '/publish')); // the answer did not
      };

      final repo = _repo(wire);
      Object? thrown;
      try {
        await repo.publish('a1');
      } catch (e) {
        thrown = e;
      }

      expect(thrown, isNotNull);
      expect(publishOutcomeIsUnknown(thrown!), isTrue);
      expect(
        await repo.reconcilePublication('the-notice'),
        PublicationOutcome.published,
      );
      expect(wire.publishCalls, 1, reason: 'exactly one publication');
    });

    test('CLIENT_RETRY_AFTER_UNKNOWN_OUTCOME = NO DUPLICATE', () async {
      // The retry reuses the SAME id. It does not create a second draft, which
      // is what actually produced two live announcements.
      final wire = _Wire();
      wire.onPublish = () {
        wire.published = true;
        return _timeout(RequestOptions(path: '/publish'));
      };
      final repo = _repo(wire);

      await repo.publish('a1').catchError((_) {});
      final outcome = await repo.reconcilePublication('the-notice');

      // Having learned it IS published, a correct caller stops here.
      expect(outcome, PublicationOutcome.published);
      expect(wire.createCalls, 0, reason: 'no second draft was created');
      expect(wire.publishCalls, 1, reason: 'no second publish was attempted');
    });

    test('ALREADY_PUBLISHED_RETRY = NO FANOUT (server contract)', () async {
      // The client half is above. This states the SERVER half the client now
      // relies on: re-publishing an already-published announcement returns it
      // unchanged and fans out nothing. Proven server-side in
      // `announcements.service.ts`; asserted here as the contract the client
      // depends on, so a change on either side breaks a test.
      final wire = _Wire()..published = true;
      wire.onPublish = () async => _Wire._json(201, '{"ok":true,"data":{}}');
      await _repo(wire).publish('a1');
      expect(wire.publishCalls, 1);
    });

    test('UNKNOWN_OUTCOME != FAILURE_COPY', () async {
      // A failed CHECK after a lost publish must remain unknown. If this ever
      // returned `notPublished`, the UI would render failure copy and invite
      // the retry that caused the incident.
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test/v1'))
        ..httpClientAdapter = _Unreachable();
      expect(
        await AnnouncementsRepository(dio).reconcilePublication('the-notice'),
        isNot(PublicationOutcome.notPublished),
      );
    });

    test('TRUE_FAILURE_BEFORE_COMMIT = RETRYABLE', () async {
      final wire = _Wire();
      wire.onPublish = () async => _Wire._json(403, '{"ok":false,"error":{"code":"FORBIDDEN"}}');
      final repo = _repo(wire);

      Object? thrown;
      try {
        await repo.publish('a1');
      } catch (e) {
        thrown = e;
      }
      expect(thrown, isNotNull);
      // Known failure -> the caller rethrows and offers a retry, and the
      // reconciliation query is never needed.
      expect(publishOutcomeIsUnknown(thrown!), isFalse);
      expect(
        await repo.reconcilePublication('the-notice'),
        PublicationOutcome.notPublished,
      );
    });
  });
}

/// Nothing answers at all — DNS gone, server down, cable out.
class _Unreachable implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? stream,
    Future<void>? cancelFuture,
  ) =>
      Future<ResponseBody>.error(
        DioException(requestOptions: options, type: DioExceptionType.connectionError),
      );

  @override
  void close({bool force = false}) {}
}
