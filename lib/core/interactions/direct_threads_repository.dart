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
    this.deliveredAt,
    this.seenAt,
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
  final DateTime? deliveredAt;
  final DateTime? seenAt;
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
      deliveredAt:
          DateTime.tryParse(json['deliveredAt']?.toString() ?? ''),
      seenAt: DateTime.tryParse(json['seenAt']?.toString() ?? ''),
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

/// Inbox row returned by `GET /v1/direct-threads`.
class InboxThread {
  const InboxThread({
    required this.threadId,
    required this.participantA,
    required this.participantB,
    this.lastMessageAt,
    this.lastMessageSnippet,
    this.lastMessageActorType,
    this.lastMessageActorUserId,
    this.lastMessageActorInstitutionId,
    required this.unreadCount,
  });

  final String threadId;
  final DirectThreadParticipant participantA;
  final DirectThreadParticipant participantB;
  final DateTime? lastMessageAt;
  final String? lastMessageSnippet;
  final ActorType? lastMessageActorType;
  final String? lastMessageActorUserId;
  final String? lastMessageActorInstitutionId;
  final int unreadCount;

  factory InboxThread.fromJson(Map<String, dynamic> json) {
    final lastActorRaw =
        (json['lastMessageActorType'] ?? '').toString().trim().toUpperCase();
    return InboxThread(
      threadId: json['threadId']?.toString() ?? '',
      participantA: _parseParticipantWithEmbed(json['participantA']),
      participantB: _parseParticipantWithEmbed(json['participantB']),
      lastMessageAt:
          DateTime.tryParse(json['lastMessageAt']?.toString() ?? ''),
      lastMessageSnippet: json['lastMessageSnippet']?.toString(),
      lastMessageActorType: lastActorRaw.isEmpty
          ? null
          : (lastActorRaw == 'INSTITUTION'
              ? ActorType.institution
              : ActorType.user),
      lastMessageActorUserId: json['lastMessageActorUserId']?.toString(),
      lastMessageActorInstitutionId:
          json['lastMessageActorInstitutionId']?.toString(),
      unreadCount: () {
        final raw = json['unreadCount'];
        if (raw is num) return raw.toInt();
        if (raw is String) return int.tryParse(raw) ?? 0;
        return 0;
      }(),
    );
  }
}

/// Embedded user/institution details returned by the inbox list. Wrapper
/// around the bare-bones [DirectThreadParticipant] adding the user/institution
/// objects.
class DirectThreadParticipantWithEmbed extends DirectThreadParticipant {
  const DirectThreadParticipantWithEmbed({
    required super.type,
    super.userId,
    super.institutionId,
    this.user,
    this.institution,
  });

  final Map<String, dynamic>? user;
  final Map<String, dynamic>? institution;
}

DirectThreadParticipantWithEmbed _parseParticipantWithEmbed(dynamic raw) {
  final json = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
  final t = (json['type'] ?? '').toString().trim().toUpperCase();
  return DirectThreadParticipantWithEmbed(
    type: t == 'INSTITUTION' ? ActorType.institution : ActorType.user,
    userId: json['userId']?.toString(),
    institutionId: json['institutionId']?.toString(),
    user: json['user'] is Map ? Map<String, dynamic>.from(json['user'] as Map) : null,
    institution: json['institution'] is Map
        ? Map<String, dynamic>.from(json['institution'] as Map)
        : null,
  );
}

class DirectThreadsRepository {
  DirectThreadsRepository(this._dio);

  final Dio _dio;

  Future<List<InboxThread>> listForActor({required ActorRef actor}) async {
    final query = <String, dynamic>{...actor.toQuery('actor')};
    final res = await _dio.get(
      '/direct-threads',
      queryParameters: query,
    );
    final body = res.data;
    final items = <InboxThread>[];
    if (body is Map) {
      final root = Map<String, dynamic>.from(body);
      final raw = root['items'];
      if (raw is List) {
        for (final entry in raw.whereType<Map>()) {
          items.add(InboxThread.fromJson(
            Map<String, dynamic>.from(entry),
          ));
        }
      }
    }
    return items;
  }

  Future<void> markSeen({
    required String threadId,
    required ActorRef actor,
  }) async {
    final body = <String, dynamic>{...actor.toFields('actor')};
    await _dio.post('/direct-threads/$threadId/seen', data: body);
  }

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

final inboxThreadsProvider = FutureProvider.autoDispose
    .family<List<InboxThread>, ActorRef>((ref, actor) async {
  final repo = ref.read(directThreadsRepositoryProvider);
  return repo.listForActor(actor: actor);
});
