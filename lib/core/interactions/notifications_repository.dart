import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../net/dio_provider.dart';
import 'actor_context.dart';

/// Phase-3 actor-aware notification.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.recipientUserId,
    required this.type,
    required this.actorType,
    this.actorId,
    this.actorInstitutionId,
    this.actor,
    this.actorInstitution,
    this.postId,
    this.institutionPostId,
    this.directThreadId,
    this.post,
    this.institutionPost,
    required this.payload,
    this.readAt,
    required this.createdAt,
  });

  final String id;
  final String recipientUserId;

  /// Wire string (LIKE / REPLY / REPOST / FOLLOW / MESSAGE / …).
  final String type;

  final ActorType actorType;
  final String? actorId;
  final String? actorInstitutionId;

  final Map<String, dynamic>? actor;
  final Map<String, dynamic>? actorInstitution;

  final String? postId;
  final String? institutionPostId;
  final String? directThreadId;

  final Map<String, dynamic>? post;
  final Map<String, dynamic>? institutionPost;

  final Map<String, dynamic> payload;
  final DateTime? readAt;
  final DateTime createdAt;

  bool get isRead => readAt != null;

  bool get isInstitutionVoice =>
      actorType == ActorType.institution &&
      actorInstitutionId != null &&
      actorInstitutionId!.isNotEmpty;

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final actorTypeRaw =
        (json['actorType'] ?? '').toString().trim().toUpperCase();
    return AppNotification(
      id: json['id']?.toString() ?? '',
      recipientUserId: json['recipientUserId']?.toString() ?? '',
      type: (json['type'] ?? '').toString().toUpperCase(),
      actorType: actorTypeRaw == 'INSTITUTION'
          ? ActorType.institution
          : ActorType.user,
      actorId: json['actorId']?.toString(),
      actorInstitutionId: json['actorInstitutionId']?.toString(),
      actor: json['actor'] is Map
          ? Map<String, dynamic>.from(json['actor'] as Map)
          : null,
      actorInstitution: json['actorInstitution'] is Map
          ? Map<String, dynamic>.from(json['actorInstitution'] as Map)
          : null,
      postId: json['postId']?.toString(),
      institutionPostId: json['institutionPostId']?.toString(),
      directThreadId: json['directThreadId']?.toString(),
      post: json['post'] is Map
          ? Map<String, dynamic>.from(json['post'] as Map)
          : null,
      institutionPost: json['institutionPost'] is Map
          ? Map<String, dynamic>.from(json['institutionPost'] as Map)
          : null,
      payload: json['payload'] is Map
          ? Map<String, dynamic>.from(json['payload'] as Map)
          : <String, dynamic>{},
      readAt: DateTime.tryParse(json['readAt']?.toString() ?? ''),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

class NotificationsPage {
  const NotificationsPage({required this.items, this.nextCursor});

  final List<AppNotification> items;
  final String? nextCursor;
}

class NotificationsRepository {
  NotificationsRepository(this._dio);

  final Dio _dio;

  Future<NotificationsPage> list({String? cursor, int? limit}) async {
    final query = <String, dynamic>{
      if (cursor != null && cursor.trim().isNotEmpty) 'cursor': cursor,
      if (limit != null) 'limit': limit,
    };
    final res = await _dio.get(
      '/notifications',
      queryParameters: query.isEmpty ? null : query,
    );
    final body = res.data;
    final items = <AppNotification>[];
    String? next;
    if (body is Map) {
      final root = Map<String, dynamic>.from(body);
      final raw = root['items'];
      if (raw is List) {
        for (final entry in raw.whereType<Map>()) {
          items.add(AppNotification.fromJson(
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
    return NotificationsPage(items: items, nextCursor: next);
  }

  Future<int> unreadCount() async {
    final res = await _dio.get('/notifications/unread-count');
    if (res.data is Map) {
      final v = (res.data as Map)['unreadCount'];
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? 0;
    }
    return 0;
  }

  Future<void> markRead(List<String> ids) async {
    if (ids.isEmpty) return;
    await _dio.post('/notifications/read', data: {'ids': ids});
  }

  Future<void> markAllRead() async {
    await _dio.post('/notifications/read-all');
  }
}

final notificationsRepositoryProvider = Provider<NotificationsRepository>(
  (ref) => NotificationsRepository(ref.read(dioProvider)),
);

final notificationsListProvider = FutureProvider.autoDispose<NotificationsPage>(
  (ref) async {
    final repo = ref.read(notificationsRepositoryProvider);
    return repo.list(limit: 50);
  },
);

final unreadNotificationCountProvider = FutureProvider.autoDispose<int>(
  (ref) async {
    final repo = ref.read(notificationsRepositoryProvider);
    return repo.unreadCount();
  },
);
