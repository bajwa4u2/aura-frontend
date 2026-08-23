import '../../features/realtime/application/incoming_call_projection.dart'
    as call_kinds;
import '../identity/person_identity_model.dart';

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

  // TERMINAL CALL CLASSES ARE CALLS TOO.
  //
  // `isCallKind` covers the RINGING vocabulary (LIVE / CALL / REALTIME /
  // *_RINGING) because that set also drives ringing behaviour, and adding
  // terminal outcomes to it would make the incoming-call layer treat a missed
  // call as an arriving one. But a NotificationType of CALL_MISSED is
  // unquestionably about a call, and it was reaching neither the call titler
  // nor `_kindPhrase` — so it fell through to the bare actor name and rendered
  // as "Zakria". That is the exact vague presentation this module exists to
  // remove, and it was caught by the Windows desktop certification run rather
  // than by any web check.
  const terminalCallTypes = <String, String>{
    'CALL_MISSED': 'MISSED',
    'CALL_ENDED': 'ENDED',
    'CALL_DECLINED': 'DECLINED',
  };
  final terminalState = terminalCallTypes[kind];
  if (terminalState != null) {
    return _callTitle(
      <String, dynamic>{...payload, 'callState': terminalState},
      actorName,
    );
  }

  // Payload-refined titles come FIRST: these classes say something more
  // specific when the payload carries the detail. They lived in the
  // Notifications screen's own switch, which is exactly how the client came to
  // have two resolvers that disagreed — the screen knew these, the canonical
  // resolver knew calls, and neither knew both.
  final refined = _payloadRefinedTitle(kind, payload, data, actorName);
  if (refined != null) return refined;

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
/// Titles that depend on the payload, not only on the kind.
String? _payloadRefinedTitle(
  String kind,
  Map<String, dynamic> payload,
  Map<String, dynamic> data,
  String actorName,
) {
  String field(String key) =>
      _stringOf(payload[key]).isNotEmpty ? _stringOf(payload[key]) : _stringOf(data[key]);

  switch (kind) {
    // Not actor-voiced, deliberately. No person acted on these: an examiner
    // produced a verdict. Rendering them in someone's voice would tell a member
    // a human reviewed their file when nobody has.
    case 'MEDIA_QUARANTINED':
      return 'An attachment of yours is under review';
    case 'MEDIA_QUARANTINE_LIFTED':
      return 'An attachment of yours is available again';

    case 'SPACE_ACTIVITY':
      final spaceName = field('spaceName');
      if (actorName.isEmpty) return null;
      return spaceName.isNotEmpty
          ? '$actorName posted in $spaceName'
          : '$actorName posted in a space you follow';

    case 'MEETING_BOOKED':
      if (actorName.isEmpty) return null;
      final pending = payload['pendingConfirmation'] == true ||
          data['pendingConfirmation'] == true;
      return pending
          ? 'A meeting with $actorName was booked with your email'
          : 'Your meeting with $actorName is scheduled';

    // The announcement's own title says more than "published an announcement".
    case 'ANNOUNCEMENT_PUBLISHED':
      final announcementTitle = field('title');
      if (announcementTitle.isNotEmpty) return announcementTitle;
      return null;

    // Moderation outcomes name what actually happened to what. These were the
    // richest cases in the Activity screen's own resolver and are kept, not
    // flattened into "your content was reviewed". Never actor-voiced: the
    // member is not told a named person judged them.
    case 'MODERATION_ACTION_TAKEN':
      switch (field('action').toUpperCase()) {
        case 'SOFT_DELETE_POST':
        case 'SOFT_DELETE_MESSAGE':
        case 'SOFT_DELETE_ANNOUNCEMENT':
          return 'Your content was removed by moderation';
        case 'ARCHIVE_INSTITUTION_POST':
          return 'Your institution post was archived';
        case 'DISABLE_USER':
          return 'Your account was disabled';
        case 'RESTORE_POST':
        case 'RESTORE_MESSAGE':
        case 'RESTORE_ANNOUNCEMENT':
        case 'RESTORE_INSTITUTION_POST':
          return 'Your content was restored';
        case 'RESTORE_USER':
          return 'Your account was restored';
        default:
          return 'Your content was reviewed by moderation';
      }

    // One class covers every stage of the accountability lifecycle; the stage
    // rides in the payload.
    case 'ACCOUNTABILITY_TAGGED':
      if (actorName.isEmpty) return null;
      switch (field('accountabilityTag').toUpperCase()) {
        case 'RESOLVED':
          return '$actorName marked your issue as Resolved';
        case 'COMMITMENT':
          return '$actorName committed to a response on your issue';
        case 'UPDATE':
          return '$actorName posted an update on your issue';
        case 'REOPENED':
          return '$actorName reopened a resolved issue';
        default:
          return '$actorName updated the status of your issue';
      }
  }
  return null;
}

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
    // Institution Ownership Continuity — governance attention for an
    // institution's remaining admins. Names the governance truth without
    // exposing why the previous owner became unactionable.
    case 'INSTITUTION_OWNERSHIP_RECOVERED':
      return 'restored ownership of an institution you help govern';
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
  // F053/F116 — one reader. `actorName` remains as a legacy flattened field
  // some payloads still carry; it is consulted only when the canonical
  // person cannot be resolved, rather than competing with it.
  final person = AuraPersonIdentity.fromJson(payload['actor']);
  // Notification copy is a SENTENCE, so the prose rendering is used: the
  // fallback order is the canonical one, the '@' is not.
  if (person.isNotEmpty) return person.proseName;
  return _stringOf(payload['actorName']);
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

// ─────────────────────────────────────────────────────────────────────────────
// SUBJECT GROUPING
//
// The Activity surface used to classify notifications with its own hand-listed
// type strings. Measured against production on 2026-08-23, that list matched
// 73 of 228 notifications: 68% were reachable by no filter at all, the Messages
// filter was entirely dead (it looked for `MESSAGE_RECEIVED` while the enum
// value is `MESSAGE`), and the single largest kind -- CALL_MISSED, 95 rows --
// belonged to no group. Two of its entries were not valid enum values.
//
// So grouping lives here, beside the title and body resolvers, and Activity
// consumes it. One authority answering "what kind of thing is this", not a
// second list drifting beside the first.
//
// EXHAUSTIVE BY CONSTRUCTION: every value of the backend NotificationType enum
// is named below, and an unrecognised kind falls to `system` rather than
// vanishing -- a notification the product cannot classify is still a
// notification the recipient must be able to reach.
// ─────────────────────────────────────────────────────────────────────────────

enum NotificationGroup { conversations, calls, meetings, social, announcements, system }

NotificationGroup resolveNotificationGroup(Map<String, dynamic> payload) =>
    notificationGroupForKind(_resolveKind(payload));

/// The classification itself, as data. A map rather than a switch so the set
/// of NAMED kinds is inspectable -- a gate can then assert that every backend
/// enum value is named here, which a switch with a default cannot express.
const Map<String, NotificationGroup> kNotificationGroups = <String, NotificationGroup>{
  'MESSAGE': NotificationGroup.conversations,
  'MENTION': NotificationGroup.conversations,
  'SPACE_INVITE': NotificationGroup.conversations,
  'THREAD_INVITE': NotificationGroup.conversations,
  'INVITATION': NotificationGroup.conversations,
  'INVITE_ACCEPTED': NotificationGroup.conversations,

  'CALL_MISSED': NotificationGroup.calls,

  'MEETING_BOOKED': NotificationGroup.meetings,
  'MEETING_REMINDER': NotificationGroup.meetings,
  'MEETING_STARTING': NotificationGroup.meetings,
  'MEETING_SUMMARY_SHARED': NotificationGroup.meetings,
  'MEETING_RESCHEDULED': NotificationGroup.meetings,
  'MEETING_CANCELLED': NotificationGroup.meetings,
  'MEETING_RSVP_ACCEPTED': NotificationGroup.meetings,
  'MEETING_RSVP_DECLINED': NotificationGroup.meetings,
  'MEETING_WAITING_ROOM_ARRIVAL': NotificationGroup.meetings,

  'FOLLOW': NotificationGroup.social,
  'FOLLOW_REQUEST': NotificationGroup.social,
  'FOLLOW_ACCEPTED': NotificationGroup.social,
  'LIKE': NotificationGroup.social,
  'SAVE': NotificationGroup.social,
  'REPLY': NotificationGroup.social,
  'REPOST': NotificationGroup.social,
  'ACCOUNTABILITY_TAGGED': NotificationGroup.social,
  'PRIORITY_PINNED': NotificationGroup.social,
  'THREAD_ACTIVITY': NotificationGroup.social,
  'SPACE_ACTIVITY': NotificationGroup.social,

  'ANNOUNCEMENT_PUBLISHED': NotificationGroup.announcements,
  'INSTITUTION_POST_PUBLISHED': NotificationGroup.announcements,

  'POST_PUBLISHED': NotificationGroup.system,
  'POST_PUBLISH_FAILED': NotificationGroup.system,
  'SYSTEM': NotificationGroup.system,
  'MODERATION_ACTION_TAKEN': NotificationGroup.system,
  'REPORT_RESOLVED': NotificationGroup.system,
  'ROLE_CHANGED': NotificationGroup.system,
  'CAPABILITY_GRANTED': NotificationGroup.system,
  'CAPABILITY_REVOKED': NotificationGroup.system,
  'INSTITUTION_OWNERSHIP_RECOVERED': NotificationGroup.system,
  'MEDIA_QUARANTINED': NotificationGroup.system,
  'MEDIA_QUARANTINE_LIFTED': NotificationGroup.system,
  'IDENTITY': NotificationGroup.system,
  'INSTITUTION_AFFILIATION': NotificationGroup.system,
  'ROLE_OR_CREDENTIAL': NotificationGroup.system,
  'NOT_VERIFIED': NotificationGroup.system,
};

NotificationGroup notificationGroupForKind(String rawKind) {
  final kind = rawKind.trim().toUpperCase();

  // Defer to the call authority rather than restating which kinds are calls.
  if (call_kinds.isCallKind(kind)) return NotificationGroup.calls;

  // Never hidden. An unrecognised kind is reachable under System until it is
  // named, because a notification the product cannot classify is still a
  // notification the recipient must be able to find.
  return kNotificationGroups[kind] ?? NotificationGroup.system;
}

String notificationGroupLabel(NotificationGroup group) {
  switch (group) {
    case NotificationGroup.conversations:
      return 'Messages';
    case NotificationGroup.calls:
      return 'Calls';
    case NotificationGroup.meetings:
      return 'Meetings';
    case NotificationGroup.social:
      return 'Social';
    case NotificationGroup.announcements:
      return 'Announcements';
    case NotificationGroup.system:
      return 'System';
  }
}
