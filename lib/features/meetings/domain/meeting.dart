class MeetingHost {
  final String id;
  final String? displayName;
  final String? handle;
  final String? avatarUrl;

  const MeetingHost({
    required this.id,
    this.displayName,
    this.handle,
    this.avatarUrl,
  });

  factory MeetingHost.fromJson(Map<String, dynamic> j) => MeetingHost(
    id: j['id'] as String,
    displayName: j['displayName'] as String?,
    handle: j['handle'] as String?,
    avatarUrl: j['avatarUrl'] as String?,
  );

  String get name => displayName ?? handle ?? 'Unknown';
}

class MeetingParticipant {
  final String id;
  final String meetingId;
  final String? userId;
  final String? guestName;
  final String? guestEmail;
  final String role;
  final String rsvpStatus;
  final bool attended;
  final MeetingHost? user;

  const MeetingParticipant({
    required this.id,
    required this.meetingId,
    this.userId,
    this.guestName,
    this.guestEmail,
    required this.role,
    required this.rsvpStatus,
    required this.attended,
    this.user,
  });

  factory MeetingParticipant.fromJson(Map<String, dynamic> j) =>
      MeetingParticipant(
        id: j['id'] as String,
        meetingId: j['meetingId'] as String,
        userId: j['userId'] as String?,
        guestName: j['guestName'] as String?,
        guestEmail: j['guestEmail'] as String?,
        role: j['role'] as String? ?? 'PARTICIPANT',
        rsvpStatus: j['rsvpStatus'] as String? ?? 'PENDING',
        attended: j['attended'] as bool? ?? false,
        user: j['user'] != null
            ? MeetingHost.fromJson(j['user'] as Map<String, dynamic>)
            : null,
      );

  String get displayName => user?.name ?? guestName ?? guestEmail ?? 'Guest';

  bool get isHost => role == 'HOST';
  bool get isGuest => role == 'GUEST';
}

class MeetingInstitutionRef {
  final String id;
  final String name;
  final String slug;

  const MeetingInstitutionRef({
    required this.id,
    required this.name,
    required this.slug,
  });

  factory MeetingInstitutionRef.fromJson(Map<String, dynamic> j) =>
      MeetingInstitutionRef(
        id: j['id'] as String? ?? '',
        name: j['name'] as String? ?? 'Institution',
        slug: j['slug'] as String? ?? '',
      );
}

class MeetingBookingDetails {
  final String id;
  final String profileId;
  final String bookerName;
  final String bookerEmail;
  final String? bookerNotes;
  final DateTime? scheduledAt;
  final int durationMinutes;
  final String timezone;
  final String status;
  final String? bookingPageName;
  final String? bookingPageSlug;
  final MeetingInstitutionRef? institution;

  const MeetingBookingDetails({
    required this.id,
    required this.profileId,
    required this.bookerName,
    required this.bookerEmail,
    this.bookerNotes,
    this.scheduledAt,
    required this.durationMinutes,
    required this.timezone,
    required this.status,
    this.bookingPageName,
    this.bookingPageSlug,
    this.institution,
  });

  factory MeetingBookingDetails.fromJson(Map<String, dynamic> j) =>
      MeetingBookingDetails(
        id: j['id'] as String? ?? '',
        profileId: j['profileId'] as String? ?? '',
        bookerName: j['bookerName'] as String? ?? 'Guest',
        bookerEmail: j['bookerEmail'] as String? ?? '',
        bookerNotes: j['bookerNotes'] as String?,
        scheduledAt: j['scheduledAt'] != null
            ? DateTime.tryParse(j['scheduledAt'] as String)
            : null,
        durationMinutes: (j['durationMinutes'] as num?)?.toInt() ?? 60,
        timezone: j['timezone'] as String? ?? 'UTC',
        status: j['status'] as String? ?? 'CONFIRMED',
        bookingPageName: j['bookingPageName'] as String?,
        bookingPageSlug: j['bookingPageSlug'] as String?,
        institution: j['institution'] is Map<String, dynamic>
            ? MeetingInstitutionRef.fromJson(
                j['institution'] as Map<String, dynamic>,
              )
            : null,
      );
}

class Meeting {
  final String id;
  final String title;
  final String? description;
  final String type;
  final String state;
  final String meetingCode;
  final String joinUrl;
  final DateTime? scheduledAt;
  final int durationMinutes;
  final String timezone;
  final String visibility;
  final bool waitingRoomEnabled;
  final bool recordingEnabled;
  final bool screenShareEnabled;
  final bool chatEnabled;
  final bool allowGuests;
  final bool guestApprovalRequired;
  final String? sessionId;
  final MeetingHost? host;
  final List<MeetingParticipant> participants;
  final MeetingBookingDetails? booking;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Meeting({
    required this.id,
    required this.title,
    this.description,
    required this.type,
    required this.state,
    required this.meetingCode,
    required this.joinUrl,
    this.scheduledAt,
    required this.durationMinutes,
    required this.timezone,
    required this.visibility,
    required this.waitingRoomEnabled,
    required this.recordingEnabled,
    required this.screenShareEnabled,
    required this.chatEnabled,
    required this.allowGuests,
    required this.guestApprovalRequired,
    this.sessionId,
    this.host,
    required this.participants,
    this.booking,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Meeting.fromJson(Map<String, dynamic> j) => Meeting(
    id: j['id'] as String,
    title: j['title'] as String,
    description: j['description'] as String?,
    type: j['type'] as String? ?? 'SCHEDULED',
    state: j['state'] as String? ?? 'DRAFT',
    meetingCode: j['meetingCode'] as String,
    joinUrl: j['joinUrl'] as String? ?? '',
    scheduledAt: j['scheduledAt'] != null
        ? DateTime.tryParse(j['scheduledAt'] as String)
        : null,
    durationMinutes: (j['durationMinutes'] as num?)?.toInt() ?? 60,
    timezone: j['timezone'] as String? ?? 'UTC',
    visibility: j['visibility'] as String? ?? 'PRIVATE',
    waitingRoomEnabled: j['waitingRoomEnabled'] as bool? ?? true,
    recordingEnabled: j['recordingEnabled'] as bool? ?? false,
    screenShareEnabled: j['screenShareEnabled'] as bool? ?? true,
    chatEnabled: j['chatEnabled'] as bool? ?? true,
    allowGuests: j['allowGuests'] as bool? ?? false,
    guestApprovalRequired: j['guestApprovalRequired'] as bool? ?? true,
    sessionId: j['sessionId'] as String?,
    host: j['host'] != null
        ? MeetingHost.fromJson(j['host'] as Map<String, dynamic>)
        : null,
    participants: (j['participants'] as List<dynamic>? ?? [])
        .map((p) => MeetingParticipant.fromJson(p as Map<String, dynamic>))
        .toList(),
    booking: j['booking'] is Map<String, dynamic>
        ? MeetingBookingDetails.fromJson(j['booking'] as Map<String, dynamic>)
        : null,
    createdAt:
        DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.now(),
    updatedAt:
        DateTime.tryParse(j['updatedAt'] as String? ?? '') ?? DateTime.now(),
  );

  bool get isActive => state == 'ACTIVE';
  bool get isScheduled => state == 'SCHEDULED';
  bool get isDraft => state == 'DRAFT';
  bool get isEnded => state == 'ENDED' || state == 'CANCELLED';
  bool get isInstant => type == 'INSTANT';

  int get participantCount => participants.length;
}

class JoinMeetingResult {
  final String meetingId;
  final String? sessionId;
  final String action;
  final String? guestToken;
  final String meetingCode;
  final String title;

  const JoinMeetingResult({
    required this.meetingId,
    this.sessionId,
    required this.action,
    this.guestToken,
    required this.meetingCode,
    required this.title,
  });

  factory JoinMeetingResult.fromJson(Map<String, dynamic> j) =>
      JoinMeetingResult(
        meetingId: j['meetingId'] as String,
        sessionId: j['sessionId'] as String?,
        action: j['action'] as String? ?? 'join',
        guestToken: j['guestToken'] as String?,
        meetingCode: j['meetingCode'] as String? ?? '',
        title: j['title'] as String? ?? '',
      );

  bool get shouldJoinDirectly => action == 'join';
  bool get shouldWait => action == 'wait';
}
