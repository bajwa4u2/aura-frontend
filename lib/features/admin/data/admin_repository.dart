import 'package:dio/dio.dart';

import 'admin_models.dart';

export 'admin_models.dart';

class AdminRepository {
  const AdminRepository(this._dio);

  final Dio _dio;

  static Map<String, dynamic> _asMap(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return Map<String, dynamic>.from(v);
    return const {};
  }

  static List<T> _parseList<T>(
    dynamic raw,
    T Function(Map<String, dynamic>) parser,
  ) {
    List<dynamic>? items;
    if (raw is List) {
      items = raw;
    } else if (raw is Map) {
      final m = _asMap(raw);
      final data = m['data'] ?? m['items'] ?? m['results'];
      if (data is List) items = data;
    }
    if (items == null) return const [];
    return items
        .whereType<Map>()
        .map((e) => parser(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<AdminAccess> fetchMe() async {
    final res = await _dio.get('/v1/admin/me');
    return AdminAccess.fromJson(_asMap(res.data));
  }

  Future<AdminMetricOverview> fetchMetrics() async {
    final res = await _dio.get('/v1/admin/metrics/overview');
    return AdminMetricOverview.fromJson(_asMap(res.data));
  }

  Future<AdminHealthSnapshot> fetchHealth() async {
    final res = await _dio.get('/v1/admin/health');
    return AdminHealthSnapshot.fromJson(_asMap(res.data));
  }

  Future<List<AdminUserSummary>> fetchUsers({
    int page = 1,
    int limit = 50,
    String? query,
  }) async {
    final res = await _dio.get(
      '/v1/admin/users',
      queryParameters: {
        'page': page,
        'limit': limit,
        if (query != null && query.isNotEmpty) 'q': query,
      },
    );
    return _parseList(res.data, AdminUserSummary.fromJson);
  }

  Future<void> updateUserStatus(String userId, String status) async {
    await _dio.patch('/v1/admin/users/$userId/status', data: {'status': status});
  }

  Future<List<AdminGrant>> fetchGrants() async {
    final res = await _dio.get('/v1/admin/grants');
    return _parseList(res.data, AdminGrant.fromJson);
  }

  Future<void> revokeGrant(String grantId) async {
    await _dio.post('/v1/admin/grants/$grantId/revoke');
  }

  Future<List<AdminAuditLogEntry>> fetchAuditLogs({
    int page = 1,
    int limit = 50,
  }) async {
    final res = await _dio.get(
      '/v1/admin/audit-logs',
      queryParameters: {'page': page, 'limit': limit},
    );
    return _parseList(res.data, AdminAuditLogEntry.fromJson);
  }

  Future<List<AdminSetting>> fetchSettings() async {
    final res = await _dio.get('/v1/admin/settings');
    return _parseList(res.data, AdminSetting.fromJson);
  }

  Future<void> updateSetting(String key, dynamic value) async {
    await _dio.patch('/v1/admin/settings/$key', data: {'value': value});
  }

  Future<List<AdminFeatureFlag>> fetchFeatureFlags() async {
    final res = await _dio.get('/v1/admin/feature-flags');
    return _parseList(res.data, AdminFeatureFlag.fromJson);
  }

  Future<void> updateFeatureFlag(String key, {required bool enabled}) async {
    await _dio.patch('/v1/admin/feature-flags/$key', data: {'enabled': enabled});
  }

  Future<List<AdminInstitutionDomain>> fetchInstitutionDomains({
    String? status,
  }) async {
    final res = await _dio.get(
      '/v1/admin/institution-domains',
      queryParameters: {
        if (status != null) 'status': status,
      },
    );
    return _parseList(res.data, AdminInstitutionDomain.fromJson);
  }

  Future<void> approveDomain(String id) async {
    await _dio.post('/v1/admin/institution-domains/$id/approve');
  }

  Future<void> rejectDomain(String id) async {
    await _dio.post('/v1/admin/institution-domains/$id/reject');
  }
}

// Standalone provider helper — used by admin_providers.dart.
AdminRepository adminRepositoryFromDio(Dio dio) => AdminRepository(dio);
