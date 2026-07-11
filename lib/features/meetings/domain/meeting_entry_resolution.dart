/// Participation Architecture — the backend resolver's entry outcome.
///
/// Doctrine: policy never lives in the UI. The frontend calls the canonical
/// resolver (`GET /public/meetings/entry/:code`) before rendering any entry
/// experience, then renders EXACTLY the state the backend returned. Flutter
/// never decides eligibility, participation, admission, waiting, or denial.
enum MeetingEntryOutcome {
  hostDirect,
  participantDirect,
  bookerDirect,
  invitedDirect,
  institutionMemberDirect,
  /// Retired by the identity-integrity doctrine — a current backend never
  /// produces it. Parsed for compatibility and rendered as a closed door.
  guestIdentityRequired,

  /// External invitee must verify the invited email (invitation-bound OTP).
  invitationVerificationRequired,
  guestDirect,
  waitingForAdmission,
  requestAccess,
  loginRequired,
  identityConflict,
  forbidden,
  meetingUnavailable;

  static MeetingEntryOutcome parse(String? raw) {
    switch (raw) {
      case 'HOST_DIRECT':
        return MeetingEntryOutcome.hostDirect;
      case 'PARTICIPANT_DIRECT':
        return MeetingEntryOutcome.participantDirect;
      case 'BOOKER_DIRECT':
        return MeetingEntryOutcome.bookerDirect;
      case 'INVITED_DIRECT':
        return MeetingEntryOutcome.invitedDirect;
      case 'INSTITUTION_MEMBER_DIRECT':
        return MeetingEntryOutcome.institutionMemberDirect;
      case 'GUEST_IDENTITY_REQUIRED':
        return MeetingEntryOutcome.guestIdentityRequired;
      case 'INVITATION_VERIFICATION_REQUIRED':
        return MeetingEntryOutcome.invitationVerificationRequired;
      case 'GUEST_DIRECT':
        return MeetingEntryOutcome.guestDirect;
      case 'WAITING_FOR_ADMISSION':
        return MeetingEntryOutcome.waitingForAdmission;
      case 'REQUEST_ACCESS':
        return MeetingEntryOutcome.requestAccess;
      case 'LOGIN_REQUIRED':
        return MeetingEntryOutcome.loginRequired;
      case 'IDENTITY_CONFLICT':
        return MeetingEntryOutcome.identityConflict;
      case 'FORBIDDEN':
        return MeetingEntryOutcome.forbidden;
      case 'MEETING_UNAVAILABLE':
      default:
        // An unknown outcome from a newer backend must fail CLOSED — render
        // the unavailable state, never an open door.
        return MeetingEntryOutcome.meetingUnavailable;
    }
  }

  /// A resolved participation the entrant may act on with a single Join tap.
  bool get canJoin =>
      this == hostDirect ||
      this == participantDirect ||
      this == bookerDirect ||
      this == invitedDirect ||
      this == institutionMemberDirect ||
      this == guestDirect;

  /// Terminal states: nothing the entrant does on this screen changes them.
  bool get isTerminal =>
      this == forbidden ||
      this == identityConflict ||
      this == meetingUnavailable;
}

/// The single next action the backend permits.
enum MeetingEntryAction {
  join,
  submitGuestIdentity,
  verifyInvitation,
  login,
  wait,
  requestAccess,
  none;

  static MeetingEntryAction parse(String? raw) {
    switch (raw) {
      case 'JOIN':
        return MeetingEntryAction.join;
      case 'SUBMIT_GUEST_IDENTITY':
        return MeetingEntryAction.submitGuestIdentity;
      case 'VERIFY_INVITATION':
        return MeetingEntryAction.verifyInvitation;
      case 'LOGIN':
        return MeetingEntryAction.login;
      case 'WAIT':
        return MeetingEntryAction.wait;
      case 'REQUEST_ACCESS':
        return MeetingEntryAction.requestAccess;
      default:
        return MeetingEntryAction.none;
    }
  }
}

class MeetingEntryHost {
  final String? displayName;
  final String? avatarUrl;
  final String? title;
  const MeetingEntryHost({this.displayName, this.avatarUrl, this.title});

  factory MeetingEntryHost.fromJson(Map<String, dynamic> j) => MeetingEntryHost(
        displayName: j['displayName'] as String?,
        avatarUrl: j['avatarUrl'] as String?,
        title: j['title'] as String?,
      );
}

class MeetingEntryInstitution {
  final String id;
  final String name;
  final String? logoUrl;
  const MeetingEntryInstitution({
    required this.id,
    required this.name,
    this.logoUrl,
  });

  factory MeetingEntryInstitution.fromJson(Map<String, dynamic> j) =>
      MeetingEntryInstitution(
        id: j['id'] as String? ?? '',
        name: j['name'] as String? ?? '',
        logoUrl: j['logoUrl'] as String?,
      );
}

/// Safe presentation data for the pre-join surface.
class MeetingEntryPresentation {
  final String meetingId;
  final String meetingCode;
  final String title;
  final String? description;
  final String state;
  final DateTime? scheduledAt;
  final int durationMinutes;
  final String timezone;
  final MeetingEntryHost? host;
  final MeetingEntryInstitution? institution;

  const MeetingEntryPresentation({
    required this.meetingId,
    required this.meetingCode,
    required this.title,
    this.description,
    required this.state,
    this.scheduledAt,
    required this.durationMinutes,
    required this.timezone,
    this.host,
    this.institution,
  });

  factory MeetingEntryPresentation.fromJson(Map<String, dynamic> j) =>
      MeetingEntryPresentation(
        meetingId: j['meetingId'] as String? ?? '',
        meetingCode: j['meetingCode'] as String? ?? '',
        title: j['title'] as String? ?? '',
        description: j['description'] as String?,
        state: j['state'] as String? ?? 'SCHEDULED',
        scheduledAt: j['scheduledAt'] != null
            ? DateTime.tryParse(j['scheduledAt'].toString())
            : null,
        durationMinutes: (j['durationMinutes'] as num?)?.toInt() ?? 60,
        timezone: j['timezone'] as String? ?? 'UTC',
        host: j['host'] is Map<String, dynamic>
            ? MeetingEntryHost.fromJson(j['host'] as Map<String, dynamic>)
            : null,
        institution: j['institution'] is Map<String, dynamic>
            ? MeetingEntryInstitution.fromJson(
                j['institution'] as Map<String, dynamic>)
            : null,
      );
}

class MeetingEntryResolution {
  final MeetingEntryOutcome outcome;
  final MeetingEntryAction action;
  final String reasonCode;

  /// Resolved identity summary (kind: MEMBER | GUEST_SESSION | ANONYMOUS).
  final String identityKind;
  final String? identityName;
  final String? identityEmail;

  final bool guestIdentityRequired;
  final bool emailVerificationRequired;
  final bool loginRequired;
  final bool approvalRequired;

  final String? participationRole;
  final bool meetingLive;

  final String? participantId;
  final String? bookingId;
  final String? invitationId;
  final String? eligibilitySource;

  /// Identity the entrant's own proof already carries (booking / invitation)
  /// — displayed, never re-asked.
  final String? prefillName;
  final String? prefillEmail;

  final MeetingEntryPresentation? presentation;

  const MeetingEntryResolution({
    required this.outcome,
    required this.action,
    required this.reasonCode,
    required this.identityKind,
    this.identityName,
    this.identityEmail,
    required this.guestIdentityRequired,
    this.emailVerificationRequired = false,
    required this.loginRequired,
    required this.approvalRequired,
    this.participationRole,
    required this.meetingLive,
    this.participantId,
    this.bookingId,
    this.invitationId,
    this.eligibilitySource,
    this.prefillName,
    this.prefillEmail,
    this.presentation,
  });

  factory MeetingEntryResolution.fromJson(Map<String, dynamic> j) {
    final identity = j['identity'] as Map<String, dynamic>? ?? const {};
    final requirements =
        j['requirements'] as Map<String, dynamic>? ?? const {};
    final participation =
        j['participation'] as Map<String, dynamic>? ?? const {};
    final admission = j['admission'] as Map<String, dynamic>? ?? const {};
    final context = j['context'] as Map<String, dynamic>? ?? const {};
    final prefill = j['prefill'] as Map<String, dynamic>?;
    return MeetingEntryResolution(
      outcome: MeetingEntryOutcome.parse(j['outcome'] as String?),
      action: MeetingEntryAction.parse(j['action'] as String?),
      reasonCode: j['reasonCode'] as String? ?? '',
      identityKind: identity['kind'] as String? ?? 'ANONYMOUS',
      identityName: identity['displayName'] as String?,
      identityEmail: identity['email'] as String?,
      guestIdentityRequired:
          requirements['guestIdentityRequired'] as bool? ?? false,
      emailVerificationRequired:
          requirements['emailVerificationRequired'] as bool? ?? false,
      loginRequired: requirements['loginRequired'] as bool? ?? false,
      approvalRequired: requirements['approvalRequired'] as bool? ?? false,
      participationRole: participation['role'] as String?,
      meetingLive: admission['meetingLive'] as bool? ?? false,
      participantId: context['participantId'] as String?,
      bookingId: context['bookingId'] as String?,
      invitationId: context['invitationId'] as String?,
      eligibilitySource: context['eligibilitySource'] as String?,
      prefillName: prefill?['name'] as String?,
      prefillEmail: prefill?['email'] as String?,
      presentation: j['presentation'] is Map<String, dynamic>
          ? MeetingEntryPresentation.fromJson(
              j['presentation'] as Map<String, dynamic>)
          : null,
    );
  }
}
