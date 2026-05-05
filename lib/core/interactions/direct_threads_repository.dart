import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../net/dio_provider.dart';
import 'actor_context.dart';
import 'follows_repository.dart';

/// Discriminated direct-thread participant.
class DirectThreadParticipant {
  const DirectThreadParticipant({
    required this.type,
    this.userId,
    this.institutionId,
  });

  final ActorType type;
  final String? userId;
  final String? institutionId;

  factory DirectThreadParticipant.fromJson(Map<String, dynamic> json) {
    final t =
        (json['type'] ?? '').toString().trim().toUpperCase();
    return DirectThreadParticipant(
      type: t == 'INSTITUTION' ? ActorType.institution : ActorType.user,
      userId: json['userId']?.toString(),
      institutionId: json['institutionId']?.toString(),
    );
  }
}

/// Result from `POST /v1/correspondence/direct` and `GET /v1/direct-threads/:id`.
class DirectThreadInfo {
  const DirectThreadInfo({
    required this.threadId,
    required this.participantA,
    required this.participantB,
    required this.route,
    required this.createdNow,
  });

  final String threadId;
  final DirectThreadParticipant participantA;
  final DirectThreadParticipant participantB;

  /// Server-supplied frontend route. Use this directly for navigation.
  final String route;
  final bool createdNow;

  factory DirectThreadInfo.fromJson(Map<String, dynamic> json) {
    return DirectThreadInfo(
      threadId: json['threadId']?.toString() ?? '',
      participantA: DirectThreadParticipant.fromJson(
        Map<String, dynamic>.from(json['participantA'] as Map? ?? {}),
      ),
      participantB: DirectThreadParticipant.fromJson(
        Map<String, dynamic>.from(json['participantB'] as Map? ?? {}),
      ),
      route: json['route']?.toString() ?? '',
      createdNow: json['createdNow'] == true,
    );
  }
}

class DirectMessage {
  const DirectMessage({
    required this.id,
    required this.threadId,
    required this.senderUserId,
    required this.actorType,
    this.actorInstitutionId,
    required this.body,
    required this.createdAt,
    this.senderUser,
    this.actorInstitution,
  });

  final String id;
  final String threadId;
  final String senderUserId;
  final ActorType actorType;
  final String? actorInstitutionId;
  final String body;
  final DateTime createdAt;
  final Map<String, dynamic>? senderUser;
  final Map<String, dynamic>? actorInstitution;

  bool get isInstitutionVoice =>
      actorType == ActorType.institution &&
      actorInstitutionId != null &&
      actorInstitutionId!.isNotEmpty;

  factory DirectMessage.fromJson(Map<String, dynamic> json) {
    final actorTypeRaw =
        (json['actorType'] ?? '').toString().trim().toUpperCase();
    final created = DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
        DateTime.now();
    return DirectMessage(
      id: json['id']?.toString() ?? '',
      threadId: json['threadId']?.toString() ?? '',
      senderUserId: json['senderUserId']?.toString() ?? '',
      actorType:
          actorTypeRaw == 'INSTITUTION' ? ActorType.institution : ActorType.user,
      actorInstitutionId: json['actorInstitutionId']?.toString(),
      body: json['body']?.toString() ?? '',
      createdAt: created,
      senderUser: json['senderUser'] is Map
          ? Map<String, dynamic>.from(json['senderUser'] as Map)
          : null,
      actorInstitution: json['actorInstitution'] is Map
          ? Map<String, dynamic>.from(json['actorInstitution'] as Map)
          : null,
    );
  }
}

class DirectMessagesPage {
  const DirectMessagesPage({required this.items, this.nextCursor});

  final List<DirectMessage> items;
  final String? nextCursor;
}

class DirectThreadsRepository {
  DirectThreadsRepository(this._dio);

  final Dio _dio;

  Future<DirectThreadInfo> openOrCreate({
    required ActorRef actor,
    required ActorRef target,
  }) async {
    final body = <String, dynamic>{
      ...actor.toFields('actor'),
      ...target.toFields('target'),
    };
    final res = await _dio.post('/correspondence/direct', data: body);
    return DirectThreadInfo.fromJson(
      Map<String, dynamic>.from(res.data as Map),
    );
  }

  Future<DirectThreadInfo> getThread({
    required String threadId,
    required ActorRef actor,
  }) async {
    final query = <String, dynamic>{...actor.toQuery('actor')};
    final res = await _dio.get(
      '/direct-threads/$threadId',
      queryParameters: query,
    );
    return DirectThreadInfo.fromJson(
      Map<String, dynamic>.from(res.data as Map),
    );
  }

  Future<DirectMessagesPage> listMessages({
    required String threadId,
    required ActorRef actor,
    String? cursor,
    int? limit,
  }) async {
    final query = <String, dynamic>{
      ...actor.toQuery('actor'),
      if (cursor != null && cursor.trim().isNotEmpty) 'cursor': cursor,
      if (limit != null) 'limit': limit,
    };
    final res = await _dio.get(
      '/direct-threads/$threadId/messages',
      queryParameters: query,
    );
    final body = res.data;
    final items = <DirectMessage>[];
    String? next;
    if (body is Map) {
      final root = Map<String, dynamic>.from(body);
      final raw = root['items'];
      if (raw is List) {
        for (final entry in raw.whereType<Map>()) {
          items.add(DirectMessage.fromJson(
            Map<String, dynamic>.from(entry),
          ));
        }
      }
      final c = root['nextCursor'];
      if (c != null) {
        final s = c.toString().trim();
        if (s.isNotEmpty) next = s;
      }
    }
    return DirectMessagesPage(items: items, nextCursor: next);
  }

  Future<DirectMessage> sendMessage({
    required String threadId,
    required ActorRef actor,
    required String body,
  }) async {
    final payload = <String, dynamic>{
      ...actor.toFields('actor'),
      'body': body,
    };
    final res = await _dio.post(
      '/direct-threads/$threadId/messages',
      data: payload,
    );
    final raw = res.data;
    final m = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    final messageMap = m['message'] is Map
        ? Map<String, dynamic>.from(m['message'] as Map)
        : m;
    return DirectMessage.fromJson(messageMap);
  }
}

final directThreadsRepositoryProvider = Provider<DirectThreadsRepository>(
  (ref) => DirectThreadsRepository(ref.read(dioProvider)),
);

class DirectThreadKey {
  const DirectThreadKey({required this.threadId, required this.actor});
  final String threadId;
  final ActorRef actor;

  @override
  bool operator ==(Object other) =>
      other is DirectThreadKey &&
      other.threadId == threadId &&
      other.actor == actor;

  @override
  int get hashCode => Object.hash(threadId, actor);
}

final directThreadProvider = FutureProvider.autoDispose
    .family<DirectThreadInfo, DirectThreadKey>((ref, key) async {
  final repo = ref.read(directThreadsRepositoryProvider);
  return repo.getThread(threadId: key.threadId, actor: key.actor);
});

final directMessagesProvider = FutureProvider.autoDispose
    .family<DirectMessagesPage, DirectThreadKey>((ref, key) async {
  final repo = ref.read(directThreadsRepositoryProvider);
  return repo.listMessages(threadId: key.threadId, actor: key.actor);
});
