import 'package:flutter/material.dart';

class CorrespondenceIdentity {
  const CorrespondenceIdentity._();

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
    final explicit = pickString(thread, const ['title', 'name']);
    if (explicit.isNotEmpty) return explicit;

    final participants = extractParticipants(thread);
    final names = participants.map(identityLabel).where((e) => e.isNotEmpty).toList(growable: false);
    final preview = threadPreview(thread);
    final spaceTitle = pickNested(thread, const [
      ['space', 'title'],
      ['space', 'name'],
    ]);

    if (names.isNotEmpty) {
      if (names.length == 1) return names.first;
      if (names.length == 2) return '${names.first} and ${names.last}';
      final base = '${names.first}, ${names[1]} +${names.length - 2}';
      if (spaceTitle.isNotEmpty) return '$base · $spaceTitle';
      return base;
    }

    if (preview.isNotEmpty) {
      if (spaceTitle.isNotEmpty) return '$spaceTitle · ${truncate(preview, max: 28)}';
      return truncate(preview, max: 42);
    }

    if (spaceTitle.isNotEmpty) return '$spaceTitle conversation';
    return 'Conversation';
  }

  static String threadParticipantSummaryFromParticipants(List<Map<String, dynamic>> participants) {
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
    for (final participant in extractParticipants(thread)) {
      final url = identityAvatarUrl(participant);
      if (url.isNotEmpty) return url;
    }
    return '';
  }

  static String inviteTitle(Map<String, dynamic> invite) {
    final destinationType = pickString(invite, const ['destinationType', 'destination_type']).toUpperCase();
    final deeplink = pickString(invite, const ['deeplink', 'targetUrl', 'target_url']);
    final sessionId = pickNested(invite, const [
      ['session', 'id'],
      ['realtimeSession', 'id'],
      ['destination', 'sessionId'],
      ['data', 'sessionId'],
    ]).isNotEmpty
        ? pickNested(invite, const [
            ['session', 'id'],
            ['realtimeSession', 'id'],
            ['destination', 'sessionId'],
            ['data', 'sessionId'],
          ])
        : pickString(invite, const ['sessionId', 'realtimeSessionId', 'realtime_session_id']);
    final threadTitle = pickNested(invite, const [
      ['thread', 'title'],
      ['thread', 'name'],
    ]).isNotEmpty ? pickNested(invite, const [['thread', 'title'], ['thread', 'name']]) : pickString(invite, const ['threadTitle', 'threadName', 'thread_title']);
    final spaceTitle = pickNested(invite, const [
      ['space', 'title'],
      ['space', 'name'],
    ]).isNotEmpty ? pickNested(invite, const [['space', 'title'], ['space', 'name']]) : pickString(invite, const ['spaceTitle', 'spaceName', 'space_title']);
    final roomTitle = pickNested(invite, const [
      ['session', 'title'],
      ['realtimeSession', 'title'],
      ['data', 'roomTitle'],
    ]).isNotEmpty
        ? pickNested(invite, const [
            ['session', 'title'],
            ['realtimeSession', 'title'],
            ['data', 'roomTitle'],
          ])
        : pickString(invite, const ['roomTitle', 'sessionTitle', 'title', 'name']);
    final inviterName = pickNested(invite, const [
      ['invitedBy', 'displayName'],
      ['inviter', 'displayName'],
      ['invitedBy', 'handle'],
      ['inviter', 'handle'],
    ]);

    final pointsToRealtime = deeplink.startsWith('/realtime') || sessionId.isNotEmpty || destinationType == 'REALTIME_INVITE';
    if (pointsToRealtime) {
      if (roomTitle.isNotEmpty) return 'Invitation to $roomTitle';
      return inviterName.isNotEmpty ? '$inviterName invited you to a live room' : 'Live room invitation';
    }

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
    final deeplink = pickString(invite, const ['deeplink', 'targetUrl', 'target_url']);
    if (deeplink.isNotEmpty) {
      return deeplink;
    }

    final sessionId = pickNested(invite, const [
      ['session', 'id'],
      ['realtimeSession', 'id'],
      ['destination', 'sessionId'],
      ['data', 'sessionId'],
    ]).isNotEmpty
        ? pickNested(invite, const [
            ['session', 'id'],
            ['realtimeSession', 'id'],
            ['destination', 'sessionId'],
            ['data', 'sessionId'],
          ])
        : pickString(invite, const ['sessionId', 'realtimeSessionId', 'realtime_session_id']);

    if (sessionId.isNotEmpty) {
      return '/realtime/$sessionId?action=join';
    }

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
