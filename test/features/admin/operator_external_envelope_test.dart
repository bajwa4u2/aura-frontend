import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aura/features/admin/data/operator_external.dart';

/// THE ENVELOPE, AND WHY IT FAILS SILENTLY.
///
/// Aura wraps every internal response as `{ok: true, data: <payload>}`, applied
/// globally on the server. The client's Dio layer does NOT unwrap it —
/// `AdminRepository` reaches through `m['data']` by hand for exactly this
/// reason. This repository originally read fields straight off `res.data`.
///
/// It went to production and the failure had no symptom. The consumer list
/// parsed as empty and the screen rendered "No external system has been
/// admitted" over a database holding a row. No error, no exception, no log —
/// just a confident, wrong, empty state.
///
/// THE WRITE PATHS WOULD HAVE BEEN WORSE. `showOnce` read at the wrong level is
/// null, so the dialog whose entire purpose is to show a credential exactly
/// once would have shown an empty box — and the secret would be gone, because
/// Aura stores only a hash. The operator would have been left holding nothing,
/// with no way to tell that anything had been lost.
///
/// So these assert the wire, not the model: given the bytes the server actually
/// sends, does a value come out.
void main() {
  Dio dioReturning(dynamic body) {
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
    dio.httpClientAdapter = _FixedAdapter(body);
    return dio;
  }

  const consumerJson = {
    'id': 'con-1',
    'displayName': 'Orchestrate',
    'status': 'ACTIVE',
    'webhookUrl': 'https://api.example.com/hook',
    'isControlledCertification': true,
    'countsTowardMarketMetrics': false,
    'credentials': [
      {
        'id': 'cred-1',
        'keyId': 'ak_live_1',
        'scopes': ['MEETINGS_READ', 'MEETINGS_WRITE'],
        'status': 'ACTIVE',
      },
    ],
    '_count': {'meetings': 3, 'events': 9},
  };

  group('reads survive Aura\'s response envelope', () {
    test('the consumer list is not empty when the server sent a row', () async {
      // The exact shape production returns.
      final repo = OperatorExternalRepository(
        dioReturning({
          'ok': true,
          'data': {
            'consumers': [consumerJson],
          },
        }),
      );

      final rows = await repo.list();

      expect(rows, hasLength(1), reason: 'an empty list here renders "none" over real rows');
      expect(rows.single.displayName, 'Orchestrate');
      expect(rows.single.activeCredential?.keyId, 'ak_live_1');
      expect(rows.single.countsTowardMarketMetrics, isFalse);
    });

    test('still works if the transport ever starts unwrapping', () async {
      // Tolerating both shapes means this file does not become wrong the day
      // somebody adds an unwrapping interceptor.
      final repo = OperatorExternalRepository(
        dioReturning({
          'consumers': [consumerJson],
        }),
      );
      expect(await repo.list(), hasLength(1));
    });

    test('tenants come through the envelope too', () async {
      final repo = OperatorExternalRepository(
        dioReturning({
          'ok': true,
          'data': {
            'tenants': [
              {
                'id': 't-1',
                'externalRef': 'clx9f2',
                'displayName': 'Acme Ltd',
                'status': 'ACTIVE',
                'meetingIdentities': [
                  {'id': 'p1', 'slug': 'acme-sales', 'name': 'Acme', 'isActive': true},
                ],
                '_count': {'meetings': 2},
              },
            ],
          },
        }),
      );

      final tenants = await repo.tenants('con-1');
      expect(tenants.single.externalRef, 'clx9f2');
      expect(tenants.single.identities.single.slug, 'acme-sales');
    });
  });

  group('the one-time secret actually arrives', () {
    test('create returns the bearer and the signing secret', () async {
      // THE TEST THAT MATTERS MOST. If this returns nulls, the dialog shows an
      // empty box and the credential is unrecoverable — Aura keeps a hash.
      final repo = OperatorExternalRepository(
        dioReturning({
          'ok': true,
          'data': {
            'consumer': {'id': 'con-1', 'displayName': 'Orchestrate'},
            'credential': {'credentialId': 'cred-1', 'keyId': 'ak_live_1'},
            'showOnce': {
              'bearer': 'ak_live_1.s3cret',
              'webhookSigningSecret': 'whsec_abc',
              'notice': 'Copy these now.',
            },
          },
        }),
      );

      final created = await repo.create(
        displayName: 'Orchestrate',
        scopes: const ['MEETINGS_READ'],
        isControlledCertification: true,
      );

      expect(created.consumerId, 'con-1');
      expect(created.showOnce.bearer, 'ak_live_1.s3cret');
      expect(created.showOnce.webhookSigningSecret, 'whsec_abc');
      expect(created.showOnce.hasAnything, isTrue);
    });

    test('rotate returns the new bearer', () async {
      final repo = OperatorExternalRepository(
        dioReturning({
          'ok': true,
          'data': {
            'credential': {'credentialId': 'cred-2', 'keyId': 'ak_live_2'},
            'showOnce': {'bearer': 'ak_live_2.n3w'},
          },
        }),
      );

      final once = await repo.rotate(consumerId: 'con-1', scopes: const ['MEETINGS_READ']);
      expect(once.bearer, 'ak_live_2.n3w');
    });

    test('setting a webhook returns the new signing secret', () async {
      final repo = OperatorExternalRepository(
        dioReturning({
          'ok': true,
          'data': {
            'webhookUrl': 'https://api.example.com/hook',
            'showOnce': {'webhookSigningSecret': 'whsec_rotated'},
          },
        }),
      );

      final once = await repo.setWebhook(
        consumerId: 'con-1',
        webhookUrl: 'https://api.example.com/hook',
      );
      expect(once.webhookSigningSecret, 'whsec_rotated');
    });

    test('clearing a webhook returns nothing, and says so honestly', () async {
      // A null showOnce is the correct answer here, not a failure — removing a
      // destination mints no secret.
      final repo = OperatorExternalRepository(
        dioReturning({
          'ok': true,
          'data': {'webhookUrl': null, 'showOnce': null},
        }),
      );

      final once = await repo.setWebhook(consumerId: 'con-1', webhookUrl: null);
      expect(once.hasAnything, isFalse);
    });
  });
}

/// Returns one fixed JSON body for any request, so the assertions are about
/// parsing rather than about routing.
class _FixedAdapter implements HttpClientAdapter {
  _FixedAdapter(this.body);

  final dynamic body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
