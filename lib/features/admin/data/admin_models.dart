// Domain models for the backend Admin Hub.
// All fromJson factories are defensive — missing / null fields fall back to safe defaults.

class AdminAccess {
  const AdminAccess({
    required this.id,
    required this.email,
    required this.displayName,
    required this.role,
    required this.permissions,
    required this.status,
    required this.grants,
  });

  final String id;
  final String email;
  final String displayName;
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
      id: _str(data['id']),
      email: _str(data['email']),
      displayName: _str(data['displayName'] ?? data['name']),
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
    required this.id,
    required this.handle,
    required this.email,
    required this.displayName,
    required this.role,
    required this.status,
    required this.createdAt,
    this.lastActiveAt,
  });

  final String id;
  final String handle;
  final String email;
  final String displayName;
  final String role;
  final String status;
  final DateTime createdAt;
  final DateTime? lastActiveAt;

  static String _str(dynamic v) => (v ?? '').toString().trim();

  factory AdminUserSummary.fromJson(Map<String, dynamic> json) {
    return AdminUserSummary(
      id: _str(json['id']),
      handle: _str(json['handle']),
      email: _str(json['email']),
      displayName: _str(json['displayName'] ?? json['name']),
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

  factory AdminMetricOverview.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json;
    return AdminMetricOverview(
      totalUsers: _int(data['totalUsers'] ?? data['users']),
      activeUsers: _int(data['activeUsers']),
      totalInstitutions: _int(data['totalInstitutions'] ?? data['institutions']),
      pendingReports: _int(data['pendingReports'] ?? data['reports']),
      totalCommunications: _int(data['totalCommunications'] ?? data['communications']),
      realtimeSessions: _int(data['realtimeSessions'] ?? data['realtime']),
      totalDevices: _int(data['totalDevices'] ?? data['devices']),
      pendingPushJobs: _int(data['pendingPushJobs'] ?? data['push']),
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
    this.requesterHandle,
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
  final String? requesterHandle;
  final String? requesterEmail;
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
      requesterHandle: req != null ? _str(req['handle']).let((s) => s.isEmpty ? null : s) : null,
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

class AdminInstitutionMember {
  const AdminInstitutionMember({
    required this.id,
    required this.userId,
    required this.role,
    required this.joinedAt,
    this.displayName,
    this.handle,
    this.title,
    this.canSpeakOfficially = false,
  });

  final String id;
  final String userId;
  final String role;
  final DateTime joinedAt;
  final String? displayName;
  final String? handle;
  final String? title;
  final bool canSpeakOfficially;

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
      displayName: user != null ? _str(user['displayName']).let((s) => s.isEmpty ? null : s) : null,
      handle: user != null ? _str(user['handle']).let((s) => s.isEmpty ? null : s) : null,
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
