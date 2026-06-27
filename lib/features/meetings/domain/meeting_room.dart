enum MeetingRoomStatus {
  startingSoon,
  scheduled,
  waiting,
  hostWaiting,
  guestWaiting,
  live,
  inProgress,
  ended,
  missed,
  cancelled,
  connectionIssue,
  unknown,
}

MeetingRoomStatus meetingRoomStatusFromString(dynamic value) {
  switch ((value ?? '').toString().trim().toUpperCase()) {
    case 'STARTING_SOON':
      return MeetingRoomStatus.startingSoon;
    case 'SCHEDULED':
      return MeetingRoomStatus.scheduled;
    case 'WAITING':
      return MeetingRoomStatus.waiting;
    case 'HOST_WAITING':
      return MeetingRoomStatus.hostWaiting;
    case 'GUEST_WAITING':
      return MeetingRoomStatus.guestWaiting;
    case 'LIVE':
      return MeetingRoomStatus.live;
    case 'IN_PROGRESS':
      return MeetingRoomStatus.inProgress;
    case 'ENDED':
      return MeetingRoomStatus.ended;
    case 'MISSED':
      return MeetingRoomStatus.missed;
    case 'CANCELLED':
      return MeetingRoomStatus.cancelled;
    case 'CONNECTION_ISSUE':
      return MeetingRoomStatus.connectionIssue;
    default:
      return MeetingRoomStatus.unknown;
  }
}

class MeetingRoom {
  final MeetingRoomStatus status;
  final String? meetingId;
  final String? roomId;
  final String? displayStatus;
  final String? primaryAction;
  final DateTime? scheduledStartAt;
  final DateTime? scheduledEndAt;
  final DateTime? actualStartedAt;
  final DateTime? actualEndedAt;
  final DateTime? hostJoinedAt;
  final int guestWaitingCount;
  final int hostCount;
  final int guestCount;
  final String? realtimeSessionId;
  final String? realtimeSessionStatus;
  final int activeParticipantCount;
  final bool canEnter;
  final bool canStart;
  final bool canEnd;
  final bool canRetryTransport;
  final bool isPastScheduledEnd;

  const MeetingRoom({
    required this.status,
    this.meetingId,
    this.roomId,
    this.displayStatus,
    this.primaryAction,
    this.scheduledStartAt,
    this.scheduledEndAt,
    this.actualStartedAt,
    this.actualEndedAt,
    this.hostJoinedAt,
    required this.guestWaitingCount,
    required this.hostCount,
    required this.guestCount,
    this.realtimeSessionId,
    this.realtimeSessionStatus,
    required this.activeParticipantCount,
    required this.canEnter,
    required this.canStart,
    required this.canEnd,
    required this.canRetryTransport,
    required this.isPastScheduledEnd,
  });

  factory MeetingRoom.fromJson(Map<String, dynamic> json) {
    return MeetingRoom(
      status: meetingRoomStatusFromString(json['status']),
      meetingId: _readString(json['meetingId']),
      roomId: _readString(json['roomId']),
      displayStatus: _readString(json['displayStatus']),
      primaryAction: _readString(json['primaryAction']),
      scheduledStartAt: _readDate(json['scheduledStartAt']),
      scheduledEndAt: _readDate(json['scheduledEndAt']),
      actualStartedAt: _readDate(json['actualStartedAt']),
      actualEndedAt: _readDate(json['actualEndedAt']),
      hostJoinedAt: _readDate(json['hostJoinedAt']),
      guestWaitingCount: (json['guestWaitingCount'] as num?)?.toInt() ?? 0,
      hostCount: _readSummaryInt(json['participantSummary'], 'hostCount'),
      guestCount: _readSummaryInt(json['participantSummary'], 'guestCount'),
      realtimeSessionId: _readString(json['realtimeSessionId']),
      realtimeSessionStatus: _readString(json['realtimeSessionStatus']),
      activeParticipantCount:
          (json['activeParticipantCount'] as num?)?.toInt() ?? 0,
      canEnter: json['canEnter'] as bool? ?? false,
      canStart: json['canStart'] as bool? ?? false,
      canEnd: json['canEnd'] as bool? ?? false,
      canRetryTransport: json['canRetryTransport'] as bool? ?? false,
      isPastScheduledEnd: json['isPastScheduledEnd'] as bool? ?? false,
    );
  }

  bool get isTerminal =>
      status == MeetingRoomStatus.ended ||
      status == MeetingRoomStatus.cancelled ||
      status == MeetingRoomStatus.missed;

  bool get hasTransport => (realtimeSessionId ?? '').trim().isNotEmpty;
}

DateTime? _readDate(dynamic value) {
  final text = value?.toString().trim() ?? '';
  if (text.isEmpty) return null;
  return DateTime.tryParse(text);
}

int _readSummaryInt(dynamic value, String key) {
  if (value is Map) {
    return (value[key] as num?)?.toInt() ?? 0;
  }
  return 0;
}

String? _readString(dynamic value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}
