import '../../features/realtime/application/incoming_call_projection.dart'
    as call_kinds;

/// Release-Client Cross-System Quality Doctrine — Legacy Global Runtime
/// Overlay Cleanup (roadmap item 11).
///
/// Traced `NotificationBridge`'s two nearly-duplicate title/body resolvers
/// (`_payloadTitle`/`_payloadBody` for the FCM path, `_notificationTitle`/
/// `_notificationBody` for the poll path) before touching anything. Call
/// lifecycle events already route to their correct targeted presentation
/// (`AuraIncomingLiveLayer`'s ringing card, the floating call widget) and
/// are explicitly excluded upstream of this module — this file is not
/// call presentation, it never was, and stays that way.
///
/// The actual defect: every OTHER notification kind — likes, replies,
/// reposts, follows, messages, mentions, institution posts, meetings,
/// moderation outcomes, role/capability changes — collapsed into either a
/// bare actor name with no indication of what happened, or the literal
/// string `'Update'` when no actor was present. That is the "vague global
/// overlay" the item names. The fix is not a second global overlay or a
/// new attention authority (Institutional Attention remains its own,
/// separately-frozen, not-yet-implemented future chapter — this module
/// does not invent a substitute for it) — it's making the ONE existing
/// overlay's text kind-specific, consolidated into one shared, pure,
/// testable resolver instead of two drifting copies.
///
/// [payload] is intentionally untyped — it is the same shape whether it
/// arrived from an FCM `RemoteMessage.data`/`.notification` merge or from
/// the polled `AppNotification` list; both call sites already normalize to
/// `Map<String, dynamic>` before reaching this resolver.
String resolveNotificationTitle(Map<String, dynamic> payload) {
  final kind = _resolveKind(payload);
  final data = _mapOf(payload['data']);
  final actorName = _actorName(payload);

  if (call_kinds.isCallKind(kind)) {
    return _callTitle(payload, actorName);
  }

  final phrase = _kindPhrase(kind);
  if (phrase != null) {
    return actorName.isNotEmpty ? '$actorName $phrase' : _capitalize(phrase);
  }

  // Backend-provided title (some notification producers already supply
  // one) wins over a bare actor name — a bare name with no verb is exactly
  // the "vague" presentation this module exists to remove.
  final backendTitle = _firstNonEmpty([
    _stringOf(payload['title']),
    _stringOf(data['title']),
  ]);
  if (backendTitle.isNotEmpty) return backendTitle;

  if (actorName.isNotEmpty) return actorName;

  // Last-resort fallback for a genuinely unrecognized/future notification
  // kind this module doesn't know about yet — not the common case anymore.
  return 'Update';
}

String resolveNotificationBody(Map<String, dynamic> payload) {
  final data = _mapOf(payload['data']);
  return _firstNonEmpty([
    _stringOf(payload['body']),
    _stringOf(data['previewText']),
    _stringOf(data['body']),
  ]);
}

String _callTitle(Map<String, dynamic> payload, String actorName) {
  final callState = _firstNonEmpty([
    _stringOf(payload['callState']),
    _stringOf(_mapOf(payload['data'])['callState']),
  ]).toUpperCase();

  if (callState == 'MISSED') {
    return actorName.isNotEmpty ? 'Missed call from $actorName' : 'Missed call';
  }
  if (callState == 'ENDED') {
    return actorName.isNotEmpty ? 'Call ended with $actorName' : 'Call ended';
  }
  if (callState == 'DECLINED') {
    return actorName.isNotEmpty ? '$actorName declined' : 'Call declined';
  }
  return actorName.isNotEmpty ? '$actorName started a call' : 'Incoming call';
}

/// Verb phrase completing "<actor> <phrase>" — covers every
/// `NotificationType` enum value with an established, common meaning.
/// Returns null for kinds handled elsewhere (calls) or genuinely unknown
/// ones, which fall through to the backend-title / bare-name / 'Update'
/// chain above.
String? _kindPhrase(String kind) {
  switch (kind) {
    case 'LIKE':
      return 'liked your post';
    case 'SAVE':
      return 'saved your post';
    case 'REPLY':
      return 'replied to your post';
    case 'REPOST':
      return 'reposted your post';
    case 'MENTION':
      return 'mentioned you';
    case 'FOLLOW':
      return 'started following you';
    case 'FOLLOW_REQUEST':
      return 'requested to follow you';
    case 'FOLLOW_ACCEPTED':
      return 'accepted your follow request';
    case 'MESSAGE':
      return 'sent you a message';
    case 'SPACE_INVITE':
      return 'invited you to a Space';
    case 'THREAD_INVITE':
      return 'invited you to a conversation';
    case 'INVITE_ACCEPTED':
      return 'accepted your invitation';
    case 'THREAD_ACTIVITY':
      return 'posted in a conversation you follow';
    case 'SPACE_ACTIVITY':
      return 'posted in a Space you follow';
    case 'ACCOUNTABILITY_TAGGED':
      return 'updated the status of a reply';
    case 'PRIORITY_PINNED':
      return 'pinned a reply';
    case 'MEETING_BOOKED':
      return 'booked a meeting with you';
    case 'MEETING_REMINDER':
      return 'has an upcoming meeting';
    case 'MEETING_STARTING':
      return 'meeting is starting now';
    case 'MEETING_RESCHEDULED':
      return 'rescheduled a meeting';
    case 'MEETING_CANCELLED':
      return 'cancelled a meeting';
    case 'MEETING_RSVP_ACCEPTED':
      return 'accepted a meeting invite';
    case 'MEETING_RSVP_DECLINED':
      return 'declined a meeting invite';
    case 'MEETING_WAITING_ROOM_ARRIVAL':
      return 'is waiting to join a meeting';
    case 'MEETING_SUMMARY_SHARED':
      return 'shared a meeting summary';
    case 'ANNOUNCEMENT_PUBLISHED':
      return 'published an announcement';
    case 'INSTITUTION_POST_PUBLISHED':
      return 'published a new post';
    case 'POST_PUBLISHED':
      return 'published a post';
    case 'POST_PUBLISH_FAILED':
      return 'post could not be published';
    case 'MODERATION_ACTION_TAKEN':
      return 'reviewed a report on your content';
    case 'REPORT_RESOLVED':
      return 'resolved a report you filed';
    case 'ROLE_CHANGED':
      return 'changed your role';
    case 'CAPABILITY_GRANTED':
      return 'granted you a new capability';
    case 'CAPABILITY_REVOKED':
      return 'revoked a capability';
    default:
      return null;
  }
}

String _resolveKind(Map<String, dynamic> payload) {
  final data = _mapOf(payload['data']);
  return _firstNonEmpty(<String>[
    _stringOf(payload['notificationKind']),
    _stringOf(payload['type']),
    _stringOf(payload['communicationType']),
    _stringOf(payload['kind']),
    _stringOf(data['notificationKind']),
    _stringOf(data['communicationType']),
    _stringOf(data['type']),
  ]).toUpperCase();
}

String _actorName(Map<String, dynamic> payload) {
  final actor = _mapOf(payload['actor']);
  return _firstNonEmpty([
    _stringOf(actor['displayName']),
    _stringOf(actor['handle']),
    _stringOf(payload['actorName']),
  ]);
}

String _capitalize(String value) {
  if (value.isEmpty) return value;
  return value[0].toUpperCase() + value.substring(1);
}

String _firstNonEmpty(List<String> values) {
  for (final value in values) {
    final text = value.trim();
    if (text.isNotEmpty) return text;
  }
  return '';
}

Map<String, dynamic> _mapOf(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

String _stringOf(dynamic value) => value?.toString().trim() ?? '';
