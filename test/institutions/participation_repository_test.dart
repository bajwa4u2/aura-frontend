import 'dart:convert';
import 'dart:typed_data';

import 'package:aura/features/institutions/participation/participation_models.dart';
import 'package:aura/features/institutions/participation/participation_repository.dart';
import 'package:aura/features/topics/topic.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// TOPICS, READ AS THE SERVER SENDS THEM (seen live, 9 Oct 2026).
///
/// The server answers `{ ok, participations: [...] }` and
/// `{ ok, participation: {...} }`. The app read `data`/`items`, so the list
/// showed one "Unknown topic" in place of four real ones, and taking a topic
/// on lost its id, so "start answering now" never switched it on. These
/// payloads are copied from the controller's real shapes, never kinder.
class _Server implements HttpClientAdapter {
  final requests = <RequestOptions>[];

  static Map<String, dynamic> _row(String id, String topic, String status) => {
        'id': id,
        'institutionId': 'inst-1',
        'topic': topic,
        'mode': 'ACCOUNTABLE',
        'status': status,
        'jurisdictionId': 'global',
        'notes': null,
        'activatedAt': status == 'ACTIVE' ? '2026-06-21T08:05:13.114Z' : null,
        'pausedAt': null,
        'createdAt': '2026-06-21T08:04:48.143Z',
        'updatedAt': '2026-06-21T08:05:13.115Z',
      };

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? s, Future<void>? c) async {
    requests.add(o);
    Object body;
    if (o.method == 'GET') {
      body = {
        'ok': true,
        'participations': [
          _row('p1', 'GOVERNMENT', 'ACTIVE'),
          _row('p2', 'EDUCATION', 'ACTIVE'),
          _row('p3', 'TECHNOLOGY', 'ACTIVE'),
          _row('p4', 'FAITH', 'INACTIVE'),
        ],
      };
    } else if (o.method == 'POST') {
      body = {'ok': true, 'participation': _row('p9', (o.data as Map)['topic'] as String, 'INACTIVE')};
    } else {
      body = {'ok': true, 'participation': _row('p9', 'COMMUNITY', (o.data as Map)['status'] as String)};
    }
    return ResponseBody.fromString(jsonEncode(body), 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late _Server server;
  late ParticipationRepository repo;
  setUp(() {
    server = _Server();
    repo = ParticipationRepository(Dio(BaseOptions(baseUrl: 'https://api.example.test/v1'))..httpClientAdapter = server);
  });

  test('the list is every topic the institution holds, named', () async {
    final list = await repo.list('inst-1');
    expect(list.map((p) => p.topic), [AuraTopic.fromWire('GOVERNMENT'), AuraTopic.fromWire('EDUCATION'), AuraTopic.fromWire('TECHNOLOGY'), AuraTopic.fromWire('FAITH')]);
    expect(list.every((p) => p.topic != null), isTrue, reason: 'no "Unknown topic"');
    expect(list.last.status, ParticipationStatus.inactive);
  });

  test('taking a topic on returns the new record with its id, so it can be switched on', () async {
    final created = await repo.create(institutionId: 'inst-1', topic: 'COMMUNITY', mode: 'ACCOUNTABLE');
    expect(created.id, 'p9');
    final on = await repo.updateStatus(institutionId: 'inst-1', participationId: created.id, status: 'ACTIVE');
    expect(on.status, ParticipationStatus.active);
    expect(server.requests.last.path, '/institutions/inst-1/participation/p9');
  });
}
