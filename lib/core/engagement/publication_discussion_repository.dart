import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../net/dio_provider.dart';
import 'engagement_model.dart';

/// One reply, as any publication surface needs to render it.
///
/// A reply IS a Post on Aura — frozen canon — so this deliberately mirrors the
/// post shape rather than inventing a "comment" model that would have to be
/// reconciled with posts later.
class PublicationReply {
  const PublicationReply({
    required this.id,
    required this.text,
    this.authorName = '',
    this.authorHandle,
    this.authorAvatarUrl,
    this.authorUserId,
    this.createdAt,
  });

  final String id;
  final String text;
  final String authorName;
  final String? authorHandle;
  final String? authorAvatarUrl;
  final String? authorUserId;
  final DateTime? createdAt;

  static PublicationReply fromJson(Map<String, dynamic> j) {
    final a = (j['author'] is Map)
        ? Map<String, dynamic>.from(j['author'] as Map)
        : const <String, dynamic>{};
    DateTime? when;
    final raw = j['createdAt'];
    if (raw != null) when = DateTime.tryParse(raw.toString());
    return PublicationReply(
      id: (j['id'] ?? '').toString(),
      text: (j['text'] ?? '').toString(),
      authorName: (a['displayName'] ?? a['proseName'] ?? '').toString(),
      authorHandle: (a['handle'] ?? '').toString().isEmpty
          ? null
          : a['handle'].toString(),
      authorAvatarUrl: (a['avatarUrl'] ?? '').toString().isEmpty
          ? null
          : a['avatarUrl'].toString(),
      authorUserId: (a['userId'] ?? a['id'] ?? '').toString().isEmpty
          ? null
          : (a['userId'] ?? a['id']).toString(),
      createdAt: when,
    );
  }
}

/// Discussion client for any eligible publication class.
///
/// Talks to the canonical `/engagement/:targetType/:targetId/replies` surface,
/// which is itself served by the posts authority. There is no article-specific
/// comment API and no article-specific comment model.
class PublicationDiscussionRepository {
  PublicationDiscussionRepository(this._dio);
  final Dio _dio;

  String _base(PublicationTarget target, String id) =>
      '/engagement/${target.wireValue}/${Uri.encodeComponent(id)}/replies';

  List<PublicationReply> _items(dynamic data) {
    final root = data is Map ? Map<String, dynamic>.from(data) : {};
    final payload = root['data'] is Map
        ? Map<String, dynamic>.from(root['data'] as Map)
        : root;
    final items = payload['items'];
    if (items is! List) return const [];
    return items
        .whereType<Map>()
        .map((m) => PublicationReply.fromJson(Map<String, dynamic>.from(m)))
        .toList(growable: false);
  }

  Future<List<PublicationReply>> list(
    PublicationTarget target,
    String id,
  ) async {
    final res = await _dio.get<dynamic>(_base(target, id));
    return _items(res.data);
  }

  Future<void> reply(
    PublicationTarget target,
    String id,
    String text,
  ) async {
    await _dio.post<dynamic>(_base(target, id), data: {'text': text});
  }

  /// Native reshare — distinct from external share. A share sheet hands
  /// someone a link; this brings the publication into Aura's own feed under
  /// the resharer's name, with the original still the canonical object.
  Future<void> reshare(
    PublicationTarget target,
    String id,
    String commentary,
  ) async {
    await _dio.post<dynamic>(
      '/engagement/${target.wireValue}/${Uri.encodeComponent(id)}/reshare',
      data: {'text': commentary},
    );
  }
}

final publicationDiscussionRepositoryProvider =
    Provider<PublicationDiscussionRepository>(
  (ref) => PublicationDiscussionRepository(ref.watch(dioProvider)),
);

final publicationDiscussionProvider = FutureProvider.autoDispose
    .family<List<PublicationReply>, ({PublicationTarget target, String id})>(
  (ref, key) => ref
      .watch(publicationDiscussionRepositoryProvider)
      .list(key.target, key.id),
);
