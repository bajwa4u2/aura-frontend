import 'meeting_identity.dart';
import 'meeting_asset.dart';
import 'meeting_room.dart';

class MeetingHost {
  final String id;
  final String? displayName;
  final String? handle;
  final String? avatarUrl;
  final String? title;

  const MeetingHost({
    required this.id,
    this.displayName,
    this.handle,
    this.avatarUrl,
    this.title,
  });

  factory MeetingHost.fromJson(Map<String, dynamic> j) => MeetingHost(
    id: j['id'] as String,
    displayName: j['displayName'] as String?,
    handle: j['handle'] as String?,
    avatarUrl: j['avatarUrl'] as String?,
    title: j['title'] as String?,
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
  final DateTime? joinedAt;
  final DateTime? leftAt;
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
    this.joinedAt,
    this.leftAt,
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
        joinedAt: j['joinedAt'] != null
            ? DateTime.tryParse(j['joinedAt'] as String)
            : null,
        leftAt: j['leftAt'] != null
            ? DateTime.tryParse(j['leftAt'] as String)
            : null,
        user: j['user'] != null
            ? MeetingHost.fromJson(j['user'] as Map<String, dynamic>)
            : null,
      );

  String get displayName => user?.name ?? guestName ?? guestEmail ?? 'Guest';

  bool get isHost => role == 'HOST';
  bool get isGuest => role == 'GUEST';

  int? get durationMinutes {
    if (joinedAt == null || leftAt == null) return null;
    return leftAt!.difference(joinedAt!).inMinutes;
  }
}

class MeetingInstitutionRef {
  final String id;
  final String name;
  final String slug;
  final String? description;
  final String? tagline;
  final String? logoUrl;
  final bool isVerified;
  final DateTime? verifiedAt;

  const MeetingInstitutionRef({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    this.tagline,
    this.logoUrl,
    this.isVerified = false,
    this.verifiedAt,
  });

  factory MeetingInstitutionRef.fromJson(Map<String, dynamic> j) =>
      MeetingInstitutionRef(
        id: j['id'] as String? ?? '',
        name: j['name'] as String? ?? 'Institution',
        slug: j['slug'] as String? ?? '',
        description: j['description'] as String?,
        tagline: j['tagline'] as String?,
        logoUrl: j['logoUrl'] as String?,
        isVerified: j['isVerified'] as bool? ?? false,
        verifiedAt: j['verifiedAt'] != null
            ? DateTime.tryParse(j['verifiedAt'] as String)
            : null,
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
  final MeetingIdentityRef? bookerIdentity;
  final MeetingInstitutionRef? institution;
  final MeetingHost? host;

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
    this.bookerIdentity,
    this.institution,
    this.host,
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
        bookerIdentity: j['bookerIdentity'] is Map<String, dynamic>
            ? MeetingIdentityRef.fromJson(
                j['bookerIdentity'] as Map<String, dynamic>,
              )
            : null,
        institution: j['institution'] is Map<String, dynamic>
            ? MeetingInstitutionRef.fromJson(
                j['institution'] as Map<String, dynamic>,
              )
            : null,
        host: j['host'] is Map<String, dynamic>
            ? MeetingHost.fromJson(j['host'] as Map<String, dynamic>)
            : null,
      );
}

class MeetingSummary {
  final String id;
  final String meetingId;
  final String? institutionId;
  final String? summaryText;
  final Map<String, dynamic> attendanceSnapshot;
  final List<String> decisions;
  final List<String> commitments;
  final List<String> actions;
  final List<String> issues;
  final List<String> followUps;
  final String? createdByUserId;
  final String? updatedByUserId;

  /// When the host distributed this summary to participants — a shared
  /// summary is part of every participant's continuity.
  final DateTime? sharedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MeetingSummary({
    required this.id,
    required this.meetingId,
    this.institutionId,
    this.summaryText,
    required this.attendanceSnapshot,
    required this.decisions,
    required this.commitments,
    required this.actions,
    required this.issues,
    required this.followUps,
    this.createdByUserId,
    this.updatedByUserId,
    this.sharedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MeetingSummary.fromJson(Map<String, dynamic> j) => MeetingSummary(
    id: j['id'] as String,
    meetingId: j['meetingId'] as String,
    institutionId: j['institutionId'] as String?,
    summaryText: j['summaryText'] as String?,
    attendanceSnapshot: _asMap(j['attendanceSnapshot']),
    decisions: _asStringList(j['decisions']),
    commitments: _asStringList(j['commitments']),
    actions: _asStringList(j['actions']),
    issues: _asStringList(j['issues']),
    followUps: _asStringList(j['followUps']),
    createdByUserId: j['createdByUserId'] as String?,
    updatedByUserId: j['updatedByUserId'] as String?,
    sharedAt: j['sharedAt'] != null
        ? DateTime.tryParse(j['sharedAt'] as String)
        : null,
    createdAt:
        DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.now(),
    updatedAt:
        DateTime.tryParse(j['updatedAt'] as String? ?? '') ?? DateTime.now(),
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

  /// Owning institution — set when this is an INSTITUTION meeting. Screen
  /// ownership doctrine: institution meetings are owned by the Institution
  /// Workspace end to end, so every host-side surface resolves its context
  /// from this (falling back to the booking's institution for booked ones).
  final String? organizationId;
  final MeetingRoom? room;
  final MeetingHost? host;
  final List<MeetingParticipant> participants;
  final MeetingBookingDetails? booking;
  final String? preparationNotes;
  final String? liveNotes;
  final MeetingSummary? summary;

  /// Guest-visible materials, attached by the public by-code endpoint so the
  /// briefing pack reaches the pre-join surface without authentication.
  final List<MeetingAsset>? assets;

  /// Owning institution's identity (organization-owned meetings) — present
  /// even without a booking so every surface can show WHO owns the meeting.
  final MeetingInstitutionRef? institution;

  /// READY recordings attached to this meeting (inventory projection only —
  /// the recordings themselves stay meeting-owned and load with the record).
  final int recordingCount;
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
    this.organizationId,
    this.room,
    this.host,
    required this.participants,
    this.booking,
    this.preparationNotes,
    this.liveNotes,
    this.summary,
    this.assets,
    this.institution,
    this.recordingCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  /// The identity that owns this meeting's room: institution first (org or
  /// booking), host otherwise.
  MeetingInstitutionRef? get owningInstitution =>
      institution ?? booking?.institution;

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
    organizationId: (j['organizationId'] ?? j['institutionId']) as String?,
    room: j['room'] is Map<String, dynamic>
        ? MeetingRoom.fromJson(j['room'] as Map<String, dynamic>)
        : null,
    host: j['host'] != null
        ? MeetingHost.fromJson(j['host'] as Map<String, dynamic>)
        : null,
    participants: (j['participants'] as List<dynamic>? ?? [])
        .map((p) => MeetingParticipant.fromJson(p as Map<String, dynamic>))
        .toList(),
    booking: j['booking'] is Map<String, dynamic>
        ? MeetingBookingDetails.fromJson(j['booking'] as Map<String, dynamic>)
        : null,
    preparationNotes: j['preparationNotes'] as String?,
    liveNotes: j['liveNotes'] as String?,
    summary: j['summary'] is Map<String, dynamic>
        ? MeetingSummary.fromJson(j['summary'] as Map<String, dynamic>)
        : null,
    assets: j['assets'] is List
        ? (j['assets'] as List)
            .whereType<Map<String, dynamic>>()
            .map(MeetingAsset.fromJson)
            .toList()
        : null,
    institution: j['institution'] is Map<String, dynamic>
        ? MeetingInstitutionRef.fromJson(
            j['institution'] as Map<String, dynamic>)
        : null,
    recordingCount: (j['recordingCount'] as num?)?.toInt() ?? 0,
    createdAt:
        DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.now(),
    updatedAt:
        DateTime.tryParse(j['updatedAt'] as String? ?? '') ?? DateTime.now(),
  );

  /// The institution that owns this meeting's workspace context, if any.
  String? get owningInstitutionId =>
      organizationId ?? booking?.institution?.id;

  bool get isActive => state == 'ACTIVE' && !isEnded;
  bool get isScheduled =>
      state == 'SCHEDULED' &&
      (room == null ||
          room?.status == MeetingRoomStatus.scheduled ||
          room?.status == MeetingRoomStatus.startingSoon ||
          room?.status == MeetingRoomStatus.waiting ||
          room?.status == MeetingRoomStatus.hostWaiting ||
          room?.status == MeetingRoomStatus.guestWaiting);
  bool get isDraft => state == 'DRAFT';
  bool get isEnded =>
      state == 'ENDED' ||
      state == 'CANCELLED' ||
      room?.status == MeetingRoomStatus.ended ||
      room?.status == MeetingRoomStatus.missed ||
      room?.status == MeetingRoomStatus.cancelled;
  bool get isInstant => type == 'INSTANT';

  int get participantCount => participants.length;
}

class JoinMeetingResult {
  final String meetingId;
  final String? sessionId;
  final String action;
  final String? guestSessionId;
  final String meetingCode;
  final String title;

  /// Participation Architecture context (additive; absent on old servers).
  final String? outcome;
  final String? reasonCode;
  final String? admissionState;

  const JoinMeetingResult({
    required this.meetingId,
    this.sessionId,
    required this.action,
    this.guestSessionId,
    required this.meetingCode,
    required this.title,
    this.outcome,
    this.reasonCode,
    this.admissionState,
  });

  factory JoinMeetingResult.fromJson(Map<String, dynamic> j) =>
      JoinMeetingResult(
        meetingId: j['meetingId'] as String,
        sessionId: j['sessionId'] as String?,
        action: j['action'] as String? ?? 'join',
        guestSessionId: j['guestSessionId'] as String?,
        meetingCode: j['meetingCode'] as String? ?? '',
        title: j['title'] as String? ?? '',
        outcome: j['outcome'] as String?,
        reasonCode: j['reasonCode'] as String?,
        admissionState: j['admissionState'] as String?,
      );

  bool get shouldJoinDirectly => action == 'join';
  bool get shouldWait => action == 'wait';

  /// The entrant is parked in the waiting room pending host approval.
  bool get isPendingApproval => admissionState == 'PENDING';
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const <String, dynamic>{};
}

List<String> _asStringList(dynamic value) {
  if (value is List) {
    return value
        .map((entry) => entry?.toString().trim() ?? '')
        .where((entry) => entry.isNotEmpty)
        .toList();
  }
  return const <String>[];
}

enum OutcomeStatus { open, completed, deferred, cancelled }

OutcomeStatus _parseOutcomeStatus(dynamic v) {
  switch ((v as String? ?? '').toUpperCase()) {
    case 'COMPLETED':
      return OutcomeStatus.completed;
    case 'DEFERRED':
      return OutcomeStatus.deferred;
    case 'CANCELLED':
      return OutcomeStatus.cancelled;
    default:
      return OutcomeStatus.open;
  }
}

class MeetingOutcome {
  final String id;
  final String meetingId;
  final String type;
  final String text;
  final OutcomeStatus status;
  final String? ownerId;
  final String? ownerName;
  final DateTime? dueDate;

  /// Canonical meeting reference (projection only): continuity surfaces route
  /// each outcome back into its owning institution's meeting record.
  final String? meetingTitle;
  final String? meetingInstitutionId;
  final DateTime? meetingScheduledAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MeetingOutcome({
    required this.id,
    required this.meetingId,
    required this.type,
    required this.text,
    required this.status,
    this.ownerId,
    this.ownerName,
    this.dueDate,
    this.meetingTitle,
    this.meetingInstitutionId,
    this.meetingScheduledAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MeetingOutcome.fromJson(Map<String, dynamic> j) {
    final owner = j['owner'];
    final ownerMap = owner is Map ? Map<String, dynamic>.from(owner) : null;
    final meeting = j['meeting'];
    final meetingMap =
        meeting is Map ? Map<String, dynamic>.from(meeting) : null;
    return MeetingOutcome(
      id: j['id'] as String,
      meetingId: j['meetingId'] as String,
      type: j['type'] as String? ?? '',
      text: j['text'] as String? ?? '',
      status: _parseOutcomeStatus(j['status']),
      ownerId: ownerMap?['id'] as String?,
      ownerName: ownerMap?['displayName'] as String?,
      dueDate: j['dueDate'] != null
          ? DateTime.tryParse(j['dueDate'] as String)
          : null,
      meetingTitle: meetingMap?['title'] as String?,
      meetingInstitutionId: meetingMap?['organizationId'] as String?,
      meetingScheduledAt: meetingMap?['scheduledAt'] != null
          ? DateTime.tryParse(meetingMap!['scheduledAt'] as String)
          : null,
      createdAt: DateTime.parse(j['createdAt'] as String),
      updatedAt: DateTime.parse(j['updatedAt'] as String),
    );
  }
}
