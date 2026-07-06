/// Phase 4 — Meeting Conversation Stream.
///
/// A meeting-owned conversation message (NOT generic messaging). Every
/// message belongs to one meeting, carries the sender's identity (member or
/// guest) with a denormalized display name, and is continuity-ready: a typed
/// message (decision/commitment/action/issue/follow-up) can later be promoted
/// into a first-class MeetingOutcome.
enum MeetingMessageType {
  chat,
  decision,
  commitment,
  action,
  issue,
  followUp,
  system;

  static MeetingMessageType parse(String? raw) {
    switch ((raw ?? '').trim().toUpperCase()) {
      case 'DECISION':
        return MeetingMessageType.decision;
      case 'COMMITMENT':
        return MeetingMessageType.commitment;
      case 'ACTION':
        return MeetingMessageType.action;
      case 'ISSUE':
        return MeetingMessageType.issue;
      case 'FOLLOW_UP':
        return MeetingMessageType.followUp;
      case 'SYSTEM':
        return MeetingMessageType.system;
      default:
        return MeetingMessageType.chat;
    }
  }

  String get wire {
    switch (this) {
      case MeetingMessageType.chat:
        return 'CHAT';
      case MeetingMessageType.decision:
        return 'DECISION';
      case MeetingMessageType.commitment:
        return 'COMMITMENT';
      case MeetingMessageType.action:
        return 'ACTION';
      case MeetingMessageType.issue:
        return 'ISSUE';
      case MeetingMessageType.followUp:
        return 'FOLLOW_UP';
      case MeetingMessageType.system:
        return 'SYSTEM';
    }
  }

  /// Composer/tile label. CHAT has no badge.
  String get label {
    switch (this) {
      case MeetingMessageType.chat:
        return 'Chat';
      case MeetingMessageType.decision:
        return 'Decision';
      case MeetingMessageType.commitment:
        return 'Commitment';
      case MeetingMessageType.action:
        return 'Action';
      case MeetingMessageType.issue:
        return 'Issue';
      case MeetingMessageType.followUp:
        return 'Follow-up';
      case MeetingMessageType.system:
        return 'System';
    }
  }
}

class MeetingConversationMessage {
  final String id;
  final String meetingId;
  final String senderId;
  final String senderName;
  final bool isGuest;
  final MeetingMessageType messageType;
  final String body;
  final DateTime createdAt;
  final String? promotedOutcomeId;

  const MeetingConversationMessage({
    required this.id,
    required this.meetingId,
    required this.senderId,
    required this.senderName,
    required this.isGuest,
    required this.messageType,
    required this.body,
    required this.createdAt,
    this.promotedOutcomeId,
  });

  factory MeetingConversationMessage.fromJson(Map<String, dynamic> j) {
    final promoted = (j['promotedOutcomeId'] ?? '').toString().trim();
    return MeetingConversationMessage(
      id: (j['id'] ?? '').toString(),
      meetingId: (j['meetingId'] ?? '').toString(),
      senderId: (j['senderId'] ?? '').toString(),
      senderName: (j['senderName'] ?? '').toString(),
      isGuest: j['isGuest'] == true,
      messageType: MeetingMessageType.parse(j['messageType']?.toString()),
      body: (j['body'] ?? '').toString(),
      createdAt:
          DateTime.tryParse((j['createdAt'] ?? '').toString())?.toLocal() ??
              DateTime.now(),
      promotedOutcomeId: promoted.isEmpty ? null : promoted,
    );
  }
}
