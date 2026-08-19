import '../../../core/identity/person_identity_model.dart';

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
  verifyInvitation,
  login,
  wait,
  requestAccess,
  none;

  static MeetingEntryAction parse(String? raw) {
    switch (raw) {
      case 'JOIN':
        return MeetingEntryAction.join;
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

/// The host shown on a pre-join surface. The backend selects the host with
/// PERSON_REFERENCE_SELECT and deliberately projects only a reduced view of
/// them here (no id, no handle) because this is an unauthenticated entry
/// screen. F116: reduced or not, it is a person, and it is read canonically -
/// `title` is the institutional role line and stays meeting-domain state.
class MeetingEntryHost {
  const MeetingEntryHost({
    this.person = AuraPersonIdentity.unknown,
    this.title,
  });

  final AuraPersonIdentity person;
  final String? title;

  String? get displayName {
    final name = person.displayName.trim();
    return name.isEmpty ? null : name;
  }

  String? get avatarUrl => person.avatarUrl;

  factory MeetingEntryHost.fromJson(Map<String, dynamic> j) => MeetingEntryHost(
        person: AuraPersonIdentity.fromJson(j),
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
  ///
  /// F053 / F116 — this summary spans two genuinely different kinds of
  /// entrant, and the resolver says which. Only MEMBER holds an Aura identity;
  /// GUEST_SESSION and ANONYMOUS are external entrants whose name, when there
  /// is one, came from the evidence they presented — a guest session's
  /// `guestName`, a booking's `bookerName`, an invitation's `inviteeName`
  /// (`participation-evidence.service.ts`). So the person branch is read
  /// through the canonical authority and the external branch keeps its own
  /// name; neither is forced into the other.
  final String identityKind;

  /// The entrant as an Aura person — present only for a MEMBER.
  final AuraPersonIdentity? identityPerson;

  /// The name external evidence supplied for a non-member entrant.
  final String? externalEntrantName;

  final String? identityEmail;

  /// The name the resolver actually RESOLVED, or null when it resolved none.
  ///
  /// Deliberately NOT the canonical label. `label` names a person the product
  /// must RENDER, and falling back to the shared neutral word is right there.
  /// This field is not rendered as a name: `pre_join_screen` pre-fills the
  /// entrant's own name box from it and reads absence as "we do not know who
  /// you are". Answering 'Someone' here would type that word into a stranger's
  /// name field and suppress the question. Naming an unresolved person stays
  /// the renderer's job; this reports what was resolved.
  String? get identityName => identityPerson != null
      ? _blankToNull(identityPerson!.displayName)
      : externalEntrantName;

  bool get identityIsAuraPerson => identityPerson != null;

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
    this.identityPerson,
    this.externalEntrantName,
    this.identityEmail,
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
    final identityKind = identity['kind'] as String? ?? 'ANONYMOUS';
    final isMember = identityKind == 'MEMBER';
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
      identityKind: identityKind,
      // The person branch delegates to the canonical authority; the external
      // branch is left exactly as the evidence stated it.
      identityPerson: isMember ? AuraPersonIdentity.fromJson(identity) : null,
      externalEntrantName:
          isMember ? null : _blankToNull(identity['displayName']?.toString()),
      identityEmail: identity['email'] as String?,
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

String? _blankToNull(String? value) {
  final trimmed = (value ?? '').trim();
  return trimmed.isEmpty ? null : trimmed;
}
