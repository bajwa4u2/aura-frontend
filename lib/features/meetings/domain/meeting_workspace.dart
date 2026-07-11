import 'meeting.dart';
import 'meeting_identity.dart';

class MeetingWorkspace {
  final String scopeType;
  final String? institutionId;
  final DateTime generatedAt;
  final List<MeetingWorkspaceItem> needsAttention;
  final List<MeetingWorkspaceItem> todayAndNext;
  final List<MeetingWorkspaceItem> invitations;
  final MeetingWorkspaceBooking booking;
  final List<MeetingOutcome> followUp;
  final List<MeetingWorkspaceItem> past;

  const MeetingWorkspace({
    required this.scopeType,
    this.institutionId,
    required this.generatedAt,
    required this.needsAttention,
    required this.todayAndNext,
    required this.invitations,
    required this.booking,
    required this.followUp,
    required this.past,
  });

  factory MeetingWorkspace.fromJson(Map<String, dynamic> json) {
    final scope = _asMap(json['scope']);
    return MeetingWorkspace(
      scopeType: scope['type'] as String? ?? 'PERSONAL',
      institutionId: scope['institutionId'] as String?,
      generatedAt:
          DateTime.tryParse(json['generatedAt'] as String? ?? '') ??
          DateTime.now(),
      needsAttention: _items(json['needsAttention']),
      todayAndNext: _items(json['todayAndNext']),
      invitations: _items(json['invitations']),
      booking: MeetingWorkspaceBooking.fromJson(_asMap(json['booking'])),
      followUp: _outcomes(json['followUp']),
      past: _items(json['past']),
    );
  }

  bool get isEmpty =>
      needsAttention.isEmpty &&
      todayAndNext.isEmpty &&
      invitations.isEmpty &&
      booking.profiles.isEmpty &&
      followUp.isEmpty &&
      past.isEmpty;

  static List<MeetingWorkspaceItem> _items(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map<String, dynamic>>()
        .map(MeetingWorkspaceItem.fromJson)
        .toList(growable: false);
  }

  static List<MeetingOutcome> _outcomes(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map<String, dynamic>>()
        .map(MeetingOutcome.fromJson)
        .toList(growable: false);
  }
}

class MeetingWorkspaceItem {
  final Meeting meeting;
  final MeetingWorkspaceRelationship relationship;
  final int pendingGuestCount;
  final bool startsSoon;
  final bool needsFollowUp;

  const MeetingWorkspaceItem({
    required this.meeting,
    required this.relationship,
    required this.pendingGuestCount,
    required this.startsSoon,
    required this.needsFollowUp,
  });

  factory MeetingWorkspaceItem.fromJson(Map<String, dynamic> json) =>
      MeetingWorkspaceItem(
        meeting: Meeting.fromJson(_asMap(json['meeting'])),
        relationship: MeetingWorkspaceRelationship.fromJson(
          _asMap(json['relationship']),
        ),
        pendingGuestCount: (json['pendingGuestCount'] as num?)?.toInt() ?? 0,
        startsSoon: json['startsSoon'] == true,
        needsFollowUp: json['needsFollowUp'] == true,
      );
}

class MeetingWorkspaceRelationship {
  final String kind;
  final String? role;
  final String? participantId;
  final String? rsvpStatus;

  const MeetingWorkspaceRelationship({
    required this.kind,
    this.role,
    this.participantId,
    this.rsvpStatus,
  });

  factory MeetingWorkspaceRelationship.fromJson(Map<String, dynamic> json) =>
      MeetingWorkspaceRelationship(
        kind: json['kind'] as String? ?? 'VISIBLE',
        role: json['role'] as String?,
        participantId: json['participantId'] as String?,
        rsvpStatus: json['rsvpStatus'] as String?,
      );

  String get label => switch (kind) {
    'HOSTING' => 'Hosting',
    'ATTENDING' => 'Attending',
    'INVITED' => 'Invited',
    'BOOKED' => 'Booked',
    'INSTITUTION_WIDE' => 'Institution-wide',
    'EXTERNAL_GUEST' => 'External guest',
    _ => 'Visible',
  };
}

class MeetingWorkspaceBooking {
  final List<MeetingWorkspaceBookingProfile> profiles;
  final int activeCount;
  final int incompleteCount;
  final bool canManage;

  const MeetingWorkspaceBooking({
    required this.profiles,
    required this.activeCount,
    required this.incompleteCount,
    required this.canManage,
  });

  factory MeetingWorkspaceBooking.fromJson(Map<String, dynamic> json) =>
      MeetingWorkspaceBooking(
        profiles: (json['profiles'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(MeetingWorkspaceBookingProfile.fromJson)
            .toList(growable: false),
        activeCount: (json['activeCount'] as num?)?.toInt() ?? 0,
        incompleteCount: (json['incompleteCount'] as num?)?.toInt() ?? 0,
        canManage: json['canManage'] != false,
      );
}

class MeetingWorkspaceBookingProfile {
  final String id;
  final String name;
  final String slug;
  final String meetingTitle;
  final String? meetingDescription;
  final List<int> durationOptions;
  final int defaultDuration;
  final String timezone;
  final bool isActive;
  final bool allowGuests;
  final bool waitingRoomEnabled;
  final bool requireApproval;
  final String publicUrl;
  final String status;
  final int windowsCount;
  final int bookingCount;
  final MeetingIdentityRef? owner;
  final MeetingIdentityRef? assignedHost;
  final MeetingInstitutionRef? institution;

  const MeetingWorkspaceBookingProfile({
    required this.id,
    required this.name,
    required this.slug,
    required this.meetingTitle,
    this.meetingDescription,
    required this.durationOptions,
    required this.defaultDuration,
    required this.timezone,
    required this.isActive,
    required this.allowGuests,
    required this.waitingRoomEnabled,
    required this.requireApproval,
    required this.publicUrl,
    required this.status,
    required this.windowsCount,
    required this.bookingCount,
    this.owner,
    this.assignedHost,
    this.institution,
  });

  factory MeetingWorkspaceBookingProfile.fromJson(Map<String, dynamic> json) =>
      MeetingWorkspaceBookingProfile(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? 'Booking page',
        slug: json['slug'] as String? ?? '',
        meetingTitle: json['meetingTitle'] as String? ?? 'Meeting',
        meetingDescription: json['meetingDescription'] as String?,
        durationOptions: (json['durationOptions'] as List<dynamic>? ?? const [])
            .map((entry) => (entry as num).toInt())
            .toList(growable: false),
        defaultDuration: (json['defaultDuration'] as num?)?.toInt() ?? 30,
        timezone: json['timezone'] as String? ?? 'UTC',
        isActive: json['isActive'] == true,
        allowGuests: json['allowGuests'] != false,
        waitingRoomEnabled: json['waitingRoomEnabled'] == true,
        requireApproval: json['requireApproval'] == true,
        publicUrl: json['publicUrl'] as String? ?? '',
        status: json['status'] as String? ?? 'INCOMPLETE',
        windowsCount: (json['windowsCount'] as num?)?.toInt() ?? 0,
        bookingCount: (json['bookingCount'] as num?)?.toInt() ?? 0,
        owner: json['owner'] is Map<String, dynamic>
            ? MeetingIdentityRef.fromUserJson(
                json['owner'] as Map<String, dynamic>,
              )
            : null,
        assignedHost: json['assignedHost'] is Map<String, dynamic>
            ? MeetingIdentityRef.fromUserJson(
                json['assignedHost'] as Map<String, dynamic>,
              )
            : null,
        institution: json['institution'] is Map<String, dynamic>
            ? MeetingInstitutionRef.fromJson(
                json['institution'] as Map<String, dynamic>,
              )
            : null,
      );

  String get statusLabel => switch (status) {
    'ACTIVE' => 'Active',
    'PAUSED' => 'Paused',
    _ => 'Incomplete',
  };
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const <String, dynamic>{};
}
