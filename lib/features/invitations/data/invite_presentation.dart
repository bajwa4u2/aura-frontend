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
/// retirement that owns them. The move was a pure relocation; the identity work
/// below came after, deliberately and separately.
///
/// PERSON IDENTITY IS CANONICAL HERE (F053/F116, 2026-08-20).
///
/// When these helpers were relocated out of the retiring correspondence family
/// they carried five person-shaped POSITIONAL reads — `['invitedBy',
/// 'displayName']`, `['inviter', 'handle']`, `['recipient', 'avatarUrl']` and
/// so on. That was recorded at the time as debt moved into surviving code, and
/// deliberately left visible rather than quietly fixed inside a relocation.
///
/// It is fixed now, and the split is the point:
///
///   THE INVITATION DOMAIN knows WHERE a person sits in its own payload — an
///   invite calls them `invitedBy` or `inviter`, `recipient` or `invitedUser`.
///   That is invitation knowledge and stays here.
///
///   THE PERSON AUTHORITY knows HOW to read one — which aliases count, which
///   envelope to unwrap, and what to do when a name is missing. That is
///   `AuraPersonIdentity` and it is not re-decided here.
///
/// The producer confirms this is genuine person identity rather than incidental
/// strings: `invitations.service.ts` selects these people with
/// `PERSON_REFERENCE_SELECT`, the canonical person projection. Reading a
/// canonical person payload with a private alias order is exactly the F053
/// defect, so the aliases are gone.
///
/// The detector could not see these reads — it recognises flat alias lists, not
/// nested positional path pairs. They were fixed because they were real, not
/// because a metric found them.
///
/// LEGACY DESTINATIONS ARE NO LONGER EMITTED. [destinationRoute] used to return
/// `/me/correspondence/...` addresses. Phase 5 retired those routes, so sending
/// anyone there would be routing live product traffic into a runtime that no
/// longer exists. An invite whose destination was a retired correspondence
/// space now resolves to the invitations hub, which is honest about what can
/// still be opened. No translator was built to resurrect the old address.
library;

import '../../../core/identity/person_identity_model.dart';

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
    final inviterName = _nameOf(_inviter(invite));

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
    final recipient = _recipient(invite);
    final recipientName = _nameOf(recipient);
    // The invite may carry a bare handle string of its own when no recipient
    // person is embedded — invitation state, not a second person reader.
    final recipientHandle = recipient.handle.trim().isNotEmpty
        ? recipient.handle.trim()
        : _pick(invite, const ['recipientHandle', 'recipient_handle']);
    final inviterName = _nameOf(_inviter(invite));
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

  /// The face to show on the invite — the recipient's, or the inviter's when
  /// the invite names no recipient person.
  static String avatarUrl(Map<String, dynamic> invite) {
    final recipient = _recipient(invite);
    final fromRecipient = (recipient.avatarUrl ?? '').trim();
    if (fromRecipient.isNotEmpty) return fromRecipient;
    return (_inviter(invite).avatarUrl ?? '').trim();
  }

  static String destinationRoute(Map<String, dynamic> invite) {
    final threadId = _pick(invite, const ['threadId', 'thread_id']);
    final spaceId = _pick(invite, const ['spaceId', 'space_id']);
    final destinationType =
        _pick(invite, const ['destinationType', 'destination_type'])
            .toUpperCase();

    // Phase 5: correspondence spaces and threads have no routes. Rather than
    // hand back a dead address, an invite that pointed at one resolves to the
    // hub where its own state is visible.
    if (destinationType == 'JOIN_AURA') return '/home';
    if (threadId.isNotEmpty || spaceId.isNotEmpty) return '/me/invitations';
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

  /// WHO invited — the invitation domain naming its own envelopes, then
  /// handing the payload to the person authority to actually read.
  static AuraPersonIdentity _inviter(Map<String, dynamic> invite) =>
      _personIn(invite, const ['invitedBy', 'inviter', 'createdBy']);

  /// WHO was invited.
  static AuraPersonIdentity _recipient(Map<String, dynamic> invite) => _personIn(
        invite,
        const [
          'recipient',
          'recipientUser',
          'invitedUser',
          'recipientProfile',
          'directRecipient',
        ],
      );

  /// First envelope that actually holds a person, read canonically.
  static AuraPersonIdentity _personIn(
    Map<String, dynamic> invite,
    List<String> envelopes,
  ) {
    for (final key in envelopes) {
      final raw = invite[key];
      if (raw is! Map) continue;
      final person = AuraPersonIdentity.fromJson(
        Map<String, dynamic>.from(raw),
      );
      if (person.isNotEmpty) return person;
    }
    return AuraPersonIdentity.unknown;
  }

  /// A person's name for PROSE — "Ayesha invited you", never "@ayesha invited
  /// you". Empty when nobody resolved, because these strings are composed into
  /// sentences that must omit the clause rather than name a stranger.
  static String _nameOf(AuraPersonIdentity person) =>
      person.isEmpty ? '' : person.proseName;

  /// Generic first-non-empty key read for invitation STATE — destination type,
  /// access policy, status, ids. Never a person: people go through
  /// [_personIn].
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
