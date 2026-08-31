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
    this.userId = '',
    this.granteeHandle = '',
    this.granteeDisplayName = '',
    this.reason = '',
  });

  final String id;
  final String role;
  final List<String> permissions;
  final bool active;
  final String grantedBy;
  final DateTime createdAt;
  final DateTime? expiresAt;

  /// WHO HOLDS THIS. The server has always sent it — `mapGrant` returns
  /// `userId` and the whole `user` record — and this model dropped it, which
  /// is why a grant could only ever be shown in one undifferentiated list and
  /// never on the person it is about.
  final String userId;
  final String granteeHandle;
  final String granteeDisplayName;

  /// Why it was issued. Recorded at grant time and never shown until now.
  final String reason;

  /// How to name the holder. Falls back through what the server sent rather
  /// than printing an opaque id at someone.
  String get granteeLabel {
    if (granteeDisplayName.isNotEmpty) return granteeDisplayName;
    if (granteeHandle.isNotEmpty) return '@$granteeHandle';
    return userId.isEmpty ? 'Unknown holder' : userId;
  }

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
      active: json['active'] == true ||
          _str(json['status']).toUpperCase() == 'ACTIVE',
      // `grantedBy` is an OBJECT on the wire (id/handle/displayName) with
      // `grantedByUserId` beside it. Stringifying the map produced the
      // unreadable `{id: ..., handle: ...}` this now avoids.
      grantedBy: _grantedByLabel(json),
      createdAt: _parseDate(json['grantedAt'] ?? json['createdAt']) ??
          DateTime.now(),
      expiresAt: _parseDate(json['expiresAt']),
      userId: _str(json['userId'] ?? (json['user'] is Map
          ? (json['user'] as Map)['id']
          : null)),
      granteeHandle: _personField(json['user'], 'handle'),
      granteeDisplayName: _personField(json['user'], 'displayName'),
      reason: _str(json['reason']),
    );
  }

  static String _personField(dynamic person, String field) =>
      person is Map ? _str(person[field]) : '';

  static String _grantedByLabel(Map<String, dynamic> json) {
    final by = json['grantedBy'];
    if (by is Map) {
      final name = _str(by['displayName']);
      if (name.isNotEmpty) return name;
      final handle = _str(by['handle']);
      if (handle.isNotEmpty) return '@$handle';
      return _str(by['id']);
    }
    return _str(by ?? json['grantedByUserId'] ?? json['ownerId']);
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

  /// The OPERATOR authority this person holds over Aura, or empty.
  ///
  /// FOUND BY THE CONTRACT, NOT BY READING THE CODE. This was parsed from a
  /// top-level `role` key the server has never sent — it sends
  /// `admin.roles: ['OWNER']` — so the directory's authority column was ALWAYS
  /// empty in production. The hand-written fixture that proved this screen
  /// carried a `role` of `MEMBER`, which made the column look populated AND
  /// invented a platform role that does not exist: OWNER, ADMIN and MODERATOR
  /// are Aura's operator roles, and MEMBER belongs to institution membership,
  /// a different authority entirely.
  ///
  /// Empty is the correct answer for almost everybody, and the directory says
  /// nothing rather than inventing a rank.
  final String role;

  final String status;
  final DateTime createdAt;
  final DateTime? lastActiveAt;

  /// True when this person can act on Aura itself.
  bool get isOperator => role.isNotEmpty;

  bool get isDisabled => status.toUpperCase() == 'DISABLED';

  static String _str(dynamic v) => (v ?? '').toString().trim();

  /// The highest operator role held, from the server's own list.
  ///
  /// Ordered by authority rather than alphabetically: a person holding both
  /// MODERATOR and OWNER is an owner, and a directory that showed the other
  /// one would understate what they may do.
  static String _operatorRole(dynamic adminBlock) {
    if (adminBlock is! Map) return '';
    final roles = adminBlock['roles'];
    if (roles is! List || roles.isEmpty) return '';
    final held = roles.map((r) => _str(r).toUpperCase()).toSet();
    for (final rank in const ['OWNER', 'ADMIN', 'MODERATOR']) {
      if (held.contains(rank)) return rank;
    }
    // A role this build does not rank is still real. Shown as sent rather
    // than dropped, because an unrecognised authority is not no authority.
    return _str(roles.first).toUpperCase();
  }

  factory AdminUserSummary.fromJson(Map<String, dynamic> json) {
    return AdminUserSummary(
      person: AuraPersonIdentity.fromJson(json),
      email: _str(json['email']),
      role: _operatorRole(json['admin']),
      // The server's word, uppercase. The old default was lowercase 'active',
      // which never matched anything it was compared against.
      status: _str(json['status']).isEmpty
          ? 'ACTIVE'
          : _str(json['status']).toUpperCase(),
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

/// WHAT THE ACTION WAS TAKEN AGAINST, as the record can name it.
///
/// The audit row stores a type word and a cuid. Rendered raw, the record read
/// `USER · cmm69u97n0000pi01rm3fyglq` — which answers "to whom" only for
/// somebody who recognises database ids, and the record exists precisely for
/// the people who were not there.
///
/// The server resolves the two subject classes the console navigates to. This
/// carries the answer WITHOUT ever manufacturing one: [resolvable] false is a
/// real answer for a target class that is not a subject, and for a subject
/// that has since been deleted.
class AdminAuditSubject {
  const AdminAuditSubject({
    required this.kind,
    required this.type,
    this.id,
    this.label,
    this.handle,
    this.resolvable = false,
  });

  /// PERSON, INSTITUTION, or REFERENCE.
  final String kind;

  /// The stored type word, verbatim — the record is not rewritten.
  final String type;

  final String? id;
  final String? label;
  final String? handle;
  final bool resolvable;

  bool get isPerson => kind == 'PERSON';
  bool get isInstitution => kind == 'INSTITUTION';

  /// True when this subject has a page an operator can open.
  bool get navigable => resolvable && (id ?? '').isNotEmpty;

  /// How the row names it. Never an id when a name exists; never a name
  /// when one does not.
  String get display {
    final named = (label ?? '').trim();
    if (named.isNotEmpty) return named;
    final reference = (id ?? '').trim();
    if (reference.isEmpty) return _humanType(type);
    return '${_humanType(type)} · $reference';
  }

  /// A qualifier the operator reads under the name — never instead of it.
  String? get qualifier {
    final h = (handle ?? '').trim();
    if (h.isEmpty) return null;
    return isPerson ? '@$h' : h;
  }

  static String _humanType(String type) {
    final t = type.trim();
    if (t.isEmpty) return 'Subject';
    // `INSTITUTION_VERIFICATION_REQUEST` is a schema word, not a sentence.
    final words = t.replaceAll('_', ' ').toLowerCase();
    return words[0].toUpperCase() + words.substring(1);
  }

  static AdminAuditSubject fromJson(dynamic value, {required String fallbackType, String? fallbackId}) {
    if (value is Map<String, dynamic>) {
      String? str(String key) {
        final v = value[key];
        if (v == null) return null;
        final s = v.toString().trim();
        return s.isEmpty ? null : s;
      }

      return AdminAuditSubject(
        kind: str('kind') ?? 'REFERENCE',
        type: str('type') ?? fallbackType,
        id: str('id') ?? fallbackId,
        label: str('label'),
        handle: str('handle'),
        resolvable: value['resolvable'] == true,
      );
    }
    // A BUILD TALKING TO AN OLDER SERVER still shows the reference rather
    // than nothing. It never claims a name it was not given.
    return AdminAuditSubject(
      kind: 'REFERENCE',
      type: fallbackType,
      id: fallbackId,
    );
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
    required this.subject,
    this.actorName = '',
    this.actorHandle = '',
    this.result = '',
    this.reason = '',
    this.targetId,
    this.metadata,
  });

  final String id;
  final String action;

  /// The acting operator's id. Read from `actorUserId` as well as `actorId`:
  /// the endpoint returns the Prisma row, whose column is `actorUserId`, and
  /// reading only the latter meant this was ALWAYS empty — so a record with no
  /// actor email showed no actor at all.
  final String actorId;

  final String actorEmail;
  final String actorName;
  final String actorHandle;
  final String targetType;
  final DateTime createdAt;

  /// SUCCESS or FAILED. A record that shows only attempts is not a record of
  /// what happened.
  final String result;

  /// Why the operator said they did it, when the act required one.
  final String reason;

  final String? targetId;
  final Map<String, dynamic>? metadata;

  /// The affected subject, named where the server could name it.
  final AdminAuditSubject subject;

  /// WHO, as a person is named. An audit row that identifies an operator only
  /// by an email address makes the record harder to read than it needs to be,
  /// and shows nothing at all when the relation is absent.
  String get actorLabel {
    if (actorName.isNotEmpty) return actorName;
    if (actorHandle.isNotEmpty) return '@$actorHandle';
    if (actorEmail.isNotEmpty) return actorEmail;
    return actorId.isEmpty ? 'Aura itself' : actorId;
  }

  bool get failed => result.toUpperCase() == 'FAILED';

  static String _str(dynamic v) => (v ?? '').toString().trim();

  static String _actor(Map<String, dynamic> json, String field) {
    final actor = json['actor'];
    return actor is Map ? _str(actor[field]) : '';
  }

  factory AdminAuditLogEntry.fromJson(Map<String, dynamic> json) {
    return AdminAuditLogEntry(
      id: _str(json['id']),
      action: _str(json['action']),
      actorId: _str(json['actorUserId'] ?? json['actorId']),
      actorEmail: _str(json['actorEmail']).isEmpty
          ? _actor(json, 'email')
          : _str(json['actorEmail']),
      actorName: _actor(json, 'displayName'),
      actorHandle: _actor(json, 'handle'),
      targetType: _str(json['targetType'] ?? json['resourceType']),
      targetId: _str(json['targetId'] ?? json['resourceId']).let((s) => s.isEmpty ? null : s),
      result: _str(json['result']),
      reason: _str(json['reason']),
      createdAt: _parseDate(json['createdAt']) ?? DateTime.now(),
      metadata: json['metadata'] is Map<String, dynamic>
          ? json['metadata'] as Map<String, dynamic>
          : null,
      subject: AdminAuditSubject.fromJson(
        json['subject'],
        fallbackType: _str(json['targetType'] ?? json['resourceType']),
        fallbackId: _str(json['targetId'] ?? json['resourceId'])
            .let((s) => s.isEmpty ? null : s),
      ),
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
    this.institutionId = '',
  });

  /// The DOMAIN RECORD's id — what the approve and reject endpoints address.
  final String id;

  /// WHICH INSTITUTION this proof belongs to. The server has always sent it
  /// (`institutionId`, plus the whole `institution` object) and this model
  /// dropped it, so nothing could ask which institution a proof was for.
  final String institutionId;

  final String domain;
  final String organizationName;
  final String status;
  final String requestedBy;
  final DateTime createdAt;

  bool get isPending => status.toUpperCase() == 'PENDING';

  static String _str(dynamic v) => (v ?? '').toString().trim();

  factory AdminInstitutionDomain.fromJson(Map<String, dynamic> json) {
    return AdminInstitutionDomain(
      id: _str(json['id']),
      institutionId: _str(
        json['institutionId'] ??
            (json['institution'] is Map
                ? (json['institution'] as Map)['id']
                : null),
      ),
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
      // TWO ENDPOINTS, TWO SHAPES, ONE SUBJECT.
      //
      // The directory sends `_count.members` (the raw Prisma aggregate); the
      // by-id read sends `memberCount` (through `formatInstitution`). Reading
      // only one of them made an institution opened directly report zero
      // members while the same institution in the list reported five.
      //
      // Both are read, and neither is preferred over a present value — the
      // absent one is what is skipped, not the smaller one.
      memberCount: json['memberCount'] != null
          ? _int(json['memberCount'])
          : _int(count['members']),
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

  /// The whole document with one family replaced.
  ///
  /// `PUT /v1/admin/policies` takes the WHOLE policy, so changing one switch
  /// means sending the other three families back exactly as they were. A
  /// partial body would silently reset its siblings to their defaults, which
  /// is the kind of change nobody notices until something it governs stops
  /// happening.
  AdminPolicy copyWith({
    InstitutionPolicy? institution,
    SecurityPolicy? security,
    CommunicationsPolicy? communications,
    FeaturePolicy? feature,
  }) =>
      AdminPolicy(
        institution: institution ?? this.institution,
        security: security ?? this.security,
        communications: communications ?? this.communications,
        feature: feature ?? this.feature,
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

/// THE THING UNDER JUDGEMENT.
///
/// A report used to reach the operator as "Reported post" plus a cuid. The
/// operator was asked whether Aura should act against content they had never
/// been shown. This carries the evidence the server resolved — and, just as
/// importantly, its absence, honestly:
///
///   * [exists] false — the target is gone. The reference is all there is.
///   * [removedAt] set — it existed and was removed. NO excerpt is served:
///     re-showing deleted words to the one audience that can act on them
///     would quietly undo the deletion.
///   * [excerpt] null on a person or a place — there is nothing to quote, and
///     an empty quotation block would imply there was.
class ModerationSubject {
  const ModerationSubject({
    required this.type,
    required this.id,
    required this.kind,
    required this.exists,
    this.label,
    this.author,
    this.excerpt,
    this.excerptTruncated = false,
    this.createdAt,
    this.removedAt,
  });

  final String type;
  final String id;

  /// PERSON, CONTENT, PLACE or INSTITUTION — what an operator calls it.
  final String kind;

  final bool exists;
  final String? label;

  /// Who is answerable. For a reported person, themselves.
  final AuraPersonIdentity? author;

  final String? excerpt;
  final bool excerptTruncated;
  final DateTime? createdAt;
  final DateTime? removedAt;

  bool get isPerson => kind == 'PERSON';
  bool get isContent => kind == 'CONTENT';
  bool get wasRemoved => removedAt != null;

  /// True when there is something to read. Distinct from [exists]: a place
  /// exists and has no text, and a removed post exists and withholds it.
  bool get hasEvidence => (excerpt ?? '').trim().isNotEmpty;

  /// The single sentence that explains an empty evidence panel. Null when
  /// there is evidence — the panel then speaks for itself.
  String? get absenceSentence {
    if (hasEvidence) return null;
    if (!exists) {
      return 'The reported $_noun no longer exists. Nothing can be shown, and '
          'nothing has been reconstructed.';
    }
    if (wasRemoved) {
      return 'This was removed before the report was judged. Aura does not '
          're-serve deleted content, including here.';
    }
    if (isPerson) {
      return 'A person was reported, not something they wrote. The judgement '
          'is about the account itself.';
    }
    return 'This $_noun carries no text to quote.';
  }

  String get _noun => switch (kind) {
        'PERSON' => 'person',
        'PLACE' => 'place',
        'INSTITUTION' => 'institution',
        _ => 'content',
      };

  static String _str(dynamic v) => (v ?? '').toString().trim();

  static ModerationSubject fromJson(
    dynamic value, {
    required String fallbackType,
    required String fallbackId,
  }) {
    if (value is! Map) {
      // AN OLDER SERVER. The reference is shown; evidence is never invented.
      return ModerationSubject(
        type: fallbackType,
        id: fallbackId,
        kind: 'CONTENT',
        exists: false,
      );
    }
    final map = Map<String, dynamic>.from(value);
    final author = map['author'];
    return ModerationSubject(
      type: _str(map['type']).isEmpty ? fallbackType : _str(map['type']),
      id: _str(map['id']).isEmpty ? fallbackId : _str(map['id']),
      kind: _str(map['kind']).isEmpty ? 'CONTENT' : _str(map['kind']),
      exists: map['exists'] == true,
      label: _str(map['label']).let((s) => s.isEmpty ? null : s),
      author: author is Map
          ? AuraPersonIdentity.fromJson(Map<String, dynamic>.from(author))
          : null,
      excerpt: _str(map['excerpt']).let((s) => s.isEmpty ? null : s),
      excerptTruncated: map['excerptTruncated'] == true,
      createdAt: DateTime.tryParse(_str(map['createdAt'])),
      removedAt: DateTime.tryParse(_str(map['removedAt'])),
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
    required this.subject,
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

  /// What was reported, resolved into evidence.
  final ModerationSubject subject;

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
      subject: ModerationSubject.fromJson(
        json['subject'],
        fallbackType: _str(json['targetType']),
        fallbackId: _str(json['targetId']),
      ),
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

/// Reconciliation evidence for the DirectThread -> Conversation convergence.
///
/// This exists as an in-product surface for one concrete reason: the report is
/// Bearer-guarded, so opening the API URL in a browser sends only the HttpOnly
/// refresh cookie and returns UNAUTHORIZED. Evidence that can only be reached
/// by a raw URL is evidence nobody can actually check.
class AdminConvergenceReport {
  const AdminConvergenceReport({
    required this.migrated,
    this.reason,
    this.sourceThreads = 0,
    this.auditedThreads = 0,
    this.destinationCreated = 0,
    this.destinationMergedIntoExisting = 0,
    this.legacyMessages = 0,
    this.migratedMessages = 0,
    this.unreconciledThreads = 0,
    this.institutionSideReadStateDropped = 0,
    this.skippedThreads = 0,
    this.migrationFinishedAt,
    this.legacyMessagesNotConverged = 0,
    this.legacyCursorsMovedSinceMigration = 0,
  });

  final bool migrated;
  final String? reason;
  final int sourceThreads;
  final int auditedThreads;
  final int destinationCreated;
  final int destinationMergedIntoExisting;
  final int legacyMessages;
  final int migratedMessages;
  final int unreconciledThreads;
  final int institutionSideReadStateDropped;
  final int skippedThreads;
  final DateTime? migrationFinishedAt;
  final int legacyMessagesNotConverged;
  final int legacyCursorsMovedSinceMigration;

  /// The migration was complete WHEN IT RAN.
  bool get auditClean => unreconciledThreads == 0 && skippedThreads == 0;

  /// The two systems agree RIGHT NOW. Strictly stronger than [auditClean], and
  /// the condition a cutover actually depends on: a point-in-time audit decays
  /// while the legacy writer is still live.
  bool get cutoverReady =>
      auditClean &&
      legacyMessagesNotConverged == 0 &&
      legacyCursorsMovedSinceMigration == 0;

  factory AdminConvergenceReport.fromJson(Map<String, dynamic> json) {
    int i(String k) => (json[k] as num?)?.toInt() ?? 0;
    final finished = json['migrationFinishedAt']?.toString();
    return AdminConvergenceReport(
      migrated: json['migrated'] == true,
      reason: json['reason'] == null ? null : _orNull(json['reason'].toString()),
      sourceThreads: i('sourceThreads'),
      auditedThreads: i('auditedThreads'),
      destinationCreated: i('destinationCreated'),
      destinationMergedIntoExisting: i('destinationMergedIntoExisting'),
      legacyMessages: i('legacyMessages'),
      migratedMessages: i('migratedMessages'),
      unreconciledThreads: i('unreconciledThreads'),
      institutionSideReadStateDropped: i('institutionSideReadStateDropped'),
      skippedThreads: i('skippedThreads'),
      migrationFinishedAt:
          finished == null || finished.isEmpty ? null : DateTime.tryParse(finished),
      legacyMessagesNotConverged: i('legacyMessagesNotConverged'),
      legacyCursorsMovedSinceMigration: i('legacyCursorsMovedSinceMigration'),
    );
  }
}

/// ONE PERSON, WHOLE.
///
/// `GET /v1/admin/users/:id` has always returned identity, account standing,
/// every admin grant, the device fleet and the recent push record in a single
/// response. Nothing in the client called it: the old console understood a
/// person only as a row in `/admin/users`, so account standing, operator
/// authority and delivery trouble were three screens that never met.
class AdminPersonDetail {
  const AdminPersonDetail({
    required this.person,
    required this.email,
    required this.status,
    required this.accountType,
    required this.createdAt,
    required this.grants,
    required this.roles,
    required this.permissions,
    required this.devices,
    required this.counts,
    this.otherOwnerHolders,
    this.emailVerifiedAt,
    this.disabledAt,
    this.city,
    this.country,
  });

  final AuraPersonIdentity person;
  final String email;

  /// The server's own word: ACTIVE or DISABLED. Never recomputed here — a
  /// second opinion about whether an account is disabled is a second answer.
  final String status;

  final String accountType;
  final DateTime createdAt;
  final DateTime? emailVerifiedAt;
  final DateTime? disabledAt;
  final String? city;
  final String? country;

  /// Every grant, including revoked and expired ones. History is the point:
  /// authority that was held and then taken away is exactly what an operator
  /// investigating someone needs to see.
  final List<AdminGrant> grants;

  /// Derived by the SERVER from the active grants alone.
  final List<String> roles;
  final List<String> permissions;

  final List<AdminPersonDevice> devices;
  final Map<String, int> counts;

  /// How many OTHER people could still act as owner if this person's owner
  /// authority were removed.
  ///
  /// Null when the server did not say — which is NOT the same as zero. An
  /// unknown answer must not be read as "nobody else", or the console starts
  /// withholding legitimate controls on a guess.
  final int? otherOwnerHolders;

  /// True only when the server said, positively, that nobody else can.
  bool get isSoleOwnerHolder => otherOwnerHolders == 0;

  String get id => person.userId;

  bool get isDisabled => status.toUpperCase() == 'DISABLED';

  Iterable<AdminGrant> get activeGrants => grants.where(
        (g) =>
            g.derivedStatus == AdminGrantStatus.active ||
            g.derivedStatus == AdminGrantStatus.bootstrap,
      );

  static String _s(dynamic v) => (v ?? '').toString().trim();

  static DateTime? _date(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    final s = v.toString().trim();
    return s.isEmpty ? null : DateTime.tryParse(s);
  }

  static List<String> _sList(dynamic v) => v is List
      ? v.map(_s).where((e) => e.isNotEmpty).toList(growable: false)
      : const <String>[];

  factory AdminPersonDetail.fromJson(Map<String, dynamic> json) {
    final body = json['user'] is Map
        ? Map<String, dynamic>.from(json['user'] as Map)
        : json;
    final admin = body['admin'] is Map
        ? Map<String, dynamic>.from(body['admin'] as Map)
        : const <String, dynamic>{};
    final rawCounts = body['counts'] is Map
        ? Map<String, dynamic>.from(body['counts'] as Map)
        : const <String, dynamic>{};

    return AdminPersonDetail(
      person: AuraPersonIdentity.fromJson(body),
      email: _s(body['email']),
      status: _s(body['status']).isEmpty ? 'ACTIVE' : _s(body['status']),
      accountType: _s(body['accountType']),
      createdAt: _date(body['createdAt']) ?? DateTime.now(),
      emailVerifiedAt: _date(body['emailVerifiedAt']),
      disabledAt: _date(body['disabledAt']),
      city: _s(body['city']).isEmpty ? null : _s(body['city']),
      country: _s(body['country']).isEmpty ? null : _s(body['country']),
      grants: admin['grants'] is List
          ? (admin['grants'] as List)
              .whereType<Map>()
              .map((e) => AdminGrant.fromJson(Map<String, dynamic>.from(e)))
              .toList(growable: false)
          : const <AdminGrant>[],
      roles: _sList(admin['roles']),
      permissions: _sList(admin['permissions']),
      devices: body['devices'] is List
          ? (body['devices'] as List)
              .whereType<Map>()
              .map((e) =>
                  AdminPersonDevice.fromJson(Map<String, dynamic>.from(e)))
              .toList(growable: false)
          : const <AdminPersonDevice>[],
      counts: {
        for (final e in rawCounts.entries)
          if (e.value is num) e.key: (e.value as num).toInt(),
      },
      otherOwnerHolders: body['otherOwnerHolders'] is num
          ? (body['otherOwnerHolders'] as num).toInt()
          : null,
    );
  }
}

/// A device this person receives Aura on.
///
/// The push token is DELIBERATELY not modelled. An operator diagnosing why
/// someone stopped receiving calls needs to know a device exists, what it is,
/// and whether it is still active — never the credential that can send to it.
class AdminPersonDevice {
  const AdminPersonDevice({
    required this.id,
    required this.platform,
    required this.isActive,
    required this.lastSeenAt,
    this.deviceName,
    this.appVersion,
    this.revokedAt,
  });

  final String id;
  final String platform;
  final bool isActive;
  final DateTime lastSeenAt;
  final String? deviceName;
  final String? appVersion;
  final DateTime? revokedAt;

  /// What to call it on screen. A platform alone ("android") names a class of
  /// device, not the one in someone's hand.
  String get label {
    final name = deviceName?.trim() ?? '';
    if (name.isNotEmpty) return name;
    return platform.isEmpty ? 'Unknown device' : platform;
  }

  factory AdminPersonDevice.fromJson(Map<String, dynamic> json) {
    String s(dynamic v) => (v ?? '').toString().trim();
    DateTime? d(dynamic v) =>
        v == null ? null : DateTime.tryParse(v.toString().trim());
    return AdminPersonDevice(
      id: s(json['id']),
      platform: s(json['platform']),
      isActive: json['isActive'] == true && json['revokedAt'] == null,
      lastSeenAt:
          d(json['lastSeenAt']) ?? d(json['updatedAt']) ?? DateTime.now(),
      deviceName: s(json['deviceName']).isEmpty ? null : s(json['deviceName']),
      appVersion: s(json['appVersion']).isEmpty ? null : s(json['appVersion']),
      revokedAt: d(json['revokedAt']),
    );
  }
}
