import 'dart:convert';
import 'dart:typed_data';

import 'package:aura/features/meetings/data/meetings_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// SHARING A SUMMARY READS THE SERVER'S WHOLE ENVELOPE (2026-10-27).
///
/// The server sent this answer without `data` until 27 Oct 2026,
/// so the app always read "not shared before, 0 recipients" and
/// never asked before re-sending an edited summary. These hold the reply the
/// server now sends.
class _Reply implements HttpClientAdapter {
  _Reply(this.body);
  final Object body;
  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? s, Future<void>? c) async =>
      ResponseBody.fromString(jsonEncode(body), 200, headers: {
        Headers.contentTypeHeader: ['application/json; charset=utf-8'],
      });
  @override
  void close({bool force = false}) {}
}

MeetingsRepository _repo(Object reply) =>
    MeetingsRepository(Dio(BaseOptions(baseUrl: 'https://api.test'))..httpClientAdapter = _Reply(reply));

void main() {
  test('a first share reports how many people it reached', () async {
    final r = await _repo({
      'ok': true,
      'data': {'ok': true, 'alreadyShared': false, 'recipients': 3},
    }).shareSummary('m1');
    expect(r.alreadyShared, isFalse);
    expect(r.recipients, 3);
  });

  test('an already-shared summary is reported, so the host is asked first', () async {
    final r = await _repo({
      'ok': true,
      'data': {'ok': true, 'alreadyShared': true, 'recipients': 0},
    }).shareSummary('m1');
    expect(r.alreadyShared, isTrue);
  });
}
