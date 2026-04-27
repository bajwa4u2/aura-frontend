class CorrespondenceIdentity {
  const CorrespondenceIdentity._();

  static const Set<String> _genericThreadTitles = {
    'conversation',
    'direct conversation',
    'group conversation',
    'private conversation',
    'shared space',
    'thread',
    'message',
    'messages',
    'chat',
    'general',
    'untitled',
    'untitled conversation',
    'untitled thread',
  };

  static String pickString(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  static String pickNested(Map<String, dynamic> map, List<List<String>> paths) {
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

  static String humanize(String value) {
    final text = value.trim();
    if (text.isEmpty) return '';
    return text
        .replaceAll('_', ' ')
        .split(RegExp(r'\s+'))
        .map((word) => word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}')
        .join(' ');
  }

  static String truncate(String value, {int max = 42}) {
    final text = value.trim();
    if (text.length <= max) return text;
    return '${text.substring(0, max - 1).trim()}…';
  }

  static List<Map<String, dynamic>> extractParticipants(Map<String, dynamic> source) {
    const keys = ['participants', 'members', 'participantList', 'memberList', 'users'];
    final out = <Map<String, dynamic>>[];
    for (final key in keys) {
      final value = source[key];
      if (value is! List) continue;
      for (final raw in value) {
        if (raw is Map<String, dynamic>) {
          out.add(raw);
        } else if (raw is Map) {
          out.add(Map<String, dynamic>.from(raw));
        }
      }
    }
    return out;
  }

  static String identityLabel(Map<String, dynamic> entity) {
    final display = pickString(entity, const ['displayName', 'fullName', 'name']);
    if (display.isNotEmpty) return display;
    final handle = pickString(entity, const ['handle', 'username']);
    if (handle.isNotEmpty) {
      final clean = handle.startsWith('@') ? handle.substring(1) : handle;
      return '@$clean';
    }
    final id = pickString(entity, const ['id', '_id', 'userId', 'memberId']);
    if (id.isNotEmpty) return 'Member ${truncate(id, max: 12)}';
    return '';
  }

  static String identityHandle(Map<String, dynamic> entity) {
    final handle = pickString(entity, const ['handle', 'username']);
    if (handle.isEmpty) return '';
    return handle.startsWith('@') ? handle : '@$handle';
  }

  static String identityLine(Map<String, dynamic> entity, {bool preferHandle = true}) {
    final label = identityLabel(entity);
    final handle = identityHandle(entity);
    if (preferHandle && handle.isNotEmpty && label != handle) return '$label · $handle';
    return label;
  }

  static String identityAvatarUrl(Map<String, dynamic> entity) {
    return pickString(entity, const ['avatarUrl', 'imageUrl', 'photoUrl']);
  }

  static String memberDisplayName(Map<String, dynamic> member) {
    final value = pickString(member, const ['displayName', 'fullName', 'name', 'username', 'handle']);
    return value.isEmpty ? 'Member' : value;
  }

  static String memberSubtitle(Map<String, dynamic> member) {
    final parts = <String>[
      pickString(member, const ['headline', 'bio', 'summary']),
      pickString(member, const ['email']),
    ].where((e) => e.isNotEmpty).toList(growable: false);
    return parts.isEmpty ? '' : parts.first;
  }

  static String threadPreview(Map<String, dynamic> thread) {
    final preview = pickString(thread, const ['lastMessage', 'lastMessageText', 'preview', 'description', 'summary']);
    return preview.isNotEmpty ? truncate(preview, max: 120) : '';
  }

  static String threadTitle(Map<String, dynamic> thread) {
    return resolveThreadContext(thread).title;
  }

  static CorrespondenceThreadContext resolveThreadContext(
    Map<String, dynamic> thread, {
    String? currentUserId,
  }) {
    final participants = extractParticipants(thread);
    final dedupedParticipants = _dedupeParticipants(participants);
    final explicit = pickString(thread, const ['title', 'name']);
    final preview = threadPreview(thread);
    final spaceTitle = pickNested(thread, const [
      ['space', 'title'],
      ['space', 'name'],
    ]);
    final spaceId = pickString(thread, const ['spaceId', 'space_id']);
    final kindValue = pickString(thread, const [
      'kind',
      'type',
      'threadType',
      'conversationType',
    ]).toUpperCase();

    final kind = _resolveThreadKind(
      kindValue: kindValue,
      participantCount: dedupedParticipants.length,
      spaceTitle: spaceTitle,
      spaceId: spaceId,
    );

    final participantLabels = _threadParticipantLabels(
      dedupedParticipants,
      currentUserId: currentUserId,
    );
    final participantSummary =
        threadParticipantSummaryFromParticipants(dedupedParticipants);
    final roleSummary = threadParticipantRoleSummary({
      'participants': dedupedParticipants,
    });
    final activityWeight = threadRecentWeight(thread);
    final threadLabel = _threadDisplayTitle(
      thread,
      kind: kind,
      explicitTitle: explicit,
      preview: preview,
      spaceTitle: spaceTitle,
      participants: dedupedParticipants,
      participantLabels: participantLabels,
      participantSummary: participantSummary,
      currentUserId: currentUserId,
    );
    final subtitle = _threadDisplaySubtitle(
      kind: kind,
      spaceTitle: spaceTitle,
      explicitTitle: explicit,
      participantSummary: participantSummary,
      roleSummary: roleSummary,
      activityWeight: activityWeight,
      preview: preview,
    );
    final avatarUrl = _threadDisplayAvatarUrl(
      thread,
      participants: dedupedParticipants,
      currentUserId: currentUserId,
    );

    return CorrespondenceThreadContext(
      kind: kind,
      title: threadLabel,
      subtitle: subtitle,
      participantSummary: participantSummary,
      roleSummary: roleSummary,
      activityWeight: activityWeight,
      kindLabel: _threadKindLabel(kind),
      participantChips: participantLabels,
      avatarUrl: avatarUrl,
      spaceTitle: spaceTitle,
      explicitTitle: explicit,
      hasSpace: spaceId.isNotEmpty || spaceTitle.isNotEmpty,
    );
  }

  static String threadDisplayTitle(
    Map<String, dynamic> thread, {
    String? currentUserId,
  }) {
    return resolveThreadContext(thread, currentUserId: currentUserId).title;
  }

  static String threadDisplaySubtitle(
    Map<String, dynamic> thread, {
    String? currentUserId,
  }) {
    return resolveThreadContext(thread, currentUserId: currentUserId).subtitle;
  }

  static List<String> threadIdentityChips(
    Map<String, dynamic> thread, {
    String? currentUserId,
  }) {
    return resolveThreadContext(thread, currentUserId: currentUserId)
        .participantChips;
  }

  static String threadConversationKindLabel(Map<String, dynamic> thread) {
    return _threadKindLabel(
      _resolveThreadKind(
        kindValue: pickString(thread, const [
          'kind',
          'type',
          'threadType',
          'conversationType',
        ]).toUpperCase(),
        participantCount: extractParticipants(thread).length,
        spaceTitle: pickNested(thread, const [
          ['space', 'title'],
          ['space', 'name'],
        ]),
        spaceId: pickString(thread, const ['spaceId', 'space_id']),
      ),
    );
  }

  static String threadDisplayAvatarUrl(
    Map<String, dynamic> thread, {
    String? currentUserId,
  }) {
    return resolveThreadContext(thread, currentUserId: currentUserId).avatarUrl;
  }

  static bool isGenericThreadLabel(String value) {
    final normalized = value.trim().toLowerCase();
    return normalized.isEmpty || _genericThreadTitles.contains(normalized);
  }

  static String _threadDisplayTitle(
    Map<String, dynamic> thread, {
    required CorrespondenceThreadKind kind,
    required String explicitTitle,
    required String preview,
    required String spaceTitle,
    required List<Map<String, dynamic>> participants,
    required List<String> participantLabels,
    required String participantSummary,
    String? currentUserId,
  }) {
    final explicitIsGeneric = isGenericThreadLabel(explicitTitle);

    switch (kind) {
      case CorrespondenceThreadKind.direct:
        final directLabel = _directThreadTitle(
          participants: participants,
          participantLabels: participantLabels,
          participantSummary: participantSummary,
          currentUserId: currentUserId,
        );
        if (directLabel.isNotEmpty) return directLabel;
        if (!explicitIsGeneric && explicitTitle.isNotEmpty) {
          return explicitTitle;
        }
        return 'Private conversation';
      case CorrespondenceThreadKind.group:
        if (!explicitIsGeneric && explicitTitle.isNotEmpty) return explicitTitle;
        if (participantSummary.isNotEmpty) return participantSummary;
        if (preview.isNotEmpty) return truncate(preview, max: 42);
        return 'Group conversation';
      case CorrespondenceThreadKind.space:
        if (spaceTitle.isNotEmpty) {
          if (!explicitIsGeneric && explicitTitle.isNotEmpty) {
            if (explicitTitle.toLowerCase() != spaceTitle.toLowerCase()) {
              return '$spaceTitle · $explicitTitle';
            }
            return explicitTitle;
          }
          return '$spaceTitle · General';
        }
        if (!explicitIsGeneric && explicitTitle.isNotEmpty) return explicitTitle;
        if (participantSummary.isNotEmpty) return participantSummary;
        if (preview.isNotEmpty) return truncate(preview, max: 42);
        return 'Shared space';
      case CorrespondenceThreadKind.unknown:
        if (!explicitIsGeneric && explicitTitle.isNotEmpty) return explicitTitle;
        if (participantSummary.isNotEmpty) return participantSummary;
        if (spaceTitle.isNotEmpty) return '$spaceTitle conversation';
        if (preview.isNotEmpty) return truncate(preview, max: 42);
        return 'Conversation';
    }
  }

  static String _threadDisplaySubtitle({
    required CorrespondenceThreadKind kind,
    required String spaceTitle,
    required String explicitTitle,
    required String participantSummary,
    required String roleSummary,
    required String activityWeight,
    required String preview,
  }) {
    final nonGenericExplicit = !isGenericThreadLabel(explicitTitle) &&
        explicitTitle.trim().isNotEmpty;

    switch (kind) {
      case CorrespondenceThreadKind.direct:
        if (roleSummary.isNotEmpty) return roleSummary;
        if (participantSummary.isNotEmpty) return participantSummary;
        return 'Private conversation';
      case CorrespondenceThreadKind.group:
        if (roleSummary.isNotEmpty) return roleSummary;
        if (participantSummary.isNotEmpty) return participantSummary;
        if (activityWeight.isNotEmpty) return activityWeight;
        return 'Group conversation';
      case CorrespondenceThreadKind.space:
        if (spaceTitle.isNotEmpty && nonGenericExplicit) {
          return '$spaceTitle · $explicitTitle';
        }
        if (participantSummary.isNotEmpty) return participantSummary;
        if (activityWeight.isNotEmpty) return activityWeight;
        return spaceTitle.isNotEmpty ? 'Shared space' : 'Shared conversation';
      case CorrespondenceThreadKind.unknown:
        if (participantSummary.isNotEmpty) return participantSummary;
        if (activityWeight.isNotEmpty) return activityWeight;
        if (preview.isNotEmpty) return truncate(preview, max: 72);
        return 'Conversation';
    }
  }

  static String _threadDisplayAvatarUrl(
    Map<String, dynamic> thread, {
    required List<Map<String, dynamic>> participants,
    String? currentUserId,
  }) {
    final explicit = pickString(thread, const ['avatarUrl', 'imageUrl', 'photoUrl']);
    if (explicit.isNotEmpty) return explicit;

    final spaceAvatar = pickNested(thread, const [
      ['space', 'avatarUrl'],
      ['space', 'imageUrl'],
      ['space', 'photoUrl'],
    ]);
    if (spaceAvatar.isNotEmpty) return spaceAvatar;

    final directAvatar = _directParticipantAvatar(
      participants,
      currentUserId: currentUserId,
    );
    if (directAvatar.isNotEmpty) return directAvatar;

    return threadAvatarUrl(thread);
  }

  static String _directThreadTitle({
    required List<Map<String, dynamic>> participants,
    required List<String> participantLabels,
    required String participantSummary,
    String? currentUserId,
  }) {
    final others = _otherParticipantLabels(
      participants,
      currentUserId: currentUserId,
    );
    if (others.isNotEmpty) {
      if (others.length == 1) return others.first;
      if (others.length == 2) return '${others.first} and ${others.last}';
      return '${others.first}, ${others[1]} +${others.length - 2}';
    }

    if (participantLabels.length == 1) return participantLabels.first;
    if (participantSummary.isNotEmpty) return participantSummary;
    return '';
  }

  static List<String> _threadParticipantLabels(
    List<Map<String, dynamic>> participants, {
    String? currentUserId,
  }) {
    final labels = <String>[];
    for (final participant in participants) {
      final label = identityLabel(participant);
      if (label.isEmpty) continue;
      final id = pickString(participant, const ['id', '_id', 'userId', 'memberId']);
      if ((currentUserId ?? '').trim().isNotEmpty &&
          id.trim().isNotEmpty &&
          id.trim() == currentUserId!.trim()) {
        continue;
      }
      if (!labels.contains(label)) {
        labels.add(label);
      }
      if (labels.length >= 3) break;
    }
    if (labels.isEmpty) {
      for (final participant in participants) {
        final label = identityLine(participant, preferHandle: true);
        if (label.isEmpty || labels.contains(label)) continue;
        labels.add(label);
        if (labels.length >= 3) break;
      }
    }
    return labels;
  }

  static List<Map<String, dynamic>> _dedupeParticipants(
    List<Map<String, dynamic>> participants,
  ) {
    final out = <Map<String, dynamic>>[];
    final seen = <String>{};
    for (final participant in participants) {
      final id = pickString(participant, const ['id', '_id', 'userId', 'memberId']);
      final key = id.isNotEmpty
          ? id
          : identityLine(participant, preferHandle: false);
      if (key.isEmpty || seen.contains(key)) continue;
      seen.add(key);
      out.add(participant);
    }
    return out;
  }

  static List<String> _otherParticipantLabels(
    List<Map<String, dynamic>> participants, {
    String? currentUserId,
  }) {
    final me = (currentUserId ?? '').trim();
    final out = <String>[];
    for (final participant in participants) {
      final id = pickString(participant, const ['id', '_id', 'userId', 'memberId']);
      if (me.isNotEmpty && id.trim().isNotEmpty && id.trim() == me) {
        continue;
      }
      final label = identityLabel(participant);
      if (label.isNotEmpty && !out.contains(label)) {
        out.add(label);
      }
    }
    return out;
  }

  static String _directParticipantAvatar(
    List<Map<String, dynamic>> participants, {
    String? currentUserId,
  }) {
    final me = (currentUserId ?? '').trim();
    for (final participant in participants) {
      final id = pickString(participant, const ['id', '_id', 'userId', 'memberId']);
      if (me.isNotEmpty && id.trim().isNotEmpty && id.trim() == me) {
        continue;
      }
      final avatar = identityAvatarUrl(participant);
      if (avatar.isNotEmpty) return avatar;
    }
    return '';
  }

  static CorrespondenceThreadKind _resolveThreadKind({
    required String kindValue,
    required int participantCount,
    required String spaceTitle,
    required String spaceId,
  }) {
    const directKinds = {
      'DIRECT',
      'PRIVATE',
      'DM',
      'ONE_TO_ONE',
      '1:1',
      'ONEONONE',
    };
    const groupKinds = {
      'GROUP',
      'GROUP_CHAT',
      'CHANNEL',
      'ROOM',
    };
    const spaceKinds = {
      'MAIN',
      'SPACE',
      'THREAD',
      'TOPIC',
      'GENERAL',
    };

    if (directKinds.contains(kindValue)) {
      return CorrespondenceThreadKind.direct;
    }
    if (groupKinds.contains(kindValue) || participantCount >= 3) {
      return CorrespondenceThreadKind.group;
    }
    if (spaceKinds.contains(kindValue) ||
        spaceTitle.trim().isNotEmpty ||
        spaceId.trim().isNotEmpty) {
      return CorrespondenceThreadKind.space;
    }
    return CorrespondenceThreadKind.unknown;
  }

  static String _threadKindLabel(CorrespondenceThreadKind kind) {
    switch (kind) {
      case CorrespondenceThreadKind.direct:
        return 'Private conversation';
      case CorrespondenceThreadKind.group:
        return 'Group conversation';
      case CorrespondenceThreadKind.space:
        return 'Shared space';
      case CorrespondenceThreadKind.unknown:
        return 'Conversation';
    }
  }
  static String threadParticipantSummaryFromParticipants(
    List<Map<String, dynamic>> participants,
  ) {
    final labels = participants.map((p) => identityLine(p, preferHandle: false)).where((e) => e.isNotEmpty).toList(growable: false);
    if (labels.isEmpty) return '';
    if (labels.length <= 3) return labels.join(' · ');
    return '${labels.take(3).join(' · ')} +${labels.length - 3}';
  }

  static String threadParticipantSummary(Map<String, dynamic> thread) {
    return threadParticipantSummaryFromParticipants(extractParticipants(thread));
  }

  static String threadParticipantRoleSummary(Map<String, dynamic> thread) {
    final participants = extractParticipants(thread);
    final roles = <String>[];
    for (final participant in participants) {
      final role = pickString(participant, const ['role', 'memberRole', 'spaceRole']);
      if (role.isEmpty) continue;
      final label = identityLabel(participant);
      final entry = label.isNotEmpty ? '$label ${humanize(role).toLowerCase()}' : humanize(role);
      if (!roles.contains(entry)) roles.add(entry);
    }
    if (roles.isEmpty) return '';
    return roles.take(2).join(' · ');
  }

  static String threadRecentWeight(Map<String, dynamic> thread) {
    final updatedAt = pickString(thread, const ['updatedAt', 'lastMessageAt', 'lastActivityAt']);
    if (updatedAt.isEmpty) return '';
    final parsed = DateTime.tryParse(updatedAt);
    if (parsed == null) return '';
    final diff = DateTime.now().difference(parsed.toLocal());
    if (diff.inMinutes < 2) return 'Active now';
    if (diff.inHours < 1) return 'Active this hour';
    if (diff.inDays < 1) return 'Active today';
    if (diff.inDays < 7) return 'Active this week';
    return '';
  }

  static String threadAvatarUrl(Map<String, dynamic> thread) {
    final directAvatar = pickString(thread, const ['avatarUrl', 'imageUrl', 'photoUrl']);
    if (directAvatar.isNotEmpty) return directAvatar;

    final spaceAvatar = pickNested(thread, const [
      ['space', 'avatarUrl'],
      ['space', 'imageUrl'],
      ['space', 'photoUrl'],
    ]);
    if (spaceAvatar.isNotEmpty) return spaceAvatar;

    for (final participant in extractParticipants(thread)) {
      final url = identityAvatarUrl(participant);
      if (url.isNotEmpty) return url;
    }
    return '';
  }

  static String inviteTitle(Map<String, dynamic> invite) {
    final destinationType = pickString(invite, const ['destinationType', 'destination_type']).toUpperCase();
    final threadTitle = pickNested(invite, const [
      ['thread', 'title'],
      ['thread', 'name'],
    ]).isNotEmpty ? pickNested(invite, const [['thread', 'title'], ['thread', 'name']]) : pickString(invite, const ['threadTitle', 'threadName', 'thread_title']);
    final spaceTitle = pickNested(invite, const [
      ['space', 'title'],
      ['space', 'name'],
    ]).isNotEmpty ? pickNested(invite, const [['space', 'title'], ['space', 'name']]) : pickString(invite, const ['spaceTitle', 'spaceName', 'space_title']);
    final inviterName = pickNested(invite, const [
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
        return threadTitle.isNotEmpty ? 'Invitation to $threadTitle' : 'Thread invitation';
      case 'START_1_TO_1':
        return inviterName.isNotEmpty ? '$inviterName invited you to correspond' : 'Direct invitation';
      case 'JOIN_AURA':
        return 'Invitation to Aura';
      default:
        return 'Invitation';
    }
  }

  static String inviteSubtitle(Map<String, dynamic> invite) {
    final message = pickString(invite, const ['message']);
    if (message.isNotEmpty) return message;

    final policy = pickString(invite, const ['accessPolicy', 'access_policy']).replaceAll('_', ' ');
    final recipientName = pickNested(invite, const [
      ['recipient', 'displayName'],
      ['recipientUser', 'displayName'],
      ['invitedUser', 'displayName'],
      ['recipientProfile', 'displayName'],
      ['directRecipient', 'displayName'],
    ]);
    final recipientHandle = pickString(invite, const ['recipientHandle', 'recipient_handle']);
    final inviterName = pickNested(invite, const [
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

  static String inviteStateLabel(Map<String, dynamic> invite) {
    final status = pickString(invite, const ['status']);
    return status.isEmpty ? 'Pending' : humanize(status);
  }

  static bool inviteIsActive(Map<String, dynamic> invite) {
    final status = pickString(invite, const ['status']).toUpperCase();
    return status.isEmpty || status == 'PENDING' || status == 'SENT' || status == 'CREATED' || status == 'OPEN' || status == 'OPENED';
  }

  static String inviteAvatarUrl(Map<String, dynamic> invite) {
    return pickNested(invite, const [
      ['recipient', 'avatarUrl'],
      ['recipientUser', 'avatarUrl'],
      ['invitedUser', 'avatarUrl'],
      ['recipientProfile', 'avatarUrl'],
      ['directRecipient', 'avatarUrl'],
      ['inviter', 'avatarUrl'],
    ]);
  }

  static String inviteDestinationRoute(Map<String, dynamic> invite) {
    final threadId = pickString(invite, const ['threadId', 'thread_id']);
    final spaceId = pickString(invite, const ['spaceId', 'space_id']);
    final destinationType = pickString(invite, const ['destinationType', 'destination_type']).toUpperCase();

    if (threadId.isNotEmpty && spaceId.isNotEmpty) {
      return '/me/correspondence/$spaceId/thread/$threadId';
    }
    if (spaceId.isNotEmpty) {
      return '/me/correspondence/$spaceId';
    }
    if (destinationType == 'JOIN_AURA') return '/home';
    return '/me/invitations';
  }

  static String initials(String value) {
    final parts = value.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList(growable: false);
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}

enum CorrespondenceThreadKind { direct, group, space, unknown }

class CorrespondenceThreadContext {
  const CorrespondenceThreadContext({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.participantSummary,
    required this.roleSummary,
    required this.activityWeight,
    required this.kindLabel,
    required this.participantChips,
    required this.avatarUrl,
    required this.spaceTitle,
    required this.explicitTitle,
    required this.hasSpace,
  });

  final CorrespondenceThreadKind kind;
  final String title;
  final String subtitle;
  final String participantSummary;
  final String roleSummary;
  final String activityWeight;
  final String kindLabel;
  final List<String> participantChips;
  final String avatarUrl;
  final String spaceTitle;
  final String explicitTitle;
  final bool hasSpace;

  bool get isDirect => kind == CorrespondenceThreadKind.direct;
  bool get isGroup => kind == CorrespondenceThreadKind.group;
  bool get isSpace => kind == CorrespondenceThreadKind.space;
  bool get isUnknown => kind == CorrespondenceThreadKind.unknown;
}
