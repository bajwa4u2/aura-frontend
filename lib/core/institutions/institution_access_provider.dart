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
    this.capabilities = const <String>{},
  });

  final String id;
  final String name;
  final String slug;
  final String? logoUrl;

  /// Canonical role wire token (OWNER/ADMIN/EDITOR/MEMBER), upper-cased.
  final String role;
  final bool canSpeakOfficially;
  final bool isVerified;

  /// Effective capability set for THIS institution, as reported by the
  /// backend (C1). Previously only the arbitrarily-chosen oldest membership
  /// carried capabilities, so a client viewing institution B reasoned with
  /// institution A's authority.
  final Set<String> capabilities;

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
      capabilities: <String>{
        if (m['capabilities'] is List)
          ...(m['capabilities'] as List)
              .map((e) => e.toString().trim().toUpperCase())
              .where((s) => s.isNotEmpty),
      },
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

  /// THE INSTITUTION'S CANONICAL PRODUCT ADDRESS.
  ///
  /// The slug, always, when there is one. Falls back to the persistence id
  /// ONLY when an institution somehow has no slug — a broken address is worse
  /// than an ugly one, and the router canonicalizes an id on arrival anyway.
  ///
  /// Every human-facing workspace link is built from this rather than from
  /// `id`, so persistence identity cannot leak into the address space by a
  /// caller reaching for the nearest field.
  String get workspaceAddress =>
      slug.trim().isNotEmpty ? slug.trim() : id;

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

  /// C3 — may this member make the institution the ACTING PARTY of an
  /// actor-level operation (institution follow, institution inbox)?
  /// Mirrors the backend actor-authority gate exactly: OWNER/ADMIN role or
  /// representative standing. This is GOVERNANCE authority (C1: governance
  /// acts remain role authority, deliberately not delegable capability) —
  /// the one canonical predicate; consumers must not re-compose it.
  bool get canActAsInstitution => isOwner || isAdmin || canRepresent;

  /// True when the acting member can author in the institution's voice.
  bool get canCreatePosts =>
      canRepresent || can(InstitutionCapabilities.publishOfficial);

  /// True when the acting member can publish/approve official posts directly.
  bool get canPublishPosts => can(InstitutionCapabilities.publishOfficial);
}

final institutionIdentityProvider = Provider<InstitutionIdentity?>((ref) {
  return _identityFrom(ref.watch(institutionAccessProvider).valueOrNull);
});

/// The identity derivation, shared by the ambient provider and the
/// route-bound one so a workspace screen reads the SAME shape whichever
/// institution it was pointed at.
InstitutionIdentity? _identityFrom(InstitutionAccess? access) {
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
  // C1 — THE CLIENT NEVER FABRICATES CAPABILITY.
  //
  // Six capability tokens used to be injected here whenever the session looked
  // like an "authorized speaker" with no role, to compensate for a supposed
  // institution-account gap. Investigation showed the gap does not exist:
  // `institution-bootstrap.ts` always creates an `InstitutionMember` row with
  // `role: OWNER, canSpeakOfficially: true`, and `/institutions/me` returns no
  // top-level `institution` key — so a membership without a role can never
  // reach this code. The compensation was unreachable, and it made the client
  // a second source of authority.
  //
  // Effective capability is computed by InstitutionAuthorityService and
  // consumed here unchanged. Gate-enforced by the C1 anti-drift suite.
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
}

/// All institutions the current member is affiliated with (primary-first).
/// Derived from the session-cached [institutionAccessProvider] — no extra
/// request. Returns an empty list while loading, on error, or when the user
/// has no affiliation, so consumers (the left-nav line) can self-hide safely.
final myAffiliationsProvider = Provider<List<MemberAffiliation>>((ref) {
  final access = ref.watch(institutionAccessProvider).valueOrNull;
  return access?.memberships ?? const <MemberAffiliation>[];
});

/// UNKNOWN IS NOT ABSENT — for the shell's own identity block.
///
/// `myAffiliationsProvider` answers with an empty list in BOTH states: "this
/// person holds no institution" and "we have not found out yet", because
/// `valueOrNull` destroys that distinction (the same trap
/// `institutionAuthoritySnapshotProvider` documents for routing).
///
/// The shell hid its affiliation line on empty, so on every entry and refresh a
/// person who DOES speak for an institution was first presented as though they
/// did not, and the institution appeared a moment later. Founder-observed
/// 2026-08-22: "a transit phase between public user and institution context —
/// narrow, but visibly noted."
///
/// Nothing here fetches or decides anything new; it exposes the resolution
/// state that already exists so presentation can say "not yet" instead of
/// asserting "none".
final myAffiliationsResolvedProvider = Provider<bool>((ref) {
  final async = ref.watch(institutionAccessProvider);
  // An error is RESOLVED-but-unknown, not still loading: an eternal skeleton
  // would be its own lie, and F068 forbids an unbounded wait.
  return !(async.isLoading && !async.hasValue);
});

/// RC3 (screen-binding half) — the workspace record for a SPECIFIC
/// institution the person holds.
///
/// `/institutions/me` used to describe whichever institution the backend
/// picked (the oldest membership), so a member of two institutions could
/// route to institution B while every payload described institution A. The
/// client's only truthful option was to rewrite B's URL to A.
///
/// This is a SCOPED READ of that same endpoint, not a second "active
/// institution" authority. Nothing here selects, stores or mutates which
/// institution is current; it answers "what is my standing in THIS one", and
/// the backend validates the claim against the caller's own membership. An
/// institution the person does not hold comes back as no standing at all —
/// the identical payload a stranger receives.
final institutionWorkspaceProvider =
    FutureProvider.family<InstitutionAccess, String>((ref, institutionId) async {
  return _readInstitutionState(ref, institutionId: institutionId.trim());
});

/// Per-institution identity for a workspace screen bound to a route.
///
/// Falls back to the ambient identity when the id is empty or names the
/// institution already in context, so a screen with no route id behaves
/// exactly as before.
final institutionWorkspaceIdentityProvider =
    Provider.family<InstitutionIdentity?, String>((ref, institutionId) {
  final id = institutionId.trim();
  final ambient = ref.watch(institutionIdentityProvider);
  if (id.isEmpty || ambient?.id == id) return ambient;
  return _identityFrom(ref.watch(institutionWorkspaceProvider(id)).valueOrNull);
});

final institutionAccessProvider = FutureProvider<InstitutionAccess>((ref) async {
  return _readInstitutionState(ref, institutionId: null);
});

Future<InstitutionAccess> _readInstitutionState(
  Ref ref, {
  required String? institutionId,
}) async {
  // DEPENDENCIES DECLARED BEFORE THE FIRST AWAIT.
  //
  // `ref.watch` after an await registers the dependency late, so a change
  // arriving in that window restarts this provider from the top. Until it
  // completes ONCE there is no previous value to fall back on, and the
  // institution route boundary reads "loading without a value" as "still
  // finding out" — which is how a cold load can sit on a spinner forever.
  final bootstrap = ref.watch(sessionBootstrapProvider.future);
  final dio = ref.watch(dioProvider);

  await bootstrap;

  final authStatus = ref.watch(authStatusProvider);
  if (authStatus != AuthStatus.authed) {
    return const InstitutionAccess(state: InstitutionAccessState.none);
  }

  // Probe accountType from /auth/me. INSTITUTION accounts represent the
  // institution itself; PUBLIC accounts may be members of an institution.
  // Both rely on /institutions/me for the actual institution + membership
  // payload — /auth/me itself does not return institution data.
  String accountType = 'PUBLIC';
  try {
    // READ, NOT WATCH. The account type is an advisory probe for one fallback
    // branch. Subscribing to it made every refresh of /auth/me restart this
    // provider — and a restart before the first completion leaves the whole
    // institution workspace with no resolved authority to render from.
    final meData = await ref.read(authMeDataProvider.future);
    accountType = (meData['accountType'] ?? '').toString().toUpperCase();
  } catch (_) {
    // /auth/me may transiently fail; treat as PUBLIC and let the call below
    // surface the real error if institutional access is required.
  }

  try {
    final res = await dio.get(
      '/institutions/me',
      queryParameters: (institutionId ?? '').isEmpty
          ? null
          : <String, dynamic>{'institutionId': institutionId},
    );
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
}