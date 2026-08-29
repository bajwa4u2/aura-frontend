import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aura/core/distribution/feed_draft_publisher.dart';

/// CONTROL TESTS FOR THE HELD-DRAFT COLLISION.
///
/// The defect: the feed's convenience endpoints are keyed by AUTHOR, not by
/// draft — `PUT /posts/draft` overwrites whatever is held and
/// `POST /posts/draft/publish` publishes whatever is held. Share's first
/// implementation used them, so somebody with an unfinished post in Compose
/// who then shared a photograph would have had that post replaced by the
/// photograph and published in its place.
///
/// Every test here is written so that it FAILS against that behaviour. The
/// central assertion is not "the right calls were made" but "the
/// author-keyed endpoints were never touched at all" — a publisher that
/// cannot name a draft cannot destroy somebody else's.
void main() {
  late List<String> calls;
  late Dio dio;

  /// Records every request and answers from [responses] by path suffix.
  Dio buildDio(Map<String, dynamic> responses, {Set<String> failOn = const {}}) {
    final d = Dio(BaseOptions(baseUrl: 'https://test.local'));
    d.httpClientAdapter = _RecordingAdapter(
      onRequest: (method, path) => calls.add('$method $path'),
      responses: responses,
      failOn: failOn,
    );
    return d;
  }

  setUp(() {
    calls = <String>[];
    dio = buildDio({
      '/posts/held': {'id': 'draft_share_1'},
      '/posts/draft_share_1': {'ok': true},
      '/posts/draft_share_1/publish': {'id': 'post_9'},
    });
  });

  /// The endpoints that act on "whatever this author is holding". Touching
  /// any of them is how one creation context destroys another's.
  ///
  /// Matched EXACTLY rather than by prefix. `/posts/draft` is a prefix of
  /// `/posts/draft_share_1`, so a `contains` check reports a correctly
  /// id-addressed call as a singleton one — which is how a guard against a
  /// dangerous path ends up flagging the safe path instead.
  bool touchedAuthorKeyedDraft(List<String> calls) => calls.any((c) {
        final path = c.split(' ').last;
        return path == '/posts/draft' || path == '/posts/draft/publish';
      });

  group('THE GUARD ITSELF', () {
    test('the old singleton sequence IS flagged', () {
      // PROOF THAT THESE TESTS ARE CONTROLS, not descriptions of whatever the
      // code happens to do. This is verbatim what Share's first feed path
      // issued; if the predicate did not catch it, every assertion below
      // would pass against the very defect they exist to prevent.
      const oldBehaviour = <String>[
        'PUT /posts/draft',
        'POST /posts/draft/publish',
      ];
      expect(touchedAuthorKeyedDraft(oldBehaviour), isTrue);
    });

    test('an id-addressed sequence is NOT flagged', () {
      expect(
        touchedAuthorKeyedDraft(const <String>[
          'POST /posts/held',
          'PUT /posts/draft_share_1',
          'POST /posts/draft_share_1/publish',
        ]),
        isFalse,
      );
    });
  });

  group('COMPOSE_EXISTS_THEN_SHARE_PUBLISH', () {
    test('publishing a share never touches the author-keyed draft', () async {
      final publisher = FeedDraftPublisher(dio);
      final id = await publisher.createDraft();
      await publisher.publish(draftId: id, text: 'hello', mediaIds: ['m1'],
              primaryTopic: 'TECHNOLOGY');

      // THE ASSERTION THAT FAILS AGAINST THE OLD BEHAVIOUR. The previous
      // implementation's entire feed path was these two endpoints.
      expect(
        touchedAuthorKeyedDraft(calls),
        isFalse,
        reason: 'Share must never write or publish "the" draft — that is what '
            'replaced somebody\'s unfinished Compose post.',
      );
    });

    test('every write names the draft it means', () async {
      final publisher = FeedDraftPublisher(dio);
      final id = await publisher.createDraft();
      await publisher.publish(draftId: id, text: 'hello', mediaIds: const [],
              primaryTopic: 'TECHNOLOGY');

      expect(calls, contains('POST /posts/held'));
      expect(calls, contains('PUT /posts/draft_share_1'));
      expect(calls, contains('POST /posts/draft_share_1/publish'));
    });

    test('the published post is reported back', () async {
      final publisher = FeedDraftPublisher(dio);
      final id = await publisher.createDraft();
      final result =
          await publisher.publish(draftId: id, text: 't', mediaIds: const [],
              primaryTopic: 'TECHNOLOGY');
      expect(result.draftId, 'draft_share_1');
      expect(result.postId, 'post_9');
    });
  });

  group('SHARE_RETRY_TARGETS_SAME_DRAFT', () {
    test('a retry publishes the same draft, not a newly discovered one',
        () async {
      final publisher = FeedDraftPublisher(dio);
      final id = await publisher.createDraft();

      // First attempt fails at publish.
      final failing = buildDio(
        {'/posts/draft_share_1': {'ok': true}},
        failOn: {'/posts/draft_share_1/publish'},
      );
      await expectLater(
        FeedDraftPublisher(failing)
            .publish(draftId: id, text: 'a', mediaIds: const [],
              primaryTopic: 'TECHNOLOGY'),
        throwsA(isA<DioException>()),
      );

      // The retry carries the SAME id. Nothing re-resolves "my draft", which
      // is what could otherwise pick up a Compose draft that had since become
      // the most recently updated one.
      calls.clear();
      await publisher.publish(draftId: id, text: 'a', mediaIds: const [],
              primaryTopic: 'TECHNOLOGY');
      expect(calls, contains('POST /posts/draft_share_1/publish'));
      expect(touchedAuthorKeyedDraft(calls), isFalse);
    });

    test('publishing refuses without an identity', () async {
      final publisher = FeedDraftPublisher(dio);
      // A publisher that could fall back to "the current draft" when given
      // nothing is precisely the hazard; it refuses instead.
      expect(
        () => publisher.publish(
            draftId: '  ', text: 't', mediaIds: const [],
            primaryTopic: 'TECHNOLOGY'),
        throwsA(isA<ArgumentError>()),
      );
      expect(calls, isEmpty);
    });
  });

  group('TOPIC IS NOT OPTIONAL', () {
    test('publishing without a topic is refused before any request', () async {
      // The backend refuses a top-level post with no primary topic -- "A
      // primary topic is required to publish a public record". Share found
      // that out in production. Refusing here, before the draft is written,
      // means the composition is never half-published against a rule the
      // client already knows.
      final publisher = FeedDraftPublisher(dio);
      final id = await publisher.createDraft();
      calls.clear();
      await expectLater(
        publisher.publish(
            draftId: id, text: 't', mediaIds: const [], primaryTopic: '  '),
        throwsA(isA<ArgumentError>()),
      );
      expect(calls, isEmpty);
    });

    test('the chosen topic reaches the draft write', () async {
      final publisher = FeedDraftPublisher(dio);
      final id = await publisher.createDraft();
      await publisher.publish(
          draftId: id, text: 't', mediaIds: const [], primaryTopic: 'HOUSING');
      expect(calls, contains('PUT /posts/draft_share_1'));
    });
  });

  group('SHARE_FAILURE — Compose survives', () {
    test('a failed creation never falls back to the author-keyed path',
        () async {
      final failing = buildDio(const {}, failOn: {'/posts/held'});
      await expectLater(
        FeedDraftPublisher(failing).createDraft(),
        throwsA(anything),
      );
      expect(touchedAuthorKeyedDraft(calls), isFalse);
    });

    test('a draft with no id is refused rather than guessed at', () async {
      // No id in the response: continuing would mean publishing something
      // unnamed, and the only unnamed thing available is the singleton.
      final noId = buildDio({'/posts/held': <String, dynamic>{}});
      await expectLater(
        FeedDraftPublisher(noId).createDraft(),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('PUBLISH_CLEAR_SEMANTICS', () {
    test('discard names one draft and is never a broad clear', () async {
      await FeedDraftPublisher(dio).discardDraft('draft_share_1');
      expect(calls, contains('DELETE /posts/draft_share_1'));
      expect(touchedAuthorKeyedDraft(calls), isFalse);
    });

    test('discarding nothing does nothing', () async {
      await FeedDraftPublisher(dio).discardDraft('   ');
      expect(calls, isEmpty);
    });

    test('a failed discard never surfaces', () async {
      // The person has already left; tidying is not worth an error.
      final failing = buildDio(const {}, failOn: {'/posts/draft_share_1'});
      await expectLater(
        FeedDraftPublisher(failing).discardDraft('draft_share_1'),
        completes,
      );
    });
  });
}

/// Records requests and returns canned answers, so the tests assert the
/// SHAPE of the conversation rather than mocking a service.
class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter({
    required this.onRequest,
    required this.responses,
    required this.failOn,
  });

  final void Function(String method, String path) onRequest;
  final Map<String, dynamic> responses;
  final Set<String> failOn;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.path;
    onRequest(options.method, path);
    if (failOn.contains(path)) {
      throw DioException(
        requestOptions: options,
        response: Response<dynamic>(requestOptions: options, statusCode: 500),
        type: DioExceptionType.badResponse,
      );
    }
    final body = responses[path] ?? <String, dynamic>{};
    return ResponseBody.fromString(
      _encode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  String _encode(dynamic v) {
    if (v is Map) {
      final parts = v.entries.map((e) => '"${e.key}":${_encode(e.value)}');
      return '{${parts.join(',')}}';
    }
    if (v is bool) return v.toString();
    return '"$v"';
  }

  @override
  void close({bool force = false}) {}
}
