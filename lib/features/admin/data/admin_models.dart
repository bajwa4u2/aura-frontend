import '../../../core/identity/person_identity_model.dart';

// Domain models for the backend Admin Hub.
// All fromJson factories are defensive — missing / null fields fall back to safe defaults.

class AdminAccess {
  const AdminAccess({
    required this.person,
    required this.email,
    required this.role,
    required this.permissions,
    required this.status,
    required this.grants,
  });

  /// WHO the administrator is. Their authorization - role, permissions,
  /// grants, status - is this model's own and deliberately stays out of
  /// identity: identity is not authorization.
  final AuraPersonIdentity person;

  /// Account credential state, not part of the person projection.
  final String email;

  String get id => person.userId;
  String get displayName => person.displayName;

  final String role;
  final List<String> permissions;
  final String status;
  final List<AdminGrant> grants;

  static String _str(dynamic v) => (v ?? '').toString().trim();
  static List<String> _strList(dynamic v) {
    if (v is List) return v.map((e) => _str(e)).where((e) => e.isNotEmpty).toList();
    return const [];
  }

  factory AdminAccess.fromJson(Map<String, dynamic> json) {
    final data = _unwrap(json);
    return AdminAccess(
      person: AuraPersonIdentity.fromJson(data),
      email: _str(data['email']),
      role: _str(data['role']),
      permissions: _strList(data['permissions']),
      status: _str(data['status'] ?? 'active'),
      grants: _parseGrants(data['grants']),
    );
  }

  static Map<String, dynamic> _unwrap(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      final user = raw['user'];
      if (user is Map<String, dynamic>) return user;
      final data = raw['data'];
      if (data is Map<String, dynamic>) {
        final nestedUser = data['user'];
        if (nestedUser is Map<String, dynamic>) return nestedUser;
        return data;
      }
      return raw;
    }
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return const {};
  }

  static List<AdminGrant> _parseGrants(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => AdminGrant.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}

/// Lifecycle state derived from the admin-grant fields. Backend only ships
/// `active: bool` and (sometimes) a `status` string; the UI used to surface
/// "INACTIVE" with no clue whether that meant expired, revoked, or
/// bootstrap-only. This enum preserves the source-of-truth bool but adds
/// the disambiguation operators actually need.
enum AdminGrantStatus {
  /// Currently in force.
  active,
  /// Was active, then `expiresAt` passed.
  expired,
  /// Backend reported `active=false` and the grant has not expired —
  /// most often a manual revocation by another admin.
  revoked,
  /// System-issued OWNER grant (`grantedBy` empty / system) — present
  /// from initial admin bootstrap. Surfaced separately so operators can
  /// see at a glance which row anchors their access.
  bootstrap,
}

class AdminGrant {
  const AdminGrant({
    required this.id,
    required this.role,
    required this.permissions,
    required this.active,
    required this.grantedBy,
    required this.createdAt,
    this.expiresAt,
  });

  final String id;
  final String role;
  final List<String> permissions;
  final bool active;
  final String grantedBy;
  final DateTime createdAt;
  final DateTime? expiresAt;

  /// Derived from (active, expiresAt, grantedBy). Computed at read time so
  /// the value always reflects the current wall clock — an "active" grant
  /// flips to "expired" the instant the expiry passes without needing a
  /// backend round-trip.
  AdminGrantStatus get derivedStatus {
    final expiry = expiresAt;
    final isExpired = expiry != null && expiry.isBefore(DateTime.now());

    if (active && !isExpired) {
      // System-issued OWNER grants have an empty `grantedBy` (or
      // explicitly "system" / "bootstrap"). Mark them so the row reads
      // "BOOTSTRAP — system OWNER" rather than just "ACTIVE".
      final grantedById = grantedBy.toLowerCase();
      final isBootstrap = grantedById.isEmpty ||
          grantedById == 'system' ||
          grantedById == 'bootstrap';
      if (isBootstrap && role.toUpperCase() == 'OWNER') {
        return AdminGrantStatus.bootstrap;
      }
      return AdminGrantStatus.active;
    }
    if (isExpired) return AdminGrantStatus.expired;
    return AdminGrantStatus.revoked;
  }

  static String _str(dynamic v) => (v ?? '').toString().trim();
  static List<String> _strList(dynamic v) {
    if (v is List) return v.map((e) => _str(e)).where((e) => e.isNotEmpty).toList();
    return const [];
  }

  factory AdminGrant.fromJson(Map<String, dynamic> json) {
    return AdminGrant(
      id: _str(json['id']),
      role: _str(json['role']),
      permissions: _strList(json['permissions']),
      active: json['active'] == true || _str(json['status']) == 'active',
      grantedBy: _str(json['grantedBy'] ?? json['ownerId']),
      createdAt: _parseDate(json['createdAt']) ?? DateTime.now(),
      expiresAt: _parseDate(json['expiresAt']),
    );
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    final s = v.toString().trim();
    if (s.isEmpty) return null;
    return DateTime.tryParse(s);
  }
}

class AdminUserSummary {
  const AdminUserSummary({
    required this.person,
    required this.email,
    required this.role,
    required this.status,
    required this.createdAt,
    this.lastActiveAt,
  });

  /// The person this row is about - named the way they are named everywhere
  /// else in the product, including inside the Admin Hub.
  final AuraPersonIdentity person;
  final String email;

  String get id => person.userId;
  String get handle => person.handle;
  String get displayName => person.displayName;

  final String role;
  final String status;
  final DateTime createdAt;
  final DateTime? lastActiveAt;

  static String _str(dynamic v) => (v ?? '').toString().trim();

  factory AdminUserSummary.fromJson(Map<String, dynamic> json) {
    return AdminUserSummary(
      person: AuraPersonIdentity.fromJson(json),
      email: _str(json['email']),
      role: _str(json['role']),
      status: _str(json['status'] ?? 'active'),
      createdAt: _parseDate(json['createdAt']) ?? DateTime.now(),
      lastActiveAt: _parseDate(json['lastActiveAt'] ?? json['lastActive']),
    );
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    final s = v.toString().trim();
    if (s.isEmpty) return null;
    return DateTime.tryParse(s);
  }
}

class AdminAuditLogEntry {
  const AdminAuditLogEntry({
    required this.id,
    required this.action,
    required this.actorId,
    required this.actorEmail,
    required this.targetType,
    required this.createdAt,
    this.targetId,
    this.metadata,
  });

  final String id;
  final String action;
  final String actorId;
  final String actorEmail;
  final String targetType;
  final DateTime createdAt;
  final String? targetId;
  final Map<String, dynamic>? metadata;

  static String _str(dynamic v) => (v ?? '').toString().trim();

  factory AdminAuditLogEntry.fromJson(Map<String, dynamic> json) {
    return AdminAuditLogEntry(
      id: _str(json['id']),
      action: _str(json['action']),
      actorId: _str(json['actorId']),
      actorEmail: _str(json['actorEmail'] ?? json['actor']?['email']),
      targetType: _str(json['targetType'] ?? json['resourceType']),
      targetId: _str(json['targetId'] ?? json['resourceId']).let((s) => s.isEmpty ? null : s),
      createdAt: _parseDate(json['createdAt']) ?? DateTime.now(),
      metadata: json['metadata'] is Map<String, dynamic>
          ? json['metadata'] as Map<String, dynamic>
          : null,
    );
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    final s = v.toString().trim();
    if (s.isEmpty) return null;
    return DateTime.tryParse(s);
  }
}

class AdminMetricOverview {
  const AdminMetricOverview({
    required this.totalUsers,
    required this.activeUsers,
    required this.totalInstitutions,
    required this.pendingReports,
    required this.totalCommunications,
    required this.realtimeSessions,
    required this.totalDevices,
    required this.pendingPushJobs,
  });

  final int totalUsers;
  final int activeUsers;
  final int totalInstitutions;
  final int pendingReports;
  final int totalCommunications;
  final int realtimeSessions;
  final int totalDevices;
  final int pendingPushJobs;

  static int _int(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse((v ?? '').toString()) ?? 0;
  }

  /// Helper: dive into a nested JSON group safely.
  static Map<String, dynamic>? _group(Map<String, dynamic> json, String key) {
    final v = json[key];
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return Map<String, dynamic>.from(v);
    return null;
  }

  factory AdminMetricOverview.fromJson(Map<String, dynamic> json) {
    // The standard ResponseWrapInterceptor wraps the controller's payload
    // in `{ ok, data }`. Older mocks returned the bare payload, so we
    // accept either shape.
    final data = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json;

    // The backend ships NESTED groups (admin-hub.service.ts:937-989):
    //   users:          { total, active, disabled }
    //   institutions:   { total, verified, suspended, rejected, ... }
    //   reports:        { total, open, reviewing, resolved, dismissed }
    //   communications: { total, unread, digests, drafts, campaigns }
    //   realtime:       { sessions, activeSessions, participants, ... }
    //   devices:        { registered, active }
    //   push:           { attempts, sent, failed, skipped }
    //
    // Pre-Slice-D code read flat keys (`data['totalUsers']`, etc.) which
    // never existed; every metric collapsed to 0 via the int default.
    // We now read the correct nested paths and keep flat-key fallbacks
    // for any future endpoint that returns a flattened shape.
    final users = _group(data, 'users');
    final institutions = _group(data, 'institutions');
    final reports = _group(data, 'reports');
    final communications = _group(data, 'communications');
    final realtime = _group(data, 'realtime');
    final devices = _group(data, 'devices');
    final push = _group(data, 'push');

    return AdminMetricOverview(
      totalUsers: _int(users?['total'] ?? data['totalUsers']),
      activeUsers: _int(users?['active'] ?? data['activeUsers']),
      totalInstitutions:
          _int(institutions?['total'] ?? data['totalInstitutions']),
      pendingReports: _int(reports?['open'] ?? data['pendingReports']),
      totalCommunications:
          _int(communications?['total'] ?? data['totalCommunications']),
      realtimeSessions:
          _int(realtime?['activeSessions'] ?? data['realtimeSessions']),
      totalDevices: _int(devices?['registered'] ?? data['totalDevices']),
      pendingPushJobs: _int(push?['failed'] ?? data['pendingPushJobs']),
    );
  }
}

class AdminHealthSnapshot {
  const AdminHealthSnapshot({
    required this.apiStatus,
    required this.dbStatus,
    required this.emailStatus,
    required this.pushStatus,
    required this.realtimeStatus,
    required this.healthy,
  });

  final String apiStatus;
  final String dbStatus;
  final String emailStatus;
  final String pushStatus;
  final String realtimeStatus;
  final bool healthy;

  static String _status(dynamic v) {
    final s = (v ?? '').toString().toLowerCase().trim();
    if (s.isEmpty) return 'unknown';
    return s;
  }

  factory AdminHealthSnapshot.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json;
    final services = data['services'] is Map<String, dynamic>
        ? data['services'] as Map<String, dynamic>
        : data;
    return AdminHealthSnapshot(
      apiStatus: _status(services['api'] ?? data['api']),
      dbStatus: _status(services['db'] ?? services['database'] ?? data['db']),
      emailStatus: _status(services['email'] ?? data['email']),
      pushStatus: _status(services['push'] ?? data['push']),
      realtimeStatus: _status(services['realtime'] ?? data['realtime']),
      healthy: data['healthy'] == true ||
          data['status'] == 'healthy' ||
          data['status'] == 'ok',
    );
  }

  bool isOk(String status) =>
      status == 'ok' || status == 'healthy' || status == 'up';
}

class AdminSetting {
  const AdminSetting({
    required this.key,
    required this.value,
    this.description,
    this.updatedAt,
  });

  final String key;
  final dynamic value;
  final String? description;
  final DateTime? updatedAt;

  static String _str(dynamic v) => (v ?? '').toString().trim();

  factory AdminSetting.fromJson(Map<String, dynamic> json) {
    return AdminSetting(
      key: _str(json['key']),
      value: json['value'],
      description: json['description'] is String ? json['description'] as String : null,
      updatedAt: _parseDate(json['updatedAt']),
    );
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    final s = v.toString().trim();
    if (s.isEmpty) return null;
    return DateTime.tryParse(s);
  }
}

class AdminFeatureFlag {
  const AdminFeatureFlag({
    required this.key,
    required this.enabled,
    this.description,
    this.updatedAt,
  });

  final String key;
  final bool enabled;
  final String? description;
  final DateTime? updatedAt;

  static String _str(dynamic v) => (v ?? '').toString().trim();

  factory AdminFeatureFlag.fromJson(Map<String, dynamic> json) {
    return AdminFeatureFlag(
      key: _str(json['key']),
      enabled: json['enabled'] == true,
      description: json['description'] is String ? json['description'] as String : null,
      updatedAt: _parseDate(json['updatedAt']),
    );
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    final s = v.toString().trim();
    if (s.isEmpty) return null;
    return DateTime.tryParse(s);
  }
}

class AdminInstitutionDomain {
  const AdminInstitutionDomain({
    required this.id,
    required this.domain,
    required this.organizationName,
    required this.status,
    required this.requestedBy,
    required this.createdAt,
  });

  final String id;
  final String domain;
  final String organizationName;
  final String status;
  final String requestedBy;
  final DateTime createdAt;

  static String _str(dynamic v) => (v ?? '').toString().trim();

  factory AdminInstitutionDomain.fromJson(Map<String, dynamic> json) {
    return AdminInstitutionDomain(
      id: _str(json['id']),
      domain: _str(json['domain']),
      organizationName: _str(
        json['organizationName'] ?? json['institution']?['name'] ?? json['name'],
      ),
      status: _str(json['status'] ?? 'pending'),
      requestedBy: _str(json['requestedBy'] ?? json['userId']),
      createdAt: _parseDate(json['createdAt']) ?? DateTime.now(),
    );
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    final s = v.toString().trim();
    if (s.isEmpty) return null;
    return DateTime.tryParse(s);
  }
}

extension _LetExt<T> on T {
  R let<R>(R Function(T) block) => block(this);
}

// ─────────────────────────────────────────────────────────────────────────────
// INSTITUTIONS
// ─────────────────────────────────────────────────────────────────────────────

class AdminInstitutionSummary {
  const AdminInstitutionSummary({
    required this.id,
    required this.name,
    required this.slug,
    required this.status,
    required this.createdAt,
    required this.memberCount,
    this.domain,
    this.websiteUrl,
    this.verifiedAt,
    this.suspendedAt,
  });

  final String id;
  final String name;
  final String slug;
  final String status;
  final DateTime createdAt;
  final int memberCount;
  final String? domain;
  final String? websiteUrl;
  final DateTime? verifiedAt;
  final DateTime? suspendedAt;

  static String _str(dynamic v) => (v ?? '').toString().trim();
  static int _int(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse((v ?? '').toString()) ?? 0;
  }

  factory AdminInstitutionSummary.fromJson(Map<String, dynamic> json) {
    final count = json['_count'] is Map<String, dynamic>
        ? json['_count'] as Map<String, dynamic>
        : const <String, dynamic>{};
    return AdminInstitutionSummary(
      id: _str(json['id']),
      name: _str(json['name']),
      slug: _str(json['slug']),
      status: _str(json['status'] ?? 'PENDING'),
      createdAt: _parseDate(json['createdAt']) ?? DateTime.now(),
      memberCount: _int(count['members']),
      domain: _str(json['domain']).let((s) => s.isEmpty ? null : s),
      websiteUrl: _str(json['websiteUrl']).let((s) => s.isEmpty ? null : s),
      verifiedAt: _parseDate(json['verifiedAt']),
      suspendedAt: _parseDate(json['suspendedAt']),
    );
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    final s = v.toString().trim();
    if (s.isEmpty) return null;
    return DateTime.tryParse(s);
  }
}

class AdminVerificationRequest {
  const AdminVerificationRequest({
    required this.id,
    required this.status,
    required this.organizationName,
    required this.createdAt,
    this.domain,
    this.websiteUrl,
    this.workEmail,
    this.requester,
    this.requesterEmail,
    this.institutionSlug,
    this.reviewNotes,
  });

  final String id;
  final String status;
  final String organizationName;
  final DateTime createdAt;
  final String? domain;
  final String? websiteUrl;
  final String? workEmail;
  /// The PERSON who asked for verification. Their work email stays separate:
  /// it is contact state on the request, not part of who they are.
  final AuraPersonIdentity? requester;
  final String? requesterEmail;

  String? get requesterHandle => _orNull(requester?.handle ?? '');
  final String? institutionSlug;
  final String? reviewNotes;

  static String _str(dynamic v) => (v ?? '').toString().trim();

  factory AdminVerificationRequest.fromJson(Map<String, dynamic> json) {
    final req = json['requester'] is Map<String, dynamic>
        ? json['requester'] as Map<String, dynamic>
        : null;
    final inst = json['institution'] is Map<String, dynamic>
        ? json['institution'] as Map<String, dynamic>
        : null;
    return AdminVerificationRequest(
      id: _str(json['id']),
      status: _str(json['status'] ?? 'UNDER_REVIEW'),
      organizationName: _str(json['organizationName']),
      createdAt: _parseDate(json['createdAt']) ?? DateTime.now(),
      domain: _str(json['domain']).let((s) => s.isEmpty ? null : s),
      websiteUrl: _str(json['websiteUrl']).let((s) => s.isEmpty ? null : s),
      workEmail: _str(json['workEmail']).let((s) => s.isEmpty ? null : s),
      requester: req == null ? null : AuraPersonIdentity.fromJson(req),
      requesterEmail: req != null ? _str(req['email']).let((s) => s.isEmpty ? null : s) : null,
      institutionSlug: inst != null ? _str(inst['slug']).let((s) => s.isEmpty ? null : s) : null,
      reviewNotes: _str(json['reviewNotes']).let((s) => s.isEmpty ? null : s),
    );
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    final s = v.toString().trim();
    if (s.isEmpty) return null;
    return DateTime.tryParse(s);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// INSTITUTION MEMBERS
// ─────────────────────────────────────────────────────────────────────────────

/// F116 case 2 — PERSON IDENTITY + LEGITIMATE DESTINATION STATE.
///
/// The membership half (`role`, `title`, `joinedAt`, `canSpeakOfficially`) is
/// this model's own; the person half is COMPOSED rather than re-parsed. The
/// forwarding getters keep every existing consumer working while there is
/// exactly one place that decides what a person's name is.
class AdminInstitutionMember {
  const AdminInstitutionMember({
    required this.id,
    required this.userId,
    required this.role,
    required this.joinedAt,
    this.person = AuraPersonIdentity.unknown,
    this.title,
    this.canSpeakOfficially = false,
  });

  final String id;
  final String userId;
  final String role;
  final DateTime joinedAt;
  final AuraPersonIdentity person;
  final String? title;
  final bool canSpeakOfficially;

  String? get displayName =>
      person.displayName.isEmpty ? null : person.displayName;
  String? get handle => person.handle.isEmpty ? null : person.handle;

  /// AXR-1 identity precedence — verified profile photo when present,
  /// so member rows never fall back to initials unnecessarily.
  String? get avatarUrl => person.avatarUrl;

  static String _str(dynamic v) => (v ?? '').toString().trim();

  factory AdminInstitutionMember.fromJson(Map<String, dynamic> json) {
    final user = json['user'] is Map<String, dynamic>
        ? json['user'] as Map<String, dynamic>
        : null;
    return AdminInstitutionMember(
      id: _str(json['id']),
      userId: _str(json['userId']),
      role: _str(json['role'] ?? 'MEMBER'),
      joinedAt: _parseDate(json['joinedAt']) ?? DateTime.now(),
      person: AuraPersonIdentity.fromJson(user),
      title: _str(json['title']).let((s) => s.isEmpty ? null : s),
      canSpeakOfficially: json['canSpeakOfficially'] == true,
    );
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    final s = v.toString().trim();
    if (s.isEmpty) return null;
    return DateTime.tryParse(s);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// INSTITUTION OWNERSHIP CONTINUITY — emergency recovery operator state
// ─────────────────────────────────────────────────────────────────────────────

/// A member the backend has confirmed is eligible to receive ownership.
/// Never assembled client-side: the candidate set comes from the same
/// eligibility authority the recovery endpoint itself enforces, so this
/// surface cannot offer a choice the backend would reject.
class OwnershipRecoveryCandidate {
  const OwnershipRecoveryCandidate({
    required this.person,
    required this.role,
  });

  /// A candidate is a PERSON holding a membership role. The role is recovery
  /// state; the person is identity.
  final AuraPersonIdentity person;
  final String role;

  String get userId => person.userId;
  String? get displayName => _orNull(person.displayName);
  String? get handle => _orNull(person.handle);
  String? get avatarUrl => person.avatarUrl;

  /// The canonical order, with one governed addition: when a candidate has
  /// neither name nor handle, an ownership-recovery screen must still show
  /// something a governor can act on, so the user id stands in rather than
  /// the neutral word.
  String get label =>
      person.displayName.trim().isEmpty && person.handle.trim().isEmpty
          ? userId
          : person.label;

  static String _str(dynamic v) => (v ?? '').toString().trim();

  factory OwnershipRecoveryCandidate.fromJson(Map<String, dynamic> json) {
    return OwnershipRecoveryCandidate(
      person: AuraPersonIdentity.fromJson(json),
      role: _str(json['role'] ?? 'MEMBER'),
    );
  }
}

/// Whether an institution currently requires governed ownership recovery.
///
/// `recoveryRequired` is derived by the backend from canonical ownership
/// truth (no actionable owner), never persisted as its own state and never
/// inferred here. When false the candidate list is empty by design —
/// ownership changes hands through the owner's own transfer, so there is
/// deliberately no ordinary "choose an owner" affordance.
class InstitutionOwnershipRecoveryState {
  const InstitutionOwnershipRecoveryState({
    required this.recoveryRequired,
    this.ownerOfRecordUserId,
    this.ownerOfRecordLabel,
    this.candidates = const [],
  });

  const InstitutionOwnershipRecoveryState.notRequired()
      : recoveryRequired = false,
        ownerOfRecordUserId = null,
        ownerOfRecordLabel = null,
        candidates = const [];

  final bool recoveryRequired;

  /// The owner still recorded in the database but no longer able to
  /// exercise authority. Null when the institution never had one.
  final String? ownerOfRecordUserId;
  final String? ownerOfRecordLabel;
  final List<OwnershipRecoveryCandidate> candidates;

  factory InstitutionOwnershipRecoveryState.fromJson(Map<String, dynamic> json) {
    if (json['recoveryRequired'] != true) {
      return const InstitutionOwnershipRecoveryState.notRequired();
    }

    final ownerOfRecord = json['ownerOfRecord'];
    String? ownerId;
    String? ownerLabel;
    if (ownerOfRecord is Map) {
      final map = Map<String, dynamic>.from(ownerOfRecord);
      final owner = AuraPersonIdentity.fromJson(map);
      final id = (map['userId'] ?? '').toString().trim();
      ownerId = id.isEmpty ? null : id;
      // Same governed exception as the candidate label above: an owner with
      // no name and no handle is still identified for a governor by id.
      ownerLabel =
          owner.displayName.trim().isEmpty && owner.handle.trim().isEmpty
              ? ownerId
              : owner.label;
    }

    final rawCandidates = json['candidates'];
    return InstitutionOwnershipRecoveryState(
      recoveryRequired: true,
      ownerOfRecordUserId: ownerId,
      ownerOfRecordLabel: ownerLabel,
      candidates: rawCandidates is List
          ? rawCandidates
              .whereType<Map>()
              .map((e) => OwnershipRecoveryCandidate.fromJson(
                    Map<String, dynamic>.from(e),
                  ))
              .toList()
          : const [],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// REVIEW QUEUE
// ─────────────────────────────────────────────────────────────────────────────

class ReviewQueueItem {
  const ReviewQueueItem({
    required this.id,
    required this.type,
    required this.entityId,
    required this.title,
    required this.subtitle,
    required this.createdBy,
    required this.createdAt,
    required this.status,
    required this.emailMatched,
    required this.dnsVerified,
    required this.meta,
  });

  /// institution_create | institution_claim | member_join
  final String type;
  final String id;
  final String entityId;
  final String title;
  final String subtitle;
  final String createdBy;
  final DateTime createdAt;

  /// pending | provisional_active | active | rejected
  final String status;
  final bool emailMatched;
  final bool dnsVerified;
  final Map<String, dynamic> meta;

  static String _str(dynamic v) => (v ?? '').toString().trim();

  factory ReviewQueueItem.fromJson(Map<String, dynamic> json) {
    final verification = json['verification'] is Map<String, dynamic>
        ? json['verification'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final meta = json['meta'] is Map<String, dynamic>
        ? json['meta'] as Map<String, dynamic>
        : const <String, dynamic>{};
    return ReviewQueueItem(
      id: _str(json['id']),
      type: _str(json['type']),
      entityId: _str(json['entityId'] ?? json['entity_id']),
      title: _str(json['title']),
      subtitle: _str(json['subtitle']),
      createdBy: _str(json['createdBy'] ?? json['created_by']),
      createdAt: _parseDate(json['createdAt'] ?? json['created_at']) ?? DateTime.now(),
      status: _str(json['status'] ?? 'pending'),
      emailMatched: verification['emailMatched'] == true,
      dnsVerified: verification['dnsVerified'] == true,
      meta: meta,
    );
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    final s = v.toString().trim();
    if (s.isEmpty) return null;
    return DateTime.tryParse(s);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// POLICIES
// ─────────────────────────────────────────────────────────────────────────────

class AdminPolicy {
  const AdminPolicy({
    required this.institution,
    required this.security,
    required this.communications,
    required this.feature,
  });

  final InstitutionPolicy institution;
  final SecurityPolicy security;
  final CommunicationsPolicy communications;
  final FeaturePolicy feature;

  static const AdminPolicy defaults = AdminPolicy(
    institution: InstitutionPolicy.defaults,
    security: SecurityPolicy.defaults,
    communications: CommunicationsPolicy.defaults,
    feature: FeaturePolicy.defaults,
  );

  factory AdminPolicy.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> sub(String key) {
      final raw = json[key] ?? json['data']?[key];
      if (raw is Map<String, dynamic>) return raw;
      if (raw is Map) return Map<String, dynamic>.from(raw);
      return const {};
    }

    return AdminPolicy(
      institution: InstitutionPolicy.fromJson(sub('institutionPolicy')),
      security: SecurityPolicy.fromJson(sub('securityPolicy')),
      communications: CommunicationsPolicy.fromJson(sub('communicationsPolicy')),
      feature: FeaturePolicy.fromJson(sub('featurePolicy')),
    );
  }

  Map<String, dynamic> toJson() => {
        'institutionPolicy': institution.toJson(),
        'securityPolicy': security.toJson(),
        'communicationsPolicy': communications.toJson(),
        'featurePolicy': feature.toJson(),
      };
}

class InstitutionPolicy {
  const InstitutionPolicy({
    required this.requireEmailVerification,
    required this.requireDnsVerification,
    required this.allowProvisionalActive,
    required this.autoApproveVerified,
    required this.allowedDomains,
    required this.blockedDomains,
  });

  static const InstitutionPolicy defaults = InstitutionPolicy(
    requireEmailVerification: true,
    requireDnsVerification: false,
    allowProvisionalActive: true,
    autoApproveVerified: false,
    allowedDomains: [],
    blockedDomains: [],
  );

  final bool requireEmailVerification;
  final bool requireDnsVerification;
  final bool allowProvisionalActive;
  final bool autoApproveVerified;
  final List<String> allowedDomains;
  final List<String> blockedDomains;

  static String _str(dynamic v) => (v ?? '').toString().trim();
  static List<String> _strList(dynamic v) {
    if (v is List) return v.map((e) => _str(e)).where((e) => e.isNotEmpty).toList();
    return const [];
  }

  factory InstitutionPolicy.fromJson(Map<String, dynamic> json) {
    return InstitutionPolicy(
      requireEmailVerification: json['requireEmailVerification'] != false,
      requireDnsVerification: json['requireDnsVerification'] == true,
      allowProvisionalActive: json['allowProvisionalActive'] != false,
      autoApproveVerified: json['autoApproveVerified'] == true,
      allowedDomains: _strList(json['allowedDomains']),
      blockedDomains: _strList(json['blockedDomains']),
    );
  }

  Map<String, dynamic> toJson() => {
        'requireEmailVerification': requireEmailVerification,
        'requireDnsVerification': requireDnsVerification,
        'allowProvisionalActive': allowProvisionalActive,
        'autoApproveVerified': autoApproveVerified,
        'allowedDomains': allowedDomains,
        'blockedDomains': blockedDomains,
      };

  InstitutionPolicy copyWith({
    bool? requireEmailVerification,
    bool? requireDnsVerification,
    bool? allowProvisionalActive,
    bool? autoApproveVerified,
  }) =>
      InstitutionPolicy(
        requireEmailVerification:
            requireEmailVerification ?? this.requireEmailVerification,
        requireDnsVerification:
            requireDnsVerification ?? this.requireDnsVerification,
        allowProvisionalActive:
            allowProvisionalActive ?? this.allowProvisionalActive,
        autoApproveVerified: autoApproveVerified ?? this.autoApproveVerified,
        allowedDomains: allowedDomains,
        blockedDomains: blockedDomains,
      );
}

class SecurityPolicy {
  const SecurityPolicy({
    required this.maxLoginAttempts,
    required this.sessionTimeoutMinutes,
    required this.requireMfa,
  });

  static const SecurityPolicy defaults = SecurityPolicy(
    maxLoginAttempts: 5,
    sessionTimeoutMinutes: 1440,
    requireMfa: false,
  );

  final int maxLoginAttempts;
  final int sessionTimeoutMinutes;
  final bool requireMfa;

  static int _int(dynamic v, int fallback) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse((v ?? '').toString()) ?? fallback;
  }

  factory SecurityPolicy.fromJson(Map<String, dynamic> json) {
    return SecurityPolicy(
      maxLoginAttempts: _int(json['maxLoginAttempts'], 5),
      sessionTimeoutMinutes: _int(json['sessionTimeoutMinutes'], 1440),
      requireMfa: json['requireMfa'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'maxLoginAttempts': maxLoginAttempts,
        'sessionTimeoutMinutes': sessionTimeoutMinutes,
        'requireMfa': requireMfa,
      };

  SecurityPolicy copyWith({
    int? maxLoginAttempts,
    int? sessionTimeoutMinutes,
    bool? requireMfa,
  }) =>
      SecurityPolicy(
        maxLoginAttempts: maxLoginAttempts ?? this.maxLoginAttempts,
        sessionTimeoutMinutes:
            sessionTimeoutMinutes ?? this.sessionTimeoutMinutes,
        requireMfa: requireMfa ?? this.requireMfa,
      );
}

class CommunicationsPolicy {
  const CommunicationsPolicy({
    required this.maxEmailsPerDay,
    required this.digestEnabled,
    required this.digestFrequency,
    required this.unsubscribeEnabled,
    required this.senderEmail,
  });

  static const CommunicationsPolicy defaults = CommunicationsPolicy(
    maxEmailsPerDay: 10,
    digestEnabled: true,
    digestFrequency: 'daily',
    unsubscribeEnabled: true,
    senderEmail: '',
  );

  final int maxEmailsPerDay;
  final bool digestEnabled;
  final String digestFrequency;
  final bool unsubscribeEnabled;
  final String senderEmail;

  static int _int(dynamic v, int fallback) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse((v ?? '').toString()) ?? fallback;
  }

  static String _str(dynamic v) => (v ?? '').toString().trim();

  factory CommunicationsPolicy.fromJson(Map<String, dynamic> json) {
    return CommunicationsPolicy(
      maxEmailsPerDay: _int(json['maxEmailsPerDay'], 10),
      digestEnabled: json['digestEnabled'] != false,
      digestFrequency: _str(json['digestFrequency']).let(
        (s) => s.isEmpty ? 'daily' : s,
      ),
      unsubscribeEnabled: json['unsubscribeEnabled'] != false,
      senderEmail: _str(json['senderEmail']),
    );
  }

  Map<String, dynamic> toJson() => {
        'maxEmailsPerDay': maxEmailsPerDay,
        'digestEnabled': digestEnabled,
        'digestFrequency': digestFrequency,
        'unsubscribeEnabled': unsubscribeEnabled,
        'senderEmail': senderEmail,
      };

  CommunicationsPolicy copyWith({
    int? maxEmailsPerDay,
    bool? digestEnabled,
    String? digestFrequency,
    bool? unsubscribeEnabled,
    String? senderEmail,
  }) =>
      CommunicationsPolicy(
        maxEmailsPerDay: maxEmailsPerDay ?? this.maxEmailsPerDay,
        digestEnabled: digestEnabled ?? this.digestEnabled,
        digestFrequency: digestFrequency ?? this.digestFrequency,
        unsubscribeEnabled: unsubscribeEnabled ?? this.unsubscribeEnabled,
        senderEmail: senderEmail ?? this.senderEmail,
      );
}

class FeaturePolicy {
  const FeaturePolicy({
    required this.betaOptInEnabled,
    required this.maintenanceMode,
    required this.publicRegistrationEnabled,
    required this.inviteOnlyMode,
  });

  static const FeaturePolicy defaults = FeaturePolicy(
    betaOptInEnabled: true,
    maintenanceMode: false,
    publicRegistrationEnabled: true,
    inviteOnlyMode: false,
  );

  final bool betaOptInEnabled;
  final bool maintenanceMode;
  final bool publicRegistrationEnabled;
  final bool inviteOnlyMode;

  factory FeaturePolicy.fromJson(Map<String, dynamic> json) {
    return FeaturePolicy(
      betaOptInEnabled: json['betaOptInEnabled'] != false,
      maintenanceMode: json['maintenanceMode'] == true,
      publicRegistrationEnabled: json['publicRegistrationEnabled'] != false,
      inviteOnlyMode: json['inviteOnlyMode'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'betaOptInEnabled': betaOptInEnabled,
        'maintenanceMode': maintenanceMode,
        'publicRegistrationEnabled': publicRegistrationEnabled,
        'inviteOnlyMode': inviteOnlyMode,
      };

  FeaturePolicy copyWith({
    bool? betaOptInEnabled,
    bool? maintenanceMode,
    bool? publicRegistrationEnabled,
    bool? inviteOnlyMode,
  }) =>
      FeaturePolicy(
        betaOptInEnabled: betaOptInEnabled ?? this.betaOptInEnabled,
        maintenanceMode: maintenanceMode ?? this.maintenanceMode,
        publicRegistrationEnabled:
            publicRegistrationEnabled ?? this.publicRegistrationEnabled,
        inviteOnlyMode: inviteOnlyMode ?? this.inviteOnlyMode,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// MODERATION
// ─────────────────────────────────────────────────────────────────────────────

// F116 case 1 — RENAMED PERSON REFERENCE SUBSET, RETIRED.
//
// `ModerationActorSummary` was id + handle + displayName + avatarUrl with its
// own private fallback (`displayName ?? handle`) — the canonical person
// reference under a different name, with a competing fallback rule. It is
// gone; moderation actors are `AuraPersonIdentity` like everyone else.

class ModerationReportAction {
  const ModerationReportAction({
    required this.id,
    required this.actionType,
    required this.targetType,
    required this.targetId,
    required this.moderator,
    required this.createdAt,
    this.note,
  });

  final String id;
  final String actionType;
  final String targetType;
  final String targetId;
  final AuraPersonIdentity moderator;
  final DateTime createdAt;
  final String? note;

  static String _str(dynamic v) => (v ?? '').toString().trim();

  factory ModerationReportAction.fromJson(Map<String, dynamic> json) {
    return ModerationReportAction(
      id: _str(json['id']),
      actionType: _str(json['actionType']),
      targetType: _str(json['targetType']),
      targetId: _str(json['targetId']),
      moderator: AuraPersonIdentity.fromJson(
        json['moderator'] is Map
            ? Map<String, dynamic>.from(json['moderator'] as Map)
            : const {},
      ),
      createdAt: DateTime.tryParse(_str(json['createdAt'])) ?? DateTime.now(),
      note: json['note'] as String?,
    );
  }
}

class ModerationReport {
  const ModerationReport({
    required this.id,
    required this.targetType,
    required this.targetId,
    required this.reporter,
    required this.reason,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.actions,
    this.details,
    this.outcomeSummary,
    this.privateNote,
  });

  final String id;
  final String targetType;
  final String targetId;
  final AuraPersonIdentity reporter;
  final String reason;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ModerationReportAction> actions;
  final String? details;
  final String? outcomeSummary;
  final String? privateNote;

  static String _str(dynamic v) => (v ?? '').toString().trim();

  factory ModerationReport.fromJson(Map<String, dynamic> json) {
    final actions = json['actions'];
    return ModerationReport(
      id: _str(json['id']),
      targetType: _str(json['targetType']),
      targetId: _str(json['targetId']),
      reporter: AuraPersonIdentity.fromJson(
        json['reporter'] is Map
            ? Map<String, dynamic>.from(json['reporter'] as Map)
            : const {},
      ),
      reason: _str(json['reason']),
      status: _str(json['status'] ?? 'OPEN'),
      createdAt: DateTime.tryParse(_str(json['createdAt'])) ?? DateTime.now(),
      updatedAt: DateTime.tryParse(_str(json['updatedAt'])) ?? DateTime.now(),
      actions: actions is List
          ? actions
              .whereType<Map>()
              .map((e) => ModerationReportAction.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
      details: json['details'] as String?,
      outcomeSummary: json['outcomeSummary'] as String?,
      privateNote: json['privateNote'] as String?,
    );
  }
}

/// C2 — Person Verification administration (layered taxonomy, full
/// governed record). Admin is the one audience for whom REVOKED/EXPIRED
/// history is first-class: it is never flattened into "not verified".
class AdminPersonVerificationRecord {
  const AdminPersonVerificationRecord({
    required this.verificationClass,
    required this.state,
    required this.reason,
    this.classSubtype,
    this.issuingAuthority,
    this.issuingInstitutionId,
    this.grantedAt,
    this.expiresAt,
    this.revokedAt,
    this.revocationReason,
  });

  final String verificationClass;
  final String state;
  final String reason;
  final String? classSubtype;
  final String? issuingAuthority;
  final String? issuingInstitutionId;
  final DateTime? grantedAt;
  final DateTime? expiresAt;
  final DateTime? revokedAt;
  final String? revocationReason;

  static String _str(dynamic v) => (v ?? '').toString().trim();

  static String? _opt(dynamic v) {
    final s = _str(v);
    return s.isEmpty ? null : s;
  }

  static DateTime? _date(dynamic v) =>
      v == null ? null : DateTime.tryParse(v.toString());

  factory AdminPersonVerificationRecord.fromJson(Map<String, dynamic> json) {
    return AdminPersonVerificationRecord(
      verificationClass: _str(json['verificationClass']),
      state: _str(json['state']),
      reason: _str(json['reason']),
      classSubtype: _opt(json['classSubtype']),
      issuingAuthority: _opt(json['issuingAuthority']),
      issuingInstitutionId: _opt(json['issuingInstitutionId']),
      grantedAt: _date(json['grantedAt']),
      expiresAt: _date(json['expiresAt']),
      revokedAt: _date(json['revokedAt']),
      revocationReason: _opt(json['revocationReason']),
    );
  }
}

class AdminPersonVerification {
  const AdminPersonVerification({
    required this.activeClasses,
    required this.history,
  });

  final List<String> activeClasses;
  final List<AdminPersonVerificationRecord> history;

  factory AdminPersonVerification.fromJson(Map<String, dynamic> json) {
    final active = <String>[
      for (final c in (json['activeClasses'] as List? ?? const []))
        (c ?? '').toString().trim(),
    ]..removeWhere((c) => c.isEmpty);
    final history = <AdminPersonVerificationRecord>[
      for (final row in (json['history'] as List? ?? const []))
        if (row is Map)
          AdminPersonVerificationRecord.fromJson(
            Map<String, dynamic>.from(row),
          ),
    ];
    return AdminPersonVerification(activeClasses: active, history: history);
  }
}

String? _orNull(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
