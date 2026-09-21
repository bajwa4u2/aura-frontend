import 'package:aura/core/media/media_url_resolver.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// FOUR ANSWERS, NOT ONE.
///
/// The delivery door distinguishes "still processing" from "under review"
/// from "gone" from "never existed", each with its own status and code. The
/// client collapsed all four into one blank frame with no retry, so a picture
/// thirty seconds from ready looked exactly like one that had been destroyed —
/// and the person was told neither.
///
/// A 202 is the dangerous one: Dio treats every 2xx as a success, so it did
/// not raise at all. The fetch read an absent `url` and threw a bare
/// `StateError`, which is how the distinction was lost silently rather than
/// loudly.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.respond);

  final ResponseBody Function(RequestOptions options) respond;
  int calls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls += 1;
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

Dio _dioReturning(int status, Map<String, dynamic> body) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.example'));
  dio.httpClientAdapter = _FakeAdapter(
    (_) => ResponseBody.fromString(
      _json(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    ),
  );
  return dio;
}

String _json(Map<String, dynamic> body) {
  final parts = body.entries.map((e) {
    final v = e.value;
    if (v == null) return '"${e.key}":null';
    if (v is num || v is bool) return '"${e.key}":$v';
    return '"${e.key}":"$v"';
  });
  return '{${parts.join(',')}}';
}

void main() {
  group('the resolver carries the door\'s own answer', () {
    test('202 IS NOT A SUCCESS', () async {
      // The whole defect in one assertion. Dio accepts 2xx, so without an
      // explicit read this returned a result-shaped nothing.
      final resolver = MediaUrlResolver(
        _dioReturning(202, {
          'code': 'MEDIA_NOT_READY',
          'message': 'Media is not ready yet',
        }),
      );

      await expectLater(
        resolver.resolve('m1'),
        throwsA(
          isA<MediaUnavailableException>()
              .having((e) => e.isPending, 'isPending', isTrue)
              .having((e) => e.code, 'code', 'MEDIA_NOT_READY')
              .having((e) => e.isQuarantined, 'isQuarantined', isFalse),
        ),
      );
    });

    test('QUARANTINE IS WITHHELD, NOT GONE', () async {
      // Reversible retention. Reporting it as destroyed would leave the owner
      // with nothing to appeal against.
      final resolver = MediaUrlResolver(
        _dioReturning(403, {
          'code': 'MEDIA_QUARANTINED',
          'message':
              'This attachment is under review and is not currently available.',
        }),
      );

      await expectLater(
        resolver.resolve('m2'),
        throwsA(
          isA<MediaUnavailableException>()
              .having((e) => e.isQuarantined, 'isQuarantined', isTrue)
              .having((e) => e.isPending, 'isPending', isFalse)
              .having((e) => e.message, 'message', contains('under review')),
        ),
      );
    });

    test('GONE AND NOT-AVAILABLE KEEP THEIR OWN CODES', () async {
      for (final c in const [
        (410, 'MEDIA_GONE'),
        (404, 'MEDIA_NOT_AVAILABLE'),
      ]) {
        final resolver = MediaUrlResolver(_dioReturning(c.$1, {'code': c.$2}));
        await expectLater(
          resolver.resolve('m-${c.$2}'),
          throwsA(
            isA<MediaUnavailableException>()
                .having((e) => e.status, 'status', c.$1)
                .having((e) => e.code, 'code', c.$2)
                // Neither is worth waiting for, and neither is appealable.
                .having((e) => e.isPending, 'isPending', isFalse)
                .having((e) => e.isQuarantined, 'isQuarantined', isFalse),
          ),
        );
      }
    });

    test('A 200 WITH NO URL IS A FAILURE, NOT AN EMPTY IMAGE', () async {
      final resolver = MediaUrlResolver(_dioReturning(200, {'id': 'm3'}));
      await expectLater(
        resolver.resolve('m3'),
        throwsA(isA<MediaUnavailableException>()),
      );
    });

    test('A RESOLVED URL STILL RESOLVES', () async {
      // The path that must not regress: everything above is new branching
      // around a success that has to keep working unchanged.
      final resolver = MediaUrlResolver(
        _dioReturning(200, {
          'id': 'm4',
          'url': 'https://auraplatform.org/media/m4/raw',
          'visibility': 'PUBLIC',
        }),
      );

      final result = await resolver.resolve('m4');
      expect(result.url, 'https://auraplatform.org/media/m4/raw');
      expect(result.isPublic, isTrue);
      expect(result.isStale(), isFalse);
    });

    test('AN EMPTY ID NEVER REACHES THE NETWORK', () async {
      final dio = _dioReturning(200, {'url': 'x'});
      final adapter = dio.httpClientAdapter as _FakeAdapter;
      await expectLater(resolverFor(dio).resolve('   '), throwsA(anything));
      expect(adapter.calls, 0);
    });
  });
}

MediaUrlResolver resolverFor(Dio dio) => MediaUrlResolver(dio);
