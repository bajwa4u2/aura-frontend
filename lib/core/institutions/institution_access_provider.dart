import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/session_bootstrap.dart';
import '../auth/session_providers.dart';
import '../net/dio_provider.dart';

enum InstitutionAccessState {
  none,
  pending,
  verifiedMember,
  authorizedSpeaker,
}

/// A single institution the current member belongs to. Display-only shape for
/// member surfaces (the left-nav affiliation line). Capacity-aware: a member
/// may merely belong, or be authorized to speak for the institution.
class MemberAffiliation {
  const MemberAffiliation({
    required this.id,
    required this.name,
    required this.slug,
    this.logoUrl,
    required this.role,
    required this.canSpeakOfficially,
    required this.isVerified,
  });

  final String id;
  final String name;
  final String slug;
  final String? logoUrl;

  /// Canonical role wire token (OWNER/ADMIN/EDITOR/MEMBER), upper-cased.
  final String role;
  final bool canSpeakOfficially;
  final bool isVerified;

  /// Tolerant parse of one `memberships[]` entry from `/institutions/me`.
  /// Returns null when the entry lacks a usable institution id.
  static MemberAffiliation? fromJson(Map<String, dynamic> m) {
    final inst = m['institution'] is Map
        ? Map<String, dynamic>.from(m['institution'] as Map)
        : null;
    if (inst == null) return null;
    final id = (inst['id'] ?? '').toString().trim();
    if (id.isEmpty) return null;
    final logo = (inst['logoUrl'] ?? '').toString().trim();
    final status = (inst['status'] ?? '').toString().trim().toUpperCase();
    return MemberAffiliation(
      id: id,
      name: (inst['name'] ?? '').toString().trim(),
      slug: (inst['slug'] ?? '').toString().trim(),
      logoUrl: logo.isEmpty ? null : logo,
      role: (m['role'] ?? '').toString().trim().toUpperCase(),
      canSpeakOfficially: m['canSpeakOfficially'] == true,
      isVerified: inst['isVerified'] == true || status == 'VERIFIED',
    );
  }
}

class InstitutionAccess {
  final InstitutionAccessState state;
  final Map<String, dynamic>? institution;
  final Map<String, dynamic>? membership;
  final Map<String, dynamic>? request;

  /// All active affiliations (primary-first). Empty when the user belongs to
  /// no institution — the left-nav line self-hides on empty.
  final List<MemberAffiliation> memberships;

  const InstitutionAccess({
    required this.state,
    this.institution,
    this.membership,
    this.request,
    this.memberships = const <MemberAffiliation>[],
  });

  bool get hasAccess =>
      state == InstitutionAccessState.pending ||
      state == InstitutionAccessState.verifiedMember ||
      state == InstitutionAccessState.authorizedSpeaker;
}

/// GOVERNANCE V1 — the institutional capability tokens the backend exposes
/// on `/institutions/me` (`membership.capabilities`). Mirror of the Prisma
/// `InstitutionCapability` enum. The frontend renders authority truthfully
/// from this set — never from role guesses.
class InstitutionCapabilities {
  static const manageMembers = 'MANAGE_MEMBERS';
  static const manageInvitations = 'MANAGE_INVITATIONS';
  static const manageJoinRequests = 'MANAGE_JOIN_REQUESTS';
  static const manageMeetings = 'MANAGE_MEETINGS';
  static const manageAvailability = 'MANAGE_AVAILABILITY';
  static const manageBookings = 'MANAGE_BOOKINGS';
  static const managePublicBooking = 'MANAGE_PUBLIC_BOOKING';
  static const manageSpaces = 'MANAGE_SPACES';
  static const manageAnnouncements = 'MANAGE_ANNOUNCEMENTS';
  static const manageBranding = 'MANAGE_BRANDING';
  static const manageDomains = 'MANAGE_DOMAINS';
  static const manageBilling = 'MANAGE_BILLING';
  static const manageVerification = 'MANAGE_VERIFICATION';
  static const manageAnalytics = 'MANAGE_ANALYTICS';
  static const manageMaterials = 'MANAGE_MATERIALS';
  static const manageSummaries = 'MANAGE_SUMMARIES';
  static const manageRecordings = 'MANAGE_RECORDINGS';
  static const hostMeetings = 'HOST_MEETINGS';
  static const officialRepresentation = 'OFFICIAL_REPRESENTATION';
  static const publishOfficial = 'PUBLISH_OFFICIAL';
  static const startLive = 'START_LIVE';
  static const endLive = 'END_LIVE';
}

/// Derived, synchronous view of the current institution's identity and the
/// acting member's authority. Null until the institution access resolves
/// and the user has an institution with a known id.
class InstitutionIdentity {
  const InstitutionIdentity({
    required this.id,
    required this.name,
    required this.slug,
    this.logoUrl,
    required this.isAuthorizedSpeaker,
    required this.capabilities,
    this.status,
    this.role,
    this.institutionClass,
    this.institutionType,
    this.domainTags = const [],
  });

  final String id;
  final String name;
  final String slug;
  final String? logoUrl;
  final bool isAuthorizedSpeaker;

  /// Effective institutional capability set (role-implied ∪ delegated),
  /// as reported by the backend. Source of truth for every visibility rule.
  final Set<String> capabilities;

  /// Institution verification/lifecycle status, e.g. 'VERIFIED', 'PENDING'.
  final String? status;

  /// Membership role in canonical wire format: 'OWNER', 'ADMIN', 'MEMBER'.
  /// Null for institution-account tokens.
  final String? role;

  final String? institutionClass;
  final String? institutionType;
  final List<String> domainTags;

  bool get isVerified => (status ?? '').toUpperCase() == 'VERIFIED';

  // ── Governance authority (Phase 5: isOwner / isAdmin / canRepresent /
  //    canHost split, plus per-capability evaluation) ──────────────────────

  bool get isOwner => (role ?? '').toUpperCase() == 'OWNER';

  /// Operational leadership — owner or admin. Governs the workspace's
  /// operational surfaces. NOT a proxy for owner-only authority.
  bool get isAdmin {
    final r = (role ?? '').toUpperCase();
    return r == 'OWNER' || r == 'ADMIN';
  }

  bool can(String capability) => capabilities.contains(capability);

  /// Official institutional voice (Representative or higher).
  bool get canRepresent =>
      can(InstitutionCapabilities.officialRepresentation) ||
      isAuthorizedSpeaker;

  /// Meeting operator (assigned Host or higher).
  bool get canHost =>
      can(InstitutionCapabilities.hostMeetings) ||
      can(InstitutionCapabilities.manageMeetings);

  bool get canManageMeetings => can(InstitutionCapabilities.manageMeetings);
  bool get canManageMembers => can(InstitutionCapabilities.manageMembers);
  bool get canManageInvitations =>
      can(InstitutionCapabilities.manageInvitations);
  bool get canManageJoinRequests =>
      can(InstitutionCapabilities.manageJoinRequests);
  bool get canManageBranding => can(InstitutionCapabilities.manageBranding);
  bool get canManageDomains => can(InstitutionCapabilities.manageDomains);
  bool get canManageBilling => can(InstitutionCapabilities.manageBilling);
  bool get canManageSpaces => can(InstitutionCapabilities.manageSpaces);
  bool get canManageAnnouncements =>
      can(InstitutionCapabilities.manageAnnouncements);
  bool get canManageAvailability =>
      can(InstitutionCapabilities.manageAvailability);
  bool get canStartLive => can(InstitutionCapabilities.startLive);

  /// True when the acting member can author in the institution's voice.
  bool get canCreatePosts =>
      canRepresent || can(InstitutionCapabilities.publishOfficial);

  /// True when the acting member can publish/approve official posts directly.
  bool get canPublishPosts => can(InstitutionCapabilities.publishOfficial);
}

final institutionIdentityProvider = Provider<InstitutionIdentity?>((ref) {
  final access = ref.watch(institutionAccessProvider).valueOrNull;
  if (access == null || !access.hasAccess) return null;

  // Institution data may be at access.institution or inside access.membership['institution'].
  final inst = access.institution ??
      (access.membership?['institution'] is Map
          ? Map<String, dynamic>.from(
              access.membership!['institution'] as Map,
            )
          : null);

  if (inst == null) return null;

  String readStr(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      final v = m[k]?.toString().trim() ?? '';
      if (v.isNotEmpty) return v;
    }
    return '';
  }

  final id = readStr(inst, ['id']);
  if (id.isEmpty) return null;

  final membership = access.membership;
  final role = (membership?['role'] ?? '').toString().trim().toUpperCase();
  final isAuthorizedSpeaker =
      access.state == InstitutionAccessState.authorizedSpeaker;

  // GOVERNANCE V1: capabilities come from the backend. An institution-account
  // token (authorized speaker with no explicit membership role) governs the
  // institution itself — grant the full operational set so its own workspace
  // renders truthfully.
  final rawCaps = membership?['capabilities'];
  final capabilities = <String>{
    if (rawCaps is List)
      ...rawCaps.map((e) => e.toString().trim().toUpperCase()).where((s) => s.isNotEmpty),
  };
  if (isAuthorizedSpeaker && role.isEmpty) {
    capabilities.addAll(const [
      InstitutionCapabilities.officialRepresentation,
      InstitutionCapabilities.publishOfficial,
      InstitutionCapabilities.manageAnnouncements,
      InstitutionCapabilities.manageMeetings,
      InstitutionCapabilities.startLive,
      InstitutionCapabilities.endLive,
    ]);
  }
  final status = readStr(inst, ['status', 'verificationStatus']);

  String? readOpt(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      final v = m[k]?.toString().trim() ?? '';
      if (v.isNotEmpty) return v;
    }
    return null;
  }

  // Synthesize a status when the inst payload only carries an isVerified flag.
  String? finalStatus = status.isNotEmpty ? status.toUpperCase() : null;
  if (finalStatus == null) {
    final isVerifiedRaw = inst['isVerified'] ?? inst['verified'];
    if (isVerifiedRaw == true || isVerifiedRaw == 1 || isVerifiedRaw == 'true') {
      finalStatus = 'VERIFIED';
    }
  }

  // Ontology fields — defensively parsed so a legacy payload without
  // them produces a perfectly valid (unclassified) identity.
  final rawTags = inst['domainTags'];
  final tagList = rawTags is List
      ? rawTags
          .map((e) => e?.toString().trim() ?? '')
          .where((s) => s.isNotEmpty)
          .toList(growable: false)
      : const <String>[];

  return InstitutionIdentity(
    id: id,
    name: readStr(inst, ['name', 'displayName', 'title', 'organizationName']),
    slug: readStr(inst, ['slug', 'handle']),
    logoUrl: readOpt(inst, ['logoUrl', 'avatarUrl', 'logo']),
    isAuthorizedSpeaker: isAuthorizedSpeaker,
    capabilities: capabilities,
    status: finalStatus,
    role: role.isEmpty ? null : role,
    institutionClass: readOpt(inst, ['institutionClass']),
    institutionType: readOpt(inst, ['institutionType']),
    domainTags: tagList,
  );
});

/// All institutions the current member is affiliated with (primary-first).
/// Derived from the session-cached [institutionAccessProvider] — no extra
/// request. Returns an empty list while loading, on error, or when the user
/// has no affiliation, so consumers (the left-nav line) can self-hide safely.
final myAffiliationsProvider = Provider<List<MemberAffiliation>>((ref) {
  final access = ref.watch(institutionAccessProvider).valueOrNull;
  return access?.memberships ?? const <MemberAffiliation>[];
});

final institutionAccessProvider = FutureProvider<InstitutionAccess>((ref) async {
  await ref.watch(sessionBootstrapProvider.future);

  final authStatus = ref.watch(authStatusProvider);
  if (authStatus != AuthStatus.authed) {
    return const InstitutionAccess(state: InstitutionAccessState.none);
  }

  final dio = ref.watch(dioProvider);

  // Probe accountType from /auth/me. INSTITUTION accounts represent the
  // institution itself; PUBLIC accounts may be members of an institution.
  // Both rely on /institutions/me for the actual institution + membership
  // payload — /auth/me itself does not return institution data.
  String accountType = 'PUBLIC';
  try {
    final meData = await ref.watch(authMeDataProvider.future);
    accountType = (meData['accountType'] ?? '').toString().toUpperCase();
  } catch (_) {
    // /auth/me may transiently fail; treat as PUBLIC and let the call below
    // surface the real error if institutional access is required.
  }

  try {
    final res = await dio.get('/institutions/me');
    final data = Map<String, dynamic>.from(res.data);
    final stateRaw = (data['state'] ?? '').toString().trim();

    InstitutionAccessState parsed;
    switch (stateRaw) {
      case 'PENDING_REQUEST':
        parsed = InstitutionAccessState.pending;
        break;
      case 'VERIFIED_MEMBER':
        parsed = InstitutionAccessState.verifiedMember;
        break;
      case 'AUTHORIZED_SPEAKER':
        parsed = InstitutionAccessState.authorizedSpeaker;
        break;
      default:
        parsed = InstitutionAccessState.none;
    }

    final institution = data['institution'] is Map
        ? Map<String, dynamic>.from(data['institution'])
        : null;
    final membership = data['membership'] is Map
        ? Map<String, dynamic>.from(data['membership'])
        : (institution != null
            // Institution-account users without an explicit membership row
            // still act as the institution itself; synthesise a minimal
            // membership envelope so downstream consumers see the institution.
            ? <String, dynamic>{'institution': institution}
            : null);

    // Institution-account tokens always grant full speaker rights, even if
    // the /institutions/me state field is missing or downgraded.
    if (accountType == 'INSTITUTION' && institution != null) {
      parsed = InstitutionAccessState.authorizedSpeaker;
    }

    final memberships = data['memberships'] is List
        ? (data['memberships'] as List)
            .whereType<Map>()
            .map((e) => MemberAffiliation.fromJson(
                  Map<String, dynamic>.from(e),
                ))
            .whereType<MemberAffiliation>()
            .toList(growable: false)
        : const <MemberAffiliation>[];

    return InstitutionAccess(
      state: parsed,
      institution: institution,
      membership: membership,
      request: data['request'] is Map
          ? Map<String, dynamic>.from(data['request'])
          : null,
      memberships: memberships,
    );
  } on DioException catch (e) {
    final code = e.response?.statusCode;

    if (code == 401 || code == 403) {
      return const InstitutionAccess(state: InstitutionAccessState.none);
    }

    rethrow;
  }
});