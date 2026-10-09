/// PLAIN WORDS FOR THE INSTITUTION WORKSPACE (phase 2, 2026-10-09).
///
/// The workspace showed people the server's own codes: `MEMBER_JOINED` under
/// every activity line, `INVITE_ONLY`, `CHALLENGE ISSUED`, `Trust: HIGH`,
/// `Standing: AUTHORIZED_SPEAKER`, an ISO timestamp and a "Slug". Every screen
/// takes its words from here, so one code reads the same everywhere and a code
/// nobody has named yet never reaches the screen as itself.
library;

String _norm(Object? raw) => (raw ?? '').toString().trim().toUpperCase();

/// A member's role, as a word inside a sentence ("… became an admin").
String institutionRoleWord(Object? role) {
  switch (_norm(role)) {
    case 'OWNER':
      return 'owner';
    case 'ADMIN':
      return 'admin';
    case 'EDITOR':
      return 'editor';
    case 'MEMBER':
      return 'member';
    default:
      return 'member';
  }
}

/// What a delegated permission lets someone do, as a short phrase.
String institutionCapabilityWords(Object? capability) {
  switch (_norm(capability)) {
    case 'HOST_MEETINGS':
      return 'host meetings';
    case 'OFFICIAL_REPRESENTATION':
      return 'speak officially for the institution';
    case 'PUBLISH_OFFICIAL':
      return 'publish official posts';
    case 'MANAGE_MEMBERS':
      return 'manage members';
    case 'MANAGE_INVITATIONS':
      return 'send invites';
    case 'MANAGE_JOIN_REQUESTS':
      return 'answer join requests';
    case 'MANAGE_MEETINGS':
      return 'manage meetings';
    case 'MANAGE_AVAILABILITY':
    case 'MANAGE_BOOKINGS':
    case 'MANAGE_PUBLIC_BOOKING':
      return 'manage bookings';
    case 'MANAGE_SPACES':
      return 'manage spaces';
    case 'MANAGE_ANNOUNCEMENTS':
      return 'manage announcements';
    case 'MANAGE_BRANDING':
      return 'edit the profile';
    case 'MANAGE_DOMAINS':
      return 'manage web addresses';
    case 'MANAGE_BILLING':
      return 'manage billing';
    case 'MANAGE_VERIFICATION':
      return 'handle verification';
    case 'MANAGE_ANALYTICS':
      return 'see engagement figures';
    case 'MANAGE_MATERIALS':
    case 'MANAGE_SUMMARIES':
    case 'MANAGE_RECORDINGS':
      return 'manage meeting records';
    case 'START_LIVE':
    case 'END_LIVE':
      return 'go live';
    default:
      return 'a new permission';
  }
}

/// Who can find and enter a space.
String spaceVisibilityWords(Object? visibility) {
  switch (_norm(visibility)) {
    case 'PRIVATE':
      return 'Private';
    case 'INVITE_ONLY':
      return 'Invite only';
    case 'DISCOVERABLE':
      return 'Open to members';
    default:
      return 'Members';
  }
}

/// Where a web address stands in being proved.
String domainStatusWords(Object? status) {
  switch (_norm(status)) {
    case 'PENDING':
      return 'Not checked yet';
    case 'CHALLENGE_ISSUED':
      return 'Waiting for the record';
    case 'UNDER_REVIEW':
      return 'Being reviewed';
    case 'VERIFIED':
      return 'Confirmed';
    case 'FAILED':
      return 'Check failed';
    case 'REVOKED':
      return 'Withdrawn';
    case 'EXPIRED':
      return 'Expired';
    default:
      return 'Not checked yet';
  }
}

/// How strongly a confirmed web address ties to the institution.
String domainTrustWords(Object? trust) {
  switch (_norm(trust)) {
    case 'ADMIN_CONFIRMED':
      return 'Confirmed by Aura';
    case 'HIGH':
      return 'Strong link';
    case 'MEDIUM':
      return 'Good link';
    case 'LOW':
      return 'Basic link';
    default:
      return '';
  }
}

/// A person's standing in the institution, as a sentence.
String institutionStandingWords(Object? state) {
  final s = (state ?? '').toString().trim();
  switch (s.toUpperCase().replaceAll('_', '')) {
    case 'AUTHORIZEDSPEAKER':
      return 'You may speak for this institution.';
    case 'VERIFIEDMEMBER':
      return 'You are a member.';
    case 'PENDING':
      return 'Your membership is waiting for approval.';
    case 'NONE':
      return 'You are not a member.';
    default:
      return '';
  }
}

/// The kind of announcement, as a label.
String announcementKindWords(Object? kind) {
  switch (_norm(kind)) {
    case 'SAFETY':
      return 'Safety';
    case 'GOVERNANCE':
      return 'Governance';
    case 'RELEASE':
      return 'Release';
    case 'POLICY_UPDATE':
      return 'Policy update';
    case 'GENERAL':
      return 'General';
    default:
      final s = (kind ?? '').toString().trim().toLowerCase().replaceAll('_', ' ');
      return s.isEmpty ? 'General' : s[0].toUpperCase() + s.substring(1);
  }
}

/// A unit's address, made from its name: "North Branch" → "north-branch".
String unitAddressFromName(String name) {
  final s = name
      .toLowerCase()
      .replaceAll(RegExp(r"['’]"), '')
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return s.isEmpty ? 'unit' : (s.length > 60 ? s.substring(0, 60) : s);
}
