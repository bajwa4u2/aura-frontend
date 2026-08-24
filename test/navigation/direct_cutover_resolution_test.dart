import 'dart:typed_data';

import 'package:aura/core/interactions/direct_thread_cutover_scope.dart';
import 'package:aura/core/net/dio_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// THE CUTOVER ASKS A QUESTION THE ADDRESS CAN ACTUALLY ANSWER.
///
/// Found in production 2026-08-24, against a real thread the founder holds:
/// the cutover called `GET /direct-threads/:id`, which — like every read on
/// that service — requires the caller to name the actor it asks AS. It sent
/// none, so the server answered `400 actor is missing userId` for every
/// address from the day the cutover shipped (2026-08-23), and the surface
/// rendered "That conversation could not be found" over a correspondence whose
/// canonical Conversation existed the whole time.
///
/// Two separate things were wrong and both are pinned here: the endpoint it
/// asked, and what it did with a failure to reach the authority.
void main() {
  /// Answers exactly one path and 400s everything else — which is what the
  /// real server does, and is the whole point.
  Dio dioAnswering(String path, {Map<String, dynamic>? body, int status = 200}) {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
    dio.httpClientAdapter = _Adapter((req) {
      if (req.path == path) {
        return ResponseBody.fromString(
          '{"ok":true,"data":${_json(body ?? {})}}',
          status,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      }
      return ResponseBody.fromString(
        '{"ok":false,"error":{"code":"REQUEST_ERROR",'
        '"message":"actor is missing userId"}}',
        400,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    });
    return dio;
  }

  Future<AsyncValue<String?>> resolve(Dio dio) async {
    final container = ProviderContainer(
      overrides: [dioProvider.overrideWithValue(dio)],
    );
    addTearDown(container.dispose);
    try {
      final v = await container
          .read(legacyDirectThreadConversationProvider('thread-1').future);
      return AsyncValue.data(v);
    } catch (e, st) {
      return AsyncValue.error(e, st);
    }
  }

  test('it asks the resolution endpoint, which needs no acting identity',
      () async {
    final result = await resolve(
      dioAnswering('/direct-threads/thread-1/conversation',
          body: {'conversationId': 'conv-1'}),
    );
    expect(result.value, 'conv-1');
  });

  test('the read endpoint alone is not enough — that was the production bug',
      () async {
    // If a future edit points this back at `/direct-threads/:id`, this fake
    // behaves exactly as production did: 400, not an answer.
    final result = await resolve(
      dioAnswering('/direct-threads/thread-1',
          body: {'conversationId': 'conv-1'}),
    );
    expect(result.hasError, isTrue,
        reason: 'the read endpoint refuses a request that names no actor');
  });

  test('a 404 is a real answer: the address names nothing', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
    dio.httpClientAdapter = _Adapter(
      (_) => ResponseBody.fromString('{"ok":false}', 404, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      }),
    );
    final result = await resolve(dio);
    expect(result.hasError, isFalse);
    expect(result.value, isNull);
  });

  test('a failure to find out surfaces as an ERROR, never as absence',
      () async {
    // The distinction the surface depends on: null means "this address names
    // nothing", an error means "I could not find out". Collapsing them is how
    // an existing correspondence came to read as a deleted one.
    final result = await resolve(dioAnswering('/nothing-matches'));
    expect(result.hasError, isTrue);
    expect(result.hasValue, isFalse);
  });
}

String _json(Map<String, dynamic> m) =>
    '{${m.entries.map((e) => '"${e.key}":"${e.value}"').join(',')}}';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.handler);
  final ResponseBody Function(RequestOptions) handler;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async =>
      handler(options);
}
