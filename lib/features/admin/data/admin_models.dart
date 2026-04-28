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
