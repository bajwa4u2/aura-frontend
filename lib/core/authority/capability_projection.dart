/// CAPABILITY PROJECTION — C1.
///
/// > **WHAT MAY I DO IN THIS CONTEXT?**
///
/// ── THE ONE RULE ─────────────────────────────────────────────────────────
///
///     CLIENT PRESENTATION  ≠  SECURITY AUTHORIZATION
///
/// Everything here decides what a person is *shown*. Nothing here decides
/// what they are *allowed to do*. Backend enforcement is authoritative, and
/// **hidden UI is never the security boundary** — a surface that hides a
/// control has not protected anything, it has only avoided offering a dead
/// end.
///
/// ── WHERE THE TRUTH COMES FROM ───────────────────────────────────────────
/// The backend computes `effective = ROLE_CAPABILITIES[role] ∪ active
/// delegated grants` in `InstitutionAuthorityService`, which its own doctrine
/// names "the single authorization authority for institutions". This class
/// **consumes** that set. It never recomputes it, never unions a role into it,
/// and never invents a capability the backend did not report.
///
/// ── ROLE IS NOT PERMISSION, BUT ROLE IS NOT NOTHING ──────────────────────
/// Governance-exclusive acts — ownership transfer, institution lifecycle,
/// appointing or removing admins — are deliberately **not** capabilities in
/// the backend model, precisely so they can never be delegated away. They are
/// role authority. So [InstitutionStanding] keeps the role, and
/// [ConsequentialAct] declares which of the two a given act requires.
///
/// Asking "is this person an ADMIN?" to decide whether to show a *capability*
/// control is the drift. Asking it to decide whether to show *ownership
/// transfer* is correct.
library;

import 'acting_context.dart' show ActingAvailability;

/// Canonical institutional capability tokens.
///
/// Mirror of the backend `InstitutionCapability` enum. Kept as a typed list so
/// a surface cannot invent a token by typo and silently get `false` forever.
class InstitutionCapabilityToken {
  const InstitutionCapabilityToken._(this.wire);
  final String wire;

  static const manageMembers = InstitutionCapabilityToken._('MANAGE_MEMBERS');
  static const manageInvitations =
      InstitutionCapabilityToken._('MANAGE_INVITATIONS');
  static const manageJoinRequests =
      InstitutionCapabilityToken._('MANAGE_JOIN_REQUESTS');
  static const manageMeetings = InstitutionCapabilityToken._('MANAGE_MEETINGS');
  static const manageAvailability =
      InstitutionCapabilityToken._('MANAGE_AVAILABILITY');
  static const manageBookings = InstitutionCapabilityToken._('MANAGE_BOOKINGS');
  static const managePublicBooking =
      InstitutionCapabilityToken._('MANAGE_PUBLIC_BOOKING');
  static const manageSpaces = InstitutionCapabilityToken._('MANAGE_SPACES');
  static const manageAnnouncements =
      InstitutionCapabilityToken._('MANAGE_ANNOUNCEMENTS');
  static const manageBranding = InstitutionCapabilityToken._('MANAGE_BRANDING');
  static const manageDomains = InstitutionCapabilityToken._('MANAGE_DOMAINS');
  static const manageBilling = InstitutionCapabilityToken._('MANAGE_BILLING');
  static const manageVerification =
      InstitutionCapabilityToken._('MANAGE_VERIFICATION');
  static const manageAnalytics =
      InstitutionCapabilityToken._('MANAGE_ANALYTICS');
  static const manageMaterials =
      InstitutionCapabilityToken._('MANAGE_MATERIALS');
  static const manageSummaries =
      InstitutionCapabilityToken._('MANAGE_SUMMARIES');
  static const manageRecordings =
      InstitutionCapabilityToken._('MANAGE_RECORDINGS');
  static const hostMeetings = InstitutionCapabilityToken._('HOST_MEETINGS');
  static const officialRepresentation =
      InstitutionCapabilityToken._('OFFICIAL_REPRESENTATION');
  static const publishOfficial =
      InstitutionCapabilityToken._('PUBLISH_OFFICIAL');
  static const startLive = InstitutionCapabilityToken._('START_LIVE');
  static const endLive = InstitutionCapabilityToken._('END_LIVE');

  static const all = <InstitutionCapabilityToken>[
    manageMembers, manageInvitations, manageJoinRequests, manageMeetings,
    manageAvailability, manageBookings, managePublicBooking, manageSpaces,
    manageAnnouncements, manageBranding, manageDomains, manageBilling,
    manageVerification, manageAnalytics, manageMaterials, manageSummaries,
    manageRecordings, hostMeetings, officialRepresentation, publishOfficial,
    startLive, endLive,
  ];

  @override
  String toString() => wire;
}

/// Institutional governance role. **Not a permission** — see the library doc.
enum InstitutionRole { member, admin, owner }

extension InstitutionRoleWire on InstitutionRole {
  String get wire => switch (this) {
        InstitutionRole.owner => 'OWNER',
        InstitutionRole.admin => 'ADMIN',
        InstitutionRole.member => 'MEMBER',
      };

  /// Governance rank, mirroring the backend `INSTITUTION_ROLE_RANK`.
  int get rank => switch (this) {
        InstitutionRole.owner => 3,
        InstitutionRole.admin => 2,
        InstitutionRole.member => 1,
      };

  bool atLeast(InstitutionRole other) => rank >= other.rank;

  static InstitutionRole? parse(String? wire) {
    switch ((wire ?? '').trim().toUpperCase()) {
      case 'OWNER':
        return InstitutionRole.owner;
      case 'ADMIN':
        return InstitutionRole.admin;
      case 'MEMBER':
        return InstitutionRole.member;
      default:
        return null;
    }
  }
}

/// What an act requires: a capability, or governance role, or neither.
class ActingRequirement {
  const ActingRequirement.personal()
      : capability = null,
        minimumRole = null,
        isPersonal = true;

  const ActingRequirement.capability(InstitutionCapabilityToken this.capability)
      : minimumRole = null,
        isPersonal = false;

  const ActingRequirement.governance(InstitutionRole this.minimumRole)
      : capability = null,
        isPersonal = false;

  final InstitutionCapabilityToken? capability;
  final InstitutionRole? minimumRole;

  /// True for acts a person performs as themselves, needing no institution.
  final bool isPersonal;
}

/// A person's standing in one institution, **as reported by the backend**.
class InstitutionStanding {
  const InstitutionStanding({
    required this.institutionId,
    required this.institutionName,
    required this.effectiveCapabilities,
    this.institutionLogoUrl,
    this.role,
    this.isInstitutionAccount = false,
  });

  final String institutionId;
  final String institutionName;
  final String? institutionLogoUrl;

  /// Effective capability set exactly as the backend reported it.
  ///
  /// **Nothing is added client-side.** The previous implementation injected a
  /// fabricated six-capability set whenever it decided the session was an
  /// "authorized speaker" with no role — inventing authority the backend had
  /// not granted. That is why this field is a plain, closed set.
  final Set<InstitutionCapabilityToken> effectiveCapabilities;

  /// Governance role, for governance acts only.
  final InstitutionRole? role;

  /// The session is the institution itself rather than a person acting for it.
  final bool isInstitutionAccount;

  bool get isMember => role != null || isInstitutionAccount;

  /// Does the backend report this capability for this person here?
  bool has(InstitutionCapabilityToken capability) =>
      effectiveCapabilities.contains(capability);

  /// Why — if at all — this standing satisfies [requirement].
  /// Null means it does not, and the act must not be offered.
  ActingAvailability? availabilityFor(ActingRequirement requirement) {
    if (requirement.isPersonal) return null;

    final capability = requirement.capability;
    if (capability != null) {
      if (!has(capability)) return null;
      return isInstitutionAccount
          ? ActingAvailability.institutionAccount
          : ActingAvailability.institutionalCapability;
    }

    final minimum = requirement.minimumRole;
    if (minimum != null) {
      final r = role;
      if (r == null || !r.atLeast(minimum)) return null;
      return ActingAvailability.institutionalGovernanceRole;
    }

    return null;
  }

  /// Parse from the backend membership payload.
  ///
  /// Unknown capability tokens are dropped rather than guessed — a client that
  /// invents meaning for a token it does not understand is reconstructing
  /// authority.
  static InstitutionStanding fromBackend({
    required String institutionId,
    required String institutionName,
    String? institutionLogoUrl,
    required Iterable<dynamic> capabilities,
    String? roleWire,
    bool isInstitutionAccount = false,
  }) {
    final byWire = {for (final c in InstitutionCapabilityToken.all) c.wire: c};
    final set = <InstitutionCapabilityToken>{};
    for (final raw in capabilities) {
      final token = byWire[raw.toString().trim().toUpperCase()];
      if (token != null) set.add(token);
    }
    return InstitutionStanding(
      institutionId: institutionId,
      institutionName: institutionName,
      institutionLogoUrl: institutionLogoUrl,
      effectiveCapabilities: set,
      role: InstitutionRoleWire.parse(roleWire),
      isInstitutionAccount: isInstitutionAccount,
    );
  }
}

/// The consequential acts whose attribution or authority matters.
///
/// Discovered from real surfaces, not invented: each maps to a control that
/// exists today and to the backend authority that actually governs it.
enum ConsequentialAct {
  publishInstitutionPost,
  publishAnnouncement,
  designateOfficialPublication,
  manageMembers,
  manageInvitations,
  manageJoinRequests,
  manageSpaces,
  manageMeetings,
  hostMeeting,
  startLive,

  /// Named so NAVIGATION can ask the same question controls ask. Both map to
  /// capabilities the backend enum already defines -- nothing new is granted.
  manageAvailability,
  manageAnalytics,

  /// AUTHORING in the institution's voice, as distinct from PUBLISHING it.
  ///
  /// The backend draws this line consistently: creating and editing an
  /// institution post or announcement requires OFFICIAL_REPRESENTATION, while
  /// publishing requires PUBLISH_OFFICIAL / MANAGE_ANNOUNCEMENTS. That is what
  /// lets a Representative draft official content without holding the
  /// authority to release it, which is the whole point of the role being a
  /// speaking authority rather than an administrative one.
  authorOfficialContent,
  manageBranding,
  manageDomains,
  manageBilling,
  manageVerification,

  /// Governance — role authority, never delegable.
  appointAdmin,
  transferOwnership,

  /// Creating, editing, archiving an institution UNIT.
  ///
  /// Deliberately a ROLE requirement, matching what the backend actually
  /// enforces (`@RequireInstitutionRole('ADMIN')`). No MANAGE_UNITS capability
  /// exists, and the founder ruling of 2026-08-23 forbids inventing one before
  /// the Unit doctrine is recovered — so this NAMES the authority already in
  /// force rather than creating a new one. Keeping it role-shaped also leaves
  /// §11 open: creating or retiring a subordinate operating context may prove
  /// to be governance-different from operating inside one.
  administerUnits,

  /// Correspond in the institution's voice.
  ///
  /// The contract **C7 must consume** when it rebuilds correspondence: if this
  /// resolves alongside [sendDirectMessage], the person holds two legitimate
  /// acting contexts and must choose explicitly at message initiation. A route
  /// may establish the recipient and the context being viewed; it may never
  /// establish the sender.
  correspondAsInstitution,

  /// Ordinary personal acts, listed so surfaces can ask the same question
  /// everywhere and get "no ceremony" as the answer.
  publishPersonalPost,
  replyPersonally,
  sendDirectMessage,
}

extension ConsequentialActAuthority on ConsequentialAct {
  ActingRequirement get requirement => switch (this) {
        ConsequentialAct.publishInstitutionPost =>
          const ActingRequirement.capability(
              InstitutionCapabilityToken.publishOfficial),
        ConsequentialAct.publishAnnouncement =>
          const ActingRequirement.capability(
              InstitutionCapabilityToken.manageAnnouncements),
        ConsequentialAct.designateOfficialPublication =>
          const ActingRequirement.capability(
              InstitutionCapabilityToken.publishOfficial),
        ConsequentialAct.manageMembers => const ActingRequirement.capability(
            InstitutionCapabilityToken.manageMembers),
        ConsequentialAct.manageInvitations =>
          const ActingRequirement.capability(
              InstitutionCapabilityToken.manageInvitations),
        ConsequentialAct.manageJoinRequests =>
          const ActingRequirement.capability(
              InstitutionCapabilityToken.manageJoinRequests),
        ConsequentialAct.manageSpaces => const ActingRequirement.capability(
            InstitutionCapabilityToken.manageSpaces),
        ConsequentialAct.manageMeetings => const ActingRequirement.capability(
            InstitutionCapabilityToken.manageMeetings),
        ConsequentialAct.hostMeeting => const ActingRequirement.capability(
            InstitutionCapabilityToken.hostMeetings),
        ConsequentialAct.manageAvailability =>
          const ActingRequirement.capability(
              InstitutionCapabilityToken.manageAvailability),
        ConsequentialAct.manageAnalytics => const ActingRequirement.capability(
            InstitutionCapabilityToken.manageAnalytics),
        ConsequentialAct.authorOfficialContent =>
          const ActingRequirement.capability(
              InstitutionCapabilityToken.officialRepresentation),
        ConsequentialAct.startLive =>
          const ActingRequirement.capability(InstitutionCapabilityToken.startLive),
        ConsequentialAct.manageBranding => const ActingRequirement.capability(
            InstitutionCapabilityToken.manageBranding),
        ConsequentialAct.manageDomains => const ActingRequirement.capability(
            InstitutionCapabilityToken.manageDomains),
        ConsequentialAct.manageBilling => const ActingRequirement.capability(
            InstitutionCapabilityToken.manageBilling),
        ConsequentialAct.manageVerification =>
          const ActingRequirement.capability(
              InstitutionCapabilityToken.manageVerification),

        // Governance: role, deliberately not a capability, so it can never be
        // delegated away. Mirrors the backend's own reasoning.
        ConsequentialAct.appointAdmin =>
          const ActingRequirement.governance(InstitutionRole.owner),
        ConsequentialAct.transferOwnership =>
          const ActingRequirement.governance(InstitutionRole.owner),
        ConsequentialAct.administerUnits =>
          const ActingRequirement.governance(InstitutionRole.admin),

        // Speaking for the institution in correspondence is the same authority
        // as speaking for it anywhere: official representation.
        ConsequentialAct.correspondAsInstitution =>
          const ActingRequirement.capability(
              InstitutionCapabilityToken.officialRepresentation),

        ConsequentialAct.publishPersonalPost =>
          const ActingRequirement.personal(),
        ConsequentialAct.replyPersonally => const ActingRequirement.personal(),
        ConsequentialAct.sendDirectMessage => const ActingRequirement.personal(),
      };

  /// True when this act speaks publicly in an institution's voice. Used to
  /// decide where attribution must be visible before commitment.
  bool get isPublicInstitutionalSpeech => switch (this) {
        ConsequentialAct.publishInstitutionPost ||
        ConsequentialAct.publishAnnouncement ||
        ConsequentialAct.designateOfficialPublication ||
        ConsequentialAct.startLive =>
          true,
        _ => false,
      };
}

/// How a control should be presented. **Presentation only.**
enum ControlPresentation {
  /// Offer it normally.
  available,

  /// The person does not hold this authority and has no path to it here.
  /// Capability-Adaptive Experience: do not make them navigate around
  /// controls built for authority they do not have.
  absent,

  /// Visible but not actionable, because the reason is worth communicating
  /// (e.g. the institution is unverified). Use sparingly — a disabled control
  /// the person can never enable is just noise.
  explained,
}

/// Projects backend-reported authority into presentation decisions.
class CapabilityProjection {
  const CapabilityProjection(this.standing);

  /// Null when there is no institutional context at all.
  final InstitutionStanding? standing;

  /// Does the backend report this capability here? Presentation only.
  bool has(InstitutionCapabilityToken capability) =>
      standing?.has(capability) ?? false;

  /// Whether the person holds governance authority of at least [role].
  /// Only legitimate for governance acts — see the library doc.
  bool holdsGovernanceRole(InstitutionRole role) {
    final r = standing?.role;
    return r != null && r.atLeast(role);
  }

  /// How to present the control for [act].
  ///
  /// Defaults to [ControlPresentation.absent] rather than a disabled control,
  /// because the frozen Capability-Adaptive Experience doctrine says a person
  /// should not be walked through an interface built around authority they do
  /// not possess.
  ControlPresentation presentationFor(
    ConsequentialAct act, {
    String? explainWhenUnavailable,
  }) {
    final requirement = act.requirement;
    if (requirement.isPersonal) return ControlPresentation.available;

    final s = standing;
    if (s == null) return ControlPresentation.absent;
    if (s.availabilityFor(requirement) != null) {
      return ControlPresentation.available;
    }
    return explainWhenUnavailable == null
        ? ControlPresentation.absent
        : ControlPresentation.explained;
  }
}
