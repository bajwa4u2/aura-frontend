/// INVITE PRESENTATION — how an invitation names itself on screen.
///
/// Relocated from `features/correspondence/data/correspondence_identity.dart`
/// (2026-08-20). It never belonged there: these are invitation-domain strings,
/// and the only reason they lived in the correspondence data layer is that the
/// correspondence surfaces happened to be built first.
///
/// The move is what lets the correspondence family die. `invitations_screen` is
/// a LIVE, routed surface that survives the C7 retirement; while it imported
/// `CorrespondenceIdentity`, deleting that class would have broken it, and the
/// seven person-identity sites inside it could never be discharged by the
/// retirement that owns them. Nothing here was canonicalised or improved —
/// preserving behaviour exactly is the point, because this is a relocation, not
/// a rewrite.
///
/// PERSON IDENTITY IS DELIBERATELY NOT READ HERE. These helpers read invitation
/// STATE — destination type, access policy, status — and the names they surface
/// are read positionally out of the invite payload's own envelopes. When this
/// screen is reconstructed, the person-shaped reads below (`invitedBy`,
/// `inviter`, `recipient`, …) are the ones that should move to
/// `AuraPersonIdentity`; they are left as-is now so this change stays a pure
/// relocation and the identity work is done deliberately rather than smuggled
/// in alongside it.
///
/// KNOWN LEGACY COUPLING, recorded not fixed: [inviteDestinationRoute] still
/// emits `/me/correspondence/...` addresses. That is the same legacy deep-link
/// production the CO-RC-C7-005 readiness audit found in eleven backend files,
/// and it is dispositioned there, not here.
library;

class InvitePresentation {
  const InvitePresentation._();

  static String title(Map<String, dynamic> invite) {
    final destinationType =
        _pick(invite, const ['destinationType', 'destination_type'])
            .toUpperCase();
    final threadTitle = _pickNested(invite, const [
      ['thread', 'title'],
      ['thread', 'name'],
    ]).isNotEmpty
        ? _pickNested(invite, const [
            ['thread', 'title'],
            ['thread', 'name'],
          ])
        : _pick(invite, const ['threadTitle', 'threadName', 'thread_title']);
    final spaceTitle = _pickNested(invite, const [
      ['space', 'title'],
      ['space', 'name'],
    ]).isNotEmpty
        ? _pickNested(invite, const [
            ['space', 'title'],
            ['space', 'name'],
          ])
        : _pick(invite, const ['spaceTitle', 'spaceName', 'space_title']);
    final inviterName = _pickNested(invite, const [
      ['invitedBy', 'displayName'],
      ['inviter', 'displayName'],
      ['invitedBy', 'handle'],
      ['inviter', 'handle'],
    ]);

    switch (destinationType) {
      case 'JOIN_SPACE':
        return spaceTitle.isNotEmpty
            ? 'Invitation to $spaceTitle'
            : inviterName.isNotEmpty
                ? '$inviterName invited you into a space'
                : 'Space invitation';
      case 'JOIN_THREAD':
        return threadTitle.isNotEmpty
            ? 'Invitation to $threadTitle'
            : 'Thread invitation';
      case 'START_1_TO_1':
        return inviterName.isNotEmpty
            ? '$inviterName invited you to correspond'
            : 'Direct invitation';
      case 'JOIN_AURA':
        return 'Invitation to Aura';
      default:
        return 'Invitation';
    }
  }

  static String subtitle(Map<String, dynamic> invite) {
    final message = _pick(invite, const ['message']);
    if (message.isNotEmpty) return message;

    final policy =
        _pick(invite, const ['accessPolicy', 'access_policy']).replaceAll('_', ' ');
    final recipientName = _pickNested(invite, const [
      ['recipient', 'displayName'],
      ['recipientUser', 'displayName'],
      ['invitedUser', 'displayName'],
      ['recipientProfile', 'displayName'],
      ['directRecipient', 'displayName'],
    ]);
    final recipientHandle =
        _pick(invite, const ['recipientHandle', 'recipient_handle']);
    final inviterName = _pickNested(invite, const [
      ['invitedBy', 'displayName'],
      ['inviter', 'displayName'],
      ['createdBy', 'displayName'],
    ]);
    final parts = <String>[
      if (policy.isNotEmpty) 'Access: $policy',
      if (recipientName.isNotEmpty) 'For: $recipientName',
      if (recipientHandle.isNotEmpty) 'For: @$recipientHandle',
      if (inviterName.isNotEmpty) 'From: $inviterName',
    ];
    return parts.isEmpty ? 'Invitation in progress.' : parts.join(' · ');
  }

  static String stateLabel(Map<String, dynamic> invite) {
    final status = _pick(invite, const ['status']);
    return status.isEmpty ? 'Pending' : humanize(status);
  }

  static bool isActive(Map<String, dynamic> invite) {
    final status = _pick(invite, const ['status']).toUpperCase();
    return status.isEmpty ||
        status == 'PENDING' ||
        status == 'SENT' ||
        status == 'CREATED' ||
        status == 'OPEN' ||
        status == 'OPENED';
  }

  static String avatarUrl(Map<String, dynamic> invite) {
    return _pickNested(invite, const [
      ['recipient', 'avatarUrl'],
      ['recipientUser', 'avatarUrl'],
      ['invitedUser', 'avatarUrl'],
      ['recipientProfile', 'avatarUrl'],
      ['directRecipient', 'avatarUrl'],
      ['inviter', 'avatarUrl'],
    ]);
  }

  static String destinationRoute(Map<String, dynamic> invite) {
    final threadId = _pick(invite, const ['threadId', 'thread_id']);
    final spaceId = _pick(invite, const ['spaceId', 'space_id']);
    final destinationType =
        _pick(invite, const ['destinationType', 'destination_type'])
            .toUpperCase();

    if (threadId.isNotEmpty && spaceId.isNotEmpty) {
      return '/me/correspondence/$spaceId/thread/$threadId';
    }
    if (spaceId.isNotEmpty) {
      return '/me/correspondence/$spaceId';
    }
    if (destinationType == 'JOIN_AURA') return '/home';
    return '/me/invitations';
  }

  /// Wire enum to sentence case — 'JOIN_SPACE' becomes 'Join space'.
  static String humanize(String value) {
    final text = value.trim();
    if (text.isEmpty) return '';
    return text
        .replaceAll('_', ' ')
        .split(RegExp(r'\s+'))
        .map((word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}')
        .join(' ');
  }

  /// Generic first-non-empty key read. Not identity: these keys name
  /// invitation state, and where a person appears the envelope is read
  /// positionally by the callers above.
  static String _pick(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  static String _pickNested(Map<String, dynamic> map, List<List<String>> paths) {
    for (final path in paths) {
      dynamic current = map;
      for (final key in path) {
        if (current is Map && current.containsKey(key)) {
          current = current[key];
        } else {
          current = null;
          break;
        }
      }
      if (current == null) continue;
      final text = current.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return '';
  }
}
