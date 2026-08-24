import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/net/dio_provider.dart';
import '../../../core/identity/person_identity_model.dart';
import '../../../core/translation/communication_translation.dart'
    show CommunicationObjectType;

/// AURA CONVERSATION SYSTEM — canonical client.
/// Canon: aura-backend/docs/2026-08-16-aura-conversation-system-canon.md
///
/// ONE repository for the one conversation product. Speaks Conversation
/// semantics only — no thread/space/direct/correspondence vocabulary
/// anywhere in this module.

/// A party to a conversation — POLYMORPHIC by product design: a person or an
/// institution can both hold a seat. F116: the polymorphism is real and stays,
/// but the PERSON half is no longer interpreted here. When the party is a
/// person they are read by the one canonical reader; when the party is an
/// institution its name and logo remain institution identity, which must never
/// be collapsed into person identity.
class ConversationParty {
  const ConversationParty({
    required this.kind,
    required this.institutionId,
    required this.leftAt,
    this.person,
    this.institutionName,
    this.institutionLogoUrl,
    this.joinedAt,
    this.firstJoinedAt,
    this.enteredByInvitation = false,
  });

  final String kind; // PERSON | INSTITUTION
  final String? institutionId;
  final DateTime? leftAt;

  /// Present only when this seat is held by a person.
  final AuraPersonIdentity? person;

  /// Institution identity — deliberately separate fields, so no code path can
  /// read an institution's name through a person-shaped accessor.
  final String? institutionName;
  final String? institutionLogoUrl;

  /// Most recent entry. MUTABLE — rewritten on re-entry, so it must never
  /// be used as formation truth (F055 founder ruling).
  final DateTime? joinedAt;

  /// IMMUTABLE admission chronology: the first time this party entered the
  /// conversation. Leaving and rejoining does not rewrite it.
  final DateTime? firstJoinedAt;

  /// False for the founding parties, true for everyone admitted later
  /// through an invitation — how the conversation grew, not when a row
  /// happened to be written.
  final bool enteredByInvitation;

  bool get isActive => leftAt == null;
  bool get isPerson => kind == 'PERSON';

  /// The seat holder's id when it is a person. Absent rather than empty, so
  /// "is this me?" comparisons cannot succeed against a blank.
  String? get userId {
    final id = person?.userId ?? '';
    return id.isEmpty ? null : id;
  }

  /// What this seat is called — the person's canonical name, or the
  /// institution's own. One accessor, two identity domains, no shared parse.
  String? get displayName =>
      isPerson ? _emptyToNull(person?.displayName) : institutionName;

  /// Real identity image (person avatar / institution logo) from the
  /// canonical identity projection — never a synthesized placeholder.
  String? get avatarUrl => isPerson ? person?.avatarUrl : institutionLogoUrl;

  factory ConversationParty.fromJson(Map<String, dynamic> json) {
    final kind = (json['kind'] ?? 'PERSON').toString();
    final isPerson = kind == 'PERSON';
    return ConversationParty(
      kind: kind,
      person: isPerson ? AuraPersonIdentity.fromJson(json) : null,
      institutionId: _ns(json['institutionId']),
      institutionName: isPerson ? null : _ns(json['displayName']),
      institutionLogoUrl: isPerson ? null : _ns(json['avatarUrl']),
      leftAt: _date(json['leftAt']),
      joinedAt: _date(json['joinedAt']),
      firstJoinedAt: _date(json['firstJoinedAt']) ?? _date(json['joinedAt']),
      enteredByInvitation: json['enteredByInvitation'] == true,
    );
  }
}

/// The newest message a viewer can see in a conversation, as the inbox needs
/// it: short, already safe to render, and describing content it cannot show.
class ConversationLatest {
  const ConversationLatest({
    required this.messageId,
    required this.senderUserId,
    required this.preview,
    required this.at,
    required this.retracted,
    required this.contentKind,
  });

  final String messageId;
  final String senderUserId;

  /// Short text. Empty for a retraction or an attachment-only message — the
  /// surface describes those instead of showing a blank line.
  final String preview;
  final DateTime? at;

  /// The author withdrew it. Previewed AS a withdrawal, never as its old text.
  final bool retracted;

  /// TEXT | IMAGE | VIDEO | AUDIO | FILE | SYSTEM
  final String contentKind;

  bool get isText => contentKind == 'TEXT';

  static ConversationLatest fromJson(Map<String, dynamic> j) =>
      ConversationLatest(
        messageId: _s(j['messageId']),
        senderUserId: _s(j['senderUserId']),
        preview: _s(j['preview']),
        at: _date(j['at']),
        retracted: j['retracted'] == true,
        contentKind: (_ns(j['contentKind']) ?? 'TEXT'),
      );
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
    required this.pinned,
    required this.manuallyUnread,
    required this.clearedAt,
    required this.latest,
  });

  final String id;
  final String? name;
  final bool isDirect;
  final DateTime? lastMessageAt;
  final List<ConversationParty> parties;
  final int unreadCount;
  final bool archived;
  final bool muted;

  /// PERSONAL CONVERSATION STATE. Viewer-specific and owned by the
  /// Conversation authority, so a conversation pinned here is pinned wherever
  /// else it appears.
  final bool pinned;

  /// The viewer deliberately marked this unread — a different fact from having
  /// unread messages, which `unreadCount` already states.
  final bool manuallyUnread;

  /// This viewer's history boundary, when they have deleted this conversation
  /// from their own history. Exposed so an empty thread can be explained
  /// truthfully instead of looking broken.
  final DateTime? clearedAt;

  /// The newest thing this viewer can actually see here. Derived per viewer by
  /// the authority, so it already respects the clear boundary and anything this
  /// person removed from their own view. Null when there is nothing to show.
  final ConversationLatest? latest;

  /// Whether attention is owed, by either route: messages this viewer has not
  /// read, or a deliberate mark-unread.
  bool get needsAttention => unreadCount > 0 || manuallyUnread;

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
      pinned: json['pinned'] == true,
      manuallyUnread: json['manuallyUnread'] == true,
      clearedAt: _date(json['clearedAt']),
      latest: json['latest'] is Map
          ? ConversationLatest.fromJson(
              Map<String, dynamic>.from(json['latest'] as Map))
          : null,
    );
  }
}

/// What a forward actually carried.
class ForwardResult {
  const ForwardResult({
    required this.messageId,
    required this.attachments,
    required this.refusedReasons,
  });

  final String messageId;
  final int attachments;

  /// Why any attachment did not travel. Reported rather than swallowed.
  final List<String> refusedReasons;

  bool get hadRefusals => refusedReasons.isNotEmpty;
}

class ConversationMessage {
  const ConversationMessage({
    required this.id,
    required this.senderUserId,
    required this.speakingForInstitutionId,
    required this.body,
    required this.systemKind,
    required this.createdAt,
    required this.editedAt,
    required this.deleted,
    required this.reactions,
    required this.myReaction,
    required this.forwardedFromSenderUserId,
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

  /// When the author last edited this. Non-null means the surface must say so
  /// — a silently rewritten message is a record nobody can rely on.
  final DateTime? editedAt;

  /// The author retracted this for everyone. The row survives as a truthful
  /// tombstone, so replies to it stay structurally valid.
  final bool deleted;

  /// Reaction totals by type, and this viewer's own. Both come from the
  /// shared engagement authority.
  final Map<String, int> reactions;
  final String? myReaction;

  /// Who originally said this, when it arrived by forward. The source
  /// conversation is deliberately absent: a recipient learns who, never where.
  final String? forwardedFromSenderUserId;

  bool get isForwarded => forwardedFromSenderUserId != null;
  bool get wasEdited => editedAt != null;
  int get reactionTotal =>
      reactions.values.fold<int>(0, (sum, n) => sum + n);

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
    final rawReactions = json['reactions'];
    final reactions = <String, int>{};
    if (rawReactions is Map) {
      for (final entry in rawReactions.entries) {
        final n = entry.value;
        reactions[entry.key.toString()] =
            n is int ? n : int.tryParse(n.toString()) ?? 0;
      }
    }

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
      editedAt: _date(json['editedAt']),
      deleted: json['deleted'] == true || json['deletedAt'] != null,
      reactions: reactions,
      myReaction: _ns(json['myReaction']),
      forwardedFromSenderUserId: _ns(json['forwardedFromSenderUserId']),
      mediaIds: mediaRows.map((m) => _s(m['mediaId'])).toList(),
      media: mediaRows
          .map((m) => MessageMediaRef(
                mediaId: _s(m['mediaId']),
                kind: _ns(m['kind']),
                mimeType: _ns(m['mimeType']),
                fileName: _ns(m['fileName']),
                fileSizeBytes: m['fileSizeBytes'] is num
                    ? (m['fileSizeBytes'] as num).toInt()
                    : null,
                source: _ns(m['source']),
                durationMs: m['durationMs'] is num
                    ? (m['durationMs'] as num).toInt()
                    : null,
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
    this.fileName,
    this.fileSizeBytes,
    this.source,
    this.durationMs,
  });
  final String mediaId;
  final String? kind; // IMAGE | AUDIO | VIDEO | OTHER | null
  final String? mimeType;

  /// F011 — a file's own name is its identity. Without it every document
  /// rendered as the bare word "Attachment".
  final String? fileName;

  /// F011 — size is the other fact a person needs before opening something.
  final int? fileSizeBytes;

  /// F014 — canonical Media.source. RECORDING marks a captured voice message,
  /// which is a different product object from an uploaded audio file.
  final String? source;

  /// F014 — authoritative length in MILLISECONDS (F133).
  final int? durationMs;

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
      String? linkPreviewId,
      String? linkSourceUrl,
      // Structured identity references from the canonical tag composer --
      // never display-name text. Same wire shape every other mention-bearing
      // surface already sends.
      List<Map<String, dynamic>> tagReferences = const []}) async {
    final res = await _dio.post<dynamic>('/conversations/$id/messages', data: {
      'body': body,
      if (speakingForInstitutionId != null)
        'speakingForInstitutionId': speakingForInstitutionId,
      if (mediaIds.isNotEmpty) 'mediaIds': mediaIds,
      if (replyToMessageId != null) 'replyToMessageId': replyToMessageId,
      if (linkPreviewId != null) 'linkPreviewId': linkPreviewId,
      if (linkSourceUrl != null && linkSourceUrl.trim().isNotEmpty)
        'linkSourceUrl': linkSourceUrl,
      if (tagReferences.isNotEmpty) 'tagReferences': tagReferences,
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
      // Was a hand-written literal, because the shared enum was missing this
      // member. It is no longer missing, so the shared type is used.
      'objectType': CommunicationObjectType.conversationMessage.wireValue,
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

  // ── PERSONAL CONVERSATION STATE ────────────────────────────────────────
  //
  // Every verb here is a thin call onto the Conversation authority. No
  // semantics live in this client: pin, clear and mark-unread mean what the
  // authority says they mean, and a widget that tried to decide otherwise
  // would be inventing a second answer.

  Future<void> setPinned(String id, bool pinned) async {
    if (pinned) {
      await _dio.post<dynamic>('/conversations/$id/pin');
    } else {
      await _dio.delete<dynamic>('/conversations/$id/pin');
    }
  }

  /// Mark unread WITHOUT rewinding the read cursor — the authority records the
  /// assertion beside it, so reading later restores the exact derived count.
  Future<void> markUnread(String id) async {
    await _dio.post<dynamic>('/conversations/$id/unread');
  }

  /// DELETE FROM THIS VIEWER'S HISTORY.
  ///
  /// Not archive, not leave, and it takes nothing from the other party. The
  /// authority records a boundary; everything at or before it stops being
  /// presented to this viewer alone.
  Future<void> clearHistory(String id) async {
    await _dio.delete<dynamic>('/conversations/$id/history');
  }

  // ── MESSAGE LIFECYCLE ──────────────────────────────────────────────────

  Future<void> reactToMessage(
    String conversationId,
    String messageId,
    String type,
  ) async {
    await _dio.post<dynamic>(
      '/conversations/$conversationId/messages/$messageId/reactions',
      data: {'type': type},
    );
  }

  Future<void> unreactMessage(
    String conversationId,
    String messageId,
  ) async {
    await _dio.delete<dynamic>(
      '/conversations/$conversationId/messages/$messageId/reactions',
    );
  }

  /// EDIT — author only. Prior versions are retained by the authority.
  Future<void> editMessage(
    String conversationId,
    String messageId,
    String body,
  ) async {
    await _dio.patch<dynamic>(
      '/conversations/$conversationId/messages/$messageId',
      data: {'body': body},
    );
  }

  /// RETRACT FOR EVERYONE — author only. A truthful tombstone remains.
  Future<void> retractMessage(
    String conversationId,
    String messageId,
  ) async {
    await _dio.delete<dynamic>(
      '/conversations/$conversationId/messages/$messageId',
    );
  }

  /// REMOVE FOR ME — this viewer's presentation only. A separate address from
  /// retract on purpose: same-looking verbs with different consequences must
  /// not share one.
  Future<void> removeMessageForMe(
    String conversationId,
    String messageId,
  ) async {
    await _dio.delete<dynamic>(
      '/conversations/$conversationId/messages/$messageId/mine',
    );
  }

  /// FORWARD — carries the words and its rich content into another
  /// conversation as destination-governed instances.
  ///
  /// Returns what actually travelled, because attachments can legitimately
  /// refuse: content still being examined must not move past the check that is
  /// holding it, and the sender should not be left assuming it did.
  Future<ForwardResult> forwardMessage(
    String conversationId,
    String messageId,
    String destinationConversationId,
  ) async {
    final res = await _dio.post<dynamic>(
      '/conversations/$conversationId/messages/$messageId/forward',
      data: {'conversationId': destinationConversationId},
    );
    final body = res.data is Map
        ? Map<String, dynamic>.from(res.data as Map)
        : const <String, dynamic>{};
    final data = body['data'] is Map
        ? Map<String, dynamic>.from(body['data'] as Map)
        : body;
    final refused = data['attachmentsRefused'];
    return ForwardResult(
      messageId: _s(data['messageId']),
      attachments: _i(data['attachments']),
      refusedReasons: refused is List
          ? refused
              .whereType<Map>()
              .map((e) => (e['reason'] ?? '').toString())
              .where((r) => r.isNotEmpty)
              .toList()
          : const [],
    );
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

String? _emptyToNull(String? v) {
  final t = (v ?? '').trim();
  return t.isEmpty ? null : t;
}
