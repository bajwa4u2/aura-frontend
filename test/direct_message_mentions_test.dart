import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aura/core/interactions/direct_threads_repository.dart';
import 'package:aura/core/interactions/follows_repository.dart';
import 'package:aura/core/net/dio_provider.dart';
import 'package:aura/core/tagging/tag_entities.dart';

/// Item 15 — DM structured @mention persistence. Covers the two
/// mechanically-verifiable layers: the model correctly parses the
/// backend's resolved `tagReferences` shape, and the repository correctly
/// includes/omits `tagReferences` in the send payload. The governed
/// autocomplete overlay mechanics themselves (`GovernedTagAutocomplete`)
/// are already covered by the Thread composer's own tests -- DM reuses the
/// identical widget/authority, not a DM-specific reimplementation.
void main() {
  group('DirectMessage.fromJson tagReferences parsing', () {
    test('parses a resolved member mention with canonical identity', () {
      final message = DirectMessage.fromJson({
        'id': 'm1',
        'threadId': 't1',
        'senderUserId': 'u1',
        'actorType': 'USER',
        'body': 'hey @jane check this out',
        'createdAt': '2026-08-13T00:00:00.000Z',
        'tagReferences': [
          {
            'kind': 'member',
            'entityId': 'u2',
            'displayLabel': 'Jane Doe',
            'sourceText': '@jane',
            'startOffset': 4,
            'endOffset': 9,
            'identity': {
              'id': 'u2',
              'type': 'member',
              'displayLabel': 'Jane Doe',
              'handleOrSlug': 'jane',
              'route': '/u/jane',
            },
          },
        ],
      });

      expect(message.tagReferences, hasLength(1));
      final ref = message.tagReferences.first;
      expect(ref.kind, TagKind.member);
      expect(ref.durableEntityId, 'u2');
      expect(ref.identity?.route, '/u/jane');
    });

    test('is an empty list when no tagReferences are present (backward compatible)', () {
      final message = DirectMessage.fromJson({
        'id': 'm1',
        'threadId': 't1',
        'senderUserId': 'u1',
        'actorType': 'USER',
        'body': 'plain message',
        'createdAt': '2026-08-13T00:00:00.000Z',
      });
      expect(message.tagReferences, isEmpty);
    });
  });

  group('DirectThreadsRepository.sendMessage tagReferences payload', () {
    test('includes tagReferences in the POST body when provided', () async {
      Map<String, dynamic>? capturedData;
      final dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
      dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
        capturedData = Map<String, dynamic>.from(options.data as Map);
        handler.resolve(Response(
          requestOptions: options,
          statusCode: 200,
          data: {
            'message': {
              'id': 'm1',
              'threadId': 't1',
              'senderUserId': 'u1',
              'actorType': 'USER',
              'body': 'hey @jane',
              'createdAt': '2026-08-13T00:00:00.000Z',
            },
          },
        ));
      }));

      final container = ProviderContainer(overrides: [
        dioProvider.overrideWithValue(dio),
      ]);
      final repo = container.read(directThreadsRepositoryProvider);

      await repo.sendMessage(
        threadId: 't1',
        actor: const ActorRef.user('u1'),
        body: 'hey @jane',
        tagReferences: const [
          {'kind': 'member', 'entityId': 'u2', 'sourceText': '@jane'},
        ],
      );

      expect(capturedData?['tagReferences'], [
        {'kind': 'member', 'entityId': 'u2', 'sourceText': '@jane'},
      ]);
    });

    test('omits tagReferences entirely from the payload when none are selected', () async {
      Map<String, dynamic>? capturedData;
      final dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
      dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
        capturedData = Map<String, dynamic>.from(options.data as Map);
        handler.resolve(Response(
          requestOptions: options,
          statusCode: 200,
          data: {
            'message': {
              'id': 'm1',
              'threadId': 't1',
              'senderUserId': 'u1',
              'actorType': 'USER',
              'body': 'plain message',
              'createdAt': '2026-08-13T00:00:00.000Z',
            },
          },
        ));
      }));

      final container = ProviderContainer(overrides: [
        dioProvider.overrideWithValue(dio),
      ]);
      final repo = container.read(directThreadsRepositoryProvider);

      await repo.sendMessage(
        threadId: 't1',
        actor: const ActorRef.user('u1'),
        body: 'plain message',
      );

      expect(capturedData?.containsKey('tagReferences'), isFalse);
    });
  });
}
