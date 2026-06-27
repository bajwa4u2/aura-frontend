enum MeetingRoomStatus { scheduled, waiting, live, ended, cancelled, unknown }

MeetingRoomStatus meetingRoomStatusFromString(dynamic value) {
  switch ((value ?? '').toString().trim().toUpperCase()) {
    case 'SCHEDULED':
      return MeetingRoomStatus.scheduled;
    case 'WAITING':
      return MeetingRoomStatus.waiting;
    case 'LIVE':
      return MeetingRoomStatus.live;
    case 'ENDED':
      return MeetingRoomStatus.ended;
    case 'CANCELLED':
      return MeetingRoomStatus.cancelled;
    default:
      return MeetingRoomStatus.unknown;
  }
}

class MeetingRoom {
  final MeetingRoomStatus status;
  final String? realtimeSessionId;
  final String? realtimeSessionStatus;
  final int activeParticipantCount;
  final bool canEnter;
  final bool canStart;
  final bool canEnd;

  const MeetingRoom({
    required this.status,
    this.realtimeSessionId,
    this.realtimeSessionStatus,
    required this.activeParticipantCount,
    required this.canEnter,
    required this.canStart,
    required this.canEnd,
  });

  factory MeetingRoom.fromJson(Map<String, dynamic> json) {
    return MeetingRoom(
      status: meetingRoomStatusFromString(json['status']),
      realtimeSessionId: _readString(json['realtimeSessionId']),
      realtimeSessionStatus: _readString(json['realtimeSessionStatus']),
      activeParticipantCount:
          (json['activeParticipantCount'] as num?)?.toInt() ?? 0,
      canEnter: json['canEnter'] as bool? ?? false,
      canStart: json['canStart'] as bool? ?? false,
      canEnd: json['canEnd'] as bool? ?? false,
    );
  }

  bool get isTerminal =>
      status == MeetingRoomStatus.ended ||
      status == MeetingRoomStatus.cancelled;

  bool get hasTransport => (realtimeSessionId ?? '').trim().isNotEmpty;
}

String? _readString(dynamic value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}
