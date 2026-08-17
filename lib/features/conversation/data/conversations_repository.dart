import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/net/dio_provider.dart';

/// AURA CONVERSATION SYSTEM — canonical client.
/// Canon: aura-backend/docs/2026-08-16-aura-conversation-system-canon.md
///
/// ONE repository for the one conversation product. Speaks Conversation
/// semantics only — no thread/space/direct/correspondence vocabulary
/// anywhere in this module.

class ConversationParty {
  const ConversationParty({
    required this.kind,
    required this.userId,
    required this.institutionId,
    required this.leftAt,
    this.displayName,
    this.avatarUrl,
  });

  final String kind; // PERSON | INSTITUTION
  final String? userId;
  final String? institutionId;
  final DateTime? leftAt;
  final String? displayName;

  /// Real identity image (person avatar / institution logo) from the
  /// canonical identity projection — never a synthesized placeholder.
  final String? avatarUrl;

  bool get isActive => leftAt == null;
  bool get isPerson => kind == 'PERSON';

  factory ConversationParty.fromJson(Map<String, dynamic> json) {
    return ConversationParty(
      kind: (json['kind'] ?? 'PERSON').toString(),
      userId: _ns(json['userId']),
      institutionId: _ns(json['institutionId']),
      leftAt: _date(json['leftAt']),
      displayName: _ns(json['displayName']),
      avatarUrl: _ns(json['avatarUrl']),
    );
  }
}

class Conversation {
  const Conversation({
    required this.id,
    required this.name,
    required this.isDirect,
    required this.lastMessageAt,
    required this.parties,
    required this.unreadCount,
    required this.archived,
    required this.muted,
  });

  final String id;
  final String? name;
  final bool isDirect;
  final DateTime? lastMessageAt;
  final List<ConversationParty> parties;
  final int unreadCount;
  final bool archived;
  final bool muted;

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: _s(json['id']),
      name: _ns(json['name']),
      isDirect: json['isDirect'] == true,
      lastMessageAt: _date(json['lastMessageAt']),
      parties: (json['parties'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(ConversationParty.fromJson)
          .toList(),
      unreadCount: _i(json['unreadCount']),
      archived: json['archived'] == true,
      muted: json['muted'] == true,
    );
  }
}

class ConversationMessage {
  const ConversationMessage({
    required this.id,
    required this.senderUserId,
    required this.speakingForInstitutionId,
    required this.body,
    required this.systemKind,
    required this.createdAt,
    this.mediaIds = const [],
    this.media = const [],
    this.replyTo,
    this.linkPreview,
    this.internalRef,
  });

  final String id;
  final String senderUserId;
  final String? speakingForInstitutionId;
  final String body;
  final String? systemKind; // JOINED | LEFT | RENAMED | null
  final DateTime createdAt;

  /// Canonical Media ids attached to this message (position-ordered).
  final List<String> mediaIds;

  /// Kind/mime per attachment (from the canonical Media authority) so the
  /// bubble renders images/audio/video truthfully.
  final List<MessageMediaRef> media;

  /// Quoted parent (reply-to), server-verified to live in THIS conversation.
  final ReplyRef? replyTo;

  /// READY external link preview from the canonical link-intelligence
  /// pipeline (same LinkPreview rows Posts/Announcements consume).
  final LinkPreviewRef? linkPreview;

  /// READY internal Aura reference, resolved viewer-scoped at read time
  /// by the owning object's authority (Item 14).
  final InternalRef? internalRef;

  bool get isSystem => systemKind != null;

  factory ConversationMessage.fromJson(Map<String, dynamic> json) {
    final mediaRows = (json['media'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList()
      ..sort((a, b) => _i(a['position']).compareTo(_i(b['position'])));
    return ConversationMessage(
      id: _s(json['id']),
      senderUserId: _s(json['senderUserId']),
      speakingForInstitutionId: _ns(json['speakingForInstitutionId']),
      body: _s(json['body']),
      systemKind: _ns(json['systemKind']),
      createdAt: _date(json['createdAt']) ?? DateTime.now(),
      mediaIds: mediaRows.map((m) => _s(m['mediaId'])).toList(),
      media: mediaRows
          .map((m) => MessageMediaRef(
                mediaId: _s(m['mediaId']),
                kind: _ns(m['kind']),
                mimeType: _ns(m['mimeType']),
              ))
          .toList(),
      replyTo: json['replyTo'] is Map<String, dynamic>
          ? ReplyRef.fromJson(json['replyTo'] as Map<String, dynamic>)
          : null,
      linkPreview: json['linkPreview'] is Map<String, dynamic>
          ? LinkPreviewRef.fromJson(
              json['linkPreview'] as Map<String, dynamic>)
          : null,
      internalRef: json['internalRef'] is Map<String, dynamic>
          ? InternalRef.fromJson(json['internalRef'] as Map<String, dynamic>)
          : null,
    );
  }
}

class InternalRef {
  const InternalRef({
    required this.kind,
    required this.route,
    this.title,
    this.subtitle,
    this.imageUrl,
  });
  final String kind;
  final String route;
  final String? title;
  final String? subtitle;
  final String? imageUrl;

  factory InternalRef.fromJson(Map<String, dynamic> json) => InternalRef(
        kind: _s(json['kind']),
        route: _s(json['route']),
        title: _ns(json['title']),
        subtitle: _ns(json['subtitle']),
        imageUrl: _ns(json['imageUrl']),
      );
}

class ReplyRef {
  const ReplyRef({
    required this.id,
    required this.senderUserId,
    required this.body,
    required this.deleted,
  });
  final String id;
  final String senderUserId;
  final String body;
  final bool deleted;

  factory ReplyRef.fromJson(Map<String, dynamic> json) => ReplyRef(
        id: _s(json['id']),
        senderUserId: _s(json['senderUserId']),
        body: _s(json['body']),
        deleted: json['deleted'] == true,
      );
}

class LinkPreviewRef {
  const LinkPreviewRef({
    required this.url,
    this.title,
    this.description,
    this.siteName,
    this.imageUrl,
  });
  final String url;
  final String? title;
  final String? description;
  final String? siteName;
  final String? imageUrl;

  factory LinkPreviewRef.fromJson(Map<String, dynamic> json) =>
      LinkPreviewRef(
        url: _s(json['canonicalUrl']),
        title: _ns(json['title']),
        description: _ns(json['description']),
        siteName: _ns(json['siteName']),
        imageUrl: _ns(json['imageUrl']),
      );
}

class MessageMediaRef {
  const MessageMediaRef({
    required this.mediaId,
    required this.kind,
    required this.mimeType,
  });
  final String mediaId;
  final String? kind; // IMAGE | AUDIO | VIDEO | DOCUMENT | null
  final String? mimeType;

  bool get isImage =>
      (kind ?? '').toUpperCase() == 'IMAGE' ||
      (mimeType ?? '').startsWith('image/');
  bool get isAudio =>
      (kind ?? '').toUpperCase() == 'AUDIO' ||
      (mimeType ?? '').startsWith('audio/');
  bool get isVideo =>
      (kind ?? '').toUpperCase() == 'VIDEO' ||
      (mimeType ?? '').startsWith('video/');
}

class PendingInvitation {
  const PendingInvitation({
    required this.id,
    required this.targetKind,
    required this.targetId,
    required this.note,
    required this.inviterUserId,
  });

  final String id;
  final String targetKind;
  final String targetId;
  final String? note;
  final String inviterUserId;

  factory PendingInvitation.fromJson(Map<String, dynamic> json) {
    return PendingInvitation(
      id: _s(json['id']),
      targetKind: _s(json['targetKind']),
      targetId: _s(json['targetId']),
      note: _ns(json['note']),
      inviterUserId: _s(json['inviterUserId']),
    );
  }
}

class ConversationsRepository {
  ConversationsRepository(this._dio);
  final Dio _dio;

  Future<List<Conversation>> list({bool archived = false}) async {
    final res = await _dio.get<dynamic>('/conversations',
        queryParameters: {if (archived) 'archived': 'true'});
    return (_unwrap(res.data)['conversations'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(Conversation.fromJson)
        .toList();
  }

  Future<Conversation> openWithPerson(String userId,
      {String? firstMessage}) async {
    final res = await _dio.post<dynamic>('/conversations', data: {
      'personUserId': userId,
      if (firstMessage != null && firstMessage.trim().isNotEmpty)
        'firstMessage': firstMessage,
    });
    return Conversation.fromJson(
        _unwrap(res.data)['conversation'] as Map<String, dynamic>);
  }

  Future<Conversation> openWithInstitution(String institutionId) async {
    final res = await _dio
        .post<dynamic>('/conversations', data: {'institutionId': institutionId});
    return Conversation.fromJson(
        _unwrap(res.data)['conversation'] as Map<String, dynamic>);
  }

  Future<Conversation> detail(String id) async {
    final res = await _dio.get<dynamic>('/conversations/$id');
    return Conversation.fromJson(
        _unwrap(res.data)['conversation'] as Map<String, dynamic>);
  }

  Future<List<ConversationMessage>> messages(String id,
      {String? before}) async {
    final res = await _dio.get<dynamic>('/conversations/$id/messages',
        queryParameters: {if (before != null) 'before': before});
    return (_unwrap(res.data)['messages'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(ConversationMessage.fromJson)
        .toList();
  }

  Future<ConversationMessage> send(String id, String body,
      {String? speakingForInstitutionId,
      List<String> mediaIds = const [],
      String? replyToMessageId,
      String? linkPreviewId}) async {
    final res = await _dio.post<dynamic>('/conversations/$id/messages', data: {
      'body': body,
      if (speakingForInstitutionId != null)
        'speakingForInstitutionId': speakingForInstitutionId,
      if (mediaIds.isNotEmpty) 'mediaIds': mediaIds,
      if (replyToMessageId != null) 'replyToMessageId': replyToMessageId,
      if (linkPreviewId != null) 'linkPreviewId': linkPreviewId,
    });
    return ConversationMessage.fromJson(
        _unwrap(res.data)['message'] as Map<String, dynamic>);
  }

  /// Compose-time link resolution through the canonical SSRF-safe
  /// link-intelligence pipeline (internal Aura links hydrate from their
  /// own authorities; external links resolve to a LinkPreview).
  Future<Map<String, dynamic>> resolveLinkPreview(String url) async {
    final res =
        await _dio.post<dynamic>('/link-previews/resolve', data: {'url': url});
    return _unwrap(res.data) as Map<String, dynamic>? ?? const {};
  }

  /// On-demand translation through the canonical communication-translation
  /// engine (party-access-checked server-side).
  Future<String> translateMessage(
      String messageId, String sourceText, String targetLanguage) async {
    final res = await _dio.post<dynamic>('/communication/translate', data: {
      'objectType': 'CONVERSATION_MESSAGE',
      'objectId': messageId,
      'sourceText': sourceText,
      'targetLanguage': targetLanguage,
    });
    return _s(_unwrap(res.data)['translatedText']);
  }

  /// CAPABILITIES ATTACH (canon): start an ephemeral realtime session
  /// parented by this conversation. Returns the session id to join.
  Future<String> startLive(String id, {required String kind}) async {
    final path = kind == 'VIDEO' ? 'video' : 'audio';
    final res =
        await _dio.post<dynamic>('/conversations/$id/live/$path/start');
    final session =
        _unwrap(res.data)['session'] as Map<String, dynamic>? ?? const {};
    return _s(session['id']);
  }

  // startBroadcast was retired (founder charter 2026-08-17): a session is
  // never BORN public. Go Live escalates the CURRENT active call session
  // — see RealtimeRepository.goLive / endLive.

  /// DURABLE CALL TRUTH (founder-proven 2026-08-17: "if you refresh when
  /// it's freezed the call is gone to never come back rather than there
  /// as an option in thread header to accept or reject").
  ///
  /// A ringing call is durable server state, not an ephemeral push/socket
  /// card: this returns the conversation's currently ACTIVE realtime
  /// session (or null), so the thread can always reconstruct a truthful
  /// accept/decline affordance after a refresh, a missed notification, a
  /// dismissed card, or a frozen client.
  Future<Map<String, dynamic>?> activeLiveSession(String id) async {
    final res = await _dio.get<dynamic>('/conversations/$id/live');
    final body = _unwrap(res.data);
    final session = body['activeSession'];
    return session is Map ? Map<String, dynamic>.from(session) : null;
  }

  /// Render-ready delivery URL for an attachment (visibility-checked
  /// server-side by the canonical Media authority).
  Future<String?> mediaDeliveryUrl(String mediaId) async {
    final res = await _dio.get<dynamic>('/media/$mediaId/url');
    final body = _unwrap(res.data);
    return _ns(body['url'] ?? body['deliveryUrl']);
  }

  Future<void> addPeople(String id,
      {required List<Map<String, String>> recipients, String? note}) async {
    await _dio.post<dynamic>('/conversations/$id/parties', data: {
      'recipients': recipients,
      if (note != null && note.trim().isNotEmpty) 'note': note,
    });
  }

  Future<void> markRead(String id, {String? lastReadMessageId}) async {
    await _dio.post<dynamic>('/conversations/$id/read', data: {
      if (lastReadMessageId != null) 'lastReadMessageId': lastReadMessageId,
    });
  }

  Future<void> setArchived(String id, bool archived) async {
    await _dio
        .post<dynamic>('/conversations/$id/archive', data: {'archived': archived});
  }

  Future<void> setMuted(String id, bool muted) async {
    await _dio.post<dynamic>('/conversations/$id/mute', data: {'muted': muted});
  }

  Future<void> rename(String id, String? name) async {
    await _dio.post<dynamic>('/conversations/$id/name', data: {'name': name});
  }

  Future<void> leave(String id) async {
    await _dio.post<dynamic>('/conversations/$id/leave');
  }

  // ── Invitations (recipient side) ──────────────────────────────────

  Future<List<PendingInvitation>> myInvitations() async {
    final res = await _dio.get<dynamic>('/invitations');
    return (_unwrap(res.data)['invitations'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(PendingInvitation.fromJson)
        .toList();
  }

  Future<Map<String, dynamic>> acceptInvitation(String id) async {
    final res = await _dio.post<dynamic>('/invitations/$id/accept');
    return _unwrap(res.data)['invitation'] as Map<String, dynamic>? ?? const {};
  }

  Future<void> declineInvitation(String id) async {
    await _dio.post<dynamic>('/invitations/$id/decline');
  }

  Future<Map<String, dynamic>> claimPreview(String token) async {
    final res = await _dio.get<dynamic>('/invitations/claim/$token/preview');
    return _unwrap(res.data) as Map<String, dynamic>;
  }

  Future<PendingInvitation> claimBind(String token) async {
    final res = await _dio.post<dynamic>('/invitations/claim/$token/bind');
    return PendingInvitation.fromJson(
        _unwrap(res.data)['invitation'] as Map<String, dynamic>);
  }
}

dynamic _unwrap(dynamic raw) {
  if (raw is Map<String, dynamic>) {
    if (raw['data'] is Map<String, dynamic>) return raw['data'];
    return raw;
  }
  return raw;
}

String _s(dynamic v) => v == null ? '' : v.toString();
String? _ns(dynamic v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

int _i(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse('$v') ?? 0;
}

DateTime? _date(dynamic v) {
  if (v == null) return null;
  return DateTime.tryParse(v.toString());
}

final conversationsRepositoryProvider = Provider<ConversationsRepository>(
  (ref) => ConversationsRepository(ref.watch(dioProvider)),
);

final conversationsListProvider =
    FutureProvider.autoDispose<List<Conversation>>((ref) async {
  return ref.watch(conversationsRepositoryProvider).list();
});

final pendingInvitationsProvider =
    FutureProvider.autoDispose<List<PendingInvitation>>((ref) async {
  return ref.watch(conversationsRepositoryProvider).myInvitations();
});

final conversationProvider = FutureProvider.autoDispose
    .family<Conversation, String>((ref, id) async {
  return ref.watch(conversationsRepositoryProvider).detail(id);
});

final conversationMessagesProvider = FutureProvider.autoDispose
    .family<List<ConversationMessage>, String>((ref, id) async {
  return ref.watch(conversationsRepositoryProvider).messages(id);
});
