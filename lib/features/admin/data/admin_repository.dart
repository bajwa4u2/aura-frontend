import 'package:dio/dio.dart';

import '../domain/platform_health.dart';
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

  Future<AdminConvergenceReport> fetchDirectThreadConvergence() async {
    final res = await _dio.get('/v1/admin/migrations/direct-thread-convergence');
    return AdminConvergenceReport.fromJson(_asMap(res.data));
  }

  Future<AdminAccess> fetchMe() async {
    final res = await _dio.get('/v1/admin/me');
    return AdminAccess.fromJson(_asMap(res.data));
  }

  Future<AdminMetricOverview> fetchMetrics() async {
    final res = await _dio.get('/v1/admin/metrics/overview');
    return AdminMetricOverview.fromJson(_asMap(res.data));
  }

  /// Platform health, normalized before it leaves the data layer.
  ///
  /// The operator surface must never reason from the payload. It did once —
  /// looking for a `services` map the server has never sent — and rendered
  /// `{STATUS: OK, MESSAGE: API PROCESS IS RUNNING}` as a status pill while
  /// announcing five degraded services over a healthy platform.
  Future<PlatformHealth> fetchHealth() async {
    final res = await _dio.get('/v1/admin/health');
    return PlatformHealth.fromJson(_asMap(res.data));
  }

  Future<List<AdminUserSummary>> fetchUsers({
    int page = 1,
    int limit = 50,
    String? query,
    String? status,
  }) async {
    final res = await _dio.get(
      '/v1/admin/users',
      queryParameters: {
        'page': page,
        'limit': limit,
        if (query != null && query.isNotEmpty) 'q': query,
        if (status != null && status.isNotEmpty && status != 'ALL') 'status': status,
      },
    );
    return _parseList(res.data, AdminUserSummary.fromJson);
  }

  /// ONE person, whole. See [AdminPersonDetail] — the endpoint always returned
  /// this and nothing ever asked for it, so account standing, operator
  /// authority and delivery trouble stayed three screens that never met.
  Future<AdminPersonDetail> fetchUser(String userId) async {
    final res = await _dio.get('/v1/admin/users/$userId');
    return AdminPersonDetail.fromJson(_asMap(res.data));
  }

  /// Change account standing. The reason travels with it because the endpoint
  /// records one in the audit entry; sending none left every disablement in
  /// the record unexplained.
  Future<void> updateUserStatus(
    String userId,
    String status, {
    String? reason,
  }) async {
    await _dio.patch('/v1/admin/users/$userId/status', data: {
      'status': status,
      if (reason != null && reason.isNotEmpty) 'reason': reason,
    });
  }

  /// Grant a verified identity class. IDENTITY_VERIFICATION_WRITE.
  ///
  /// The authority requires a reason and refuses a second active record for
  /// the same class. Both rules live there, not here.
  Future<void> grantPersonVerificationClass(
    String userId, {
    required String verificationClass,
    required String reason,
    String? issuingAuthority,
    String? issuingInstitutionId,
  }) async {
    await _dio.post('/v1/admin/users/$userId/verification/grant', data: {
      'verificationClass': verificationClass,
      'reason': reason,
      if (issuingAuthority != null && issuingAuthority.isNotEmpty)
        'issuingAuthority': issuingAuthority,
      if (issuingInstitutionId != null && issuingInstitutionId.isNotEmpty)
        'issuingInstitutionId': issuingInstitutionId,
    });
  }

  // C2 — Person Verification administration. Thin wire client over the
  // VERIFICATION_READ/WRITE admin endpoints; every governed rule lives in
  // the backend Person Verification Authority.
  Future<AdminPersonVerification> fetchPersonVerification(String userId) async {
    final res = await _dio.get('/v1/admin/users/$userId/verification');
    return AdminPersonVerification.fromJson(_asMap(res.data));
  }

  Future<void> grantPersonVerification(
    String userId, {
    required String verificationClass,
    required String reason,
    String? issuingAuthority,
    String? issuingInstitutionId,
    String? classSubtype,
  }) async {
    await _dio.post(
      '/v1/admin/users/$userId/verification/grant',
      data: {
        'verificationClass': verificationClass,
        'reason': reason,
        if (issuingAuthority != null && issuingAuthority.isNotEmpty)
          'issuingAuthority': issuingAuthority,
        if (issuingInstitutionId != null && issuingInstitutionId.isNotEmpty)
          'issuingInstitutionId': issuingInstitutionId,
        if (classSubtype != null && classSubtype.isNotEmpty)
          'classSubtype': classSubtype,
      },
    );
  }

  Future<void> revokePersonVerification(
    String userId, {
    required String verificationClass,
    required String reason,
  }) async {
    await _dio.post(
      '/v1/admin/users/$userId/verification/revoke',
      data: {
        'verificationClass': verificationClass,
        'reason': reason,
      },
    );
  }

  /// Operator grants. [userId] narrows to ONE person's authority — the filter
  /// the endpoint has always accepted and nothing ever sent, which is why a
  /// grant could only be found by scrolling the estate-wide list.
  Future<List<AdminGrant>> fetchGrants({String? userId, String? status}) async {
    final res = await _dio.get('/v1/admin/grants', queryParameters: {
      if (userId != null && userId.isNotEmpty) 'userId': userId,
      if (status != null && status.isNotEmpty) 'status': status,
      'limit': 100,
    });
    return _parseList(res.data, AdminGrant.fromJson);
  }

  /// Revoking is a governed act, so the reason travels with it. The endpoint
  /// records `reason` and `notes` in the audit entry; sending nothing left
  /// every revocation in the record with no explanation attached.
  Future<void> revokeGrant(String grantId, {String? reason}) async {
    await _dio.post(
      '/v1/admin/grants/$grantId/revoke',
      data: {if (reason != null && reason.isNotEmpty) 'reason': reason},
    );
  }

  /// Issue authority to a person. USERS_WRITE; audited as
  /// `admin.grant.created`.
  Future<void> createGrant({
    required String userId,
    required String role,
    List<String> permissions = const [],
    String? reason,
    DateTime? expiresAt,
  }) async {
    await _dio.post('/v1/admin/grants', data: {
      'userId': userId,
      'role': role,
      if (permissions.isNotEmpty) 'permissions': permissions,
      if (reason != null && reason.isNotEmpty) 'reason': reason,
      if (expiresAt != null) 'expiresAt': expiresAt.toUtc().toIso8601String(),
    });
  }

  /// The catalogue, from the server that defines it.
  ///
  /// Never a list held on this side: the two would drift the first time a
  /// scope is added, which is how the identity scopes came to be ungrantable.
  Future<List<String>> fetchPermissionCatalogue() async {
    final res = await _dio.get('/v1/admin/grants/permissions');
    final data = res.data;
    final body = data is Map<String, dynamic> ? (data['data'] ?? data) : data;
    final list = body is Map<String, dynamic> ? body['permissions'] : body;
    return list is List
        ? list.map((e) => e.toString()).toList(growable: false)
        : const [];
  }

  /// Set a grant's permissions.
  ///
  /// The whole set, not a delta, because that is what the endpoint means and a
  /// delta would quietly disagree with what the operator saw on screen.
  Future<void> setGrantPermissions(String grantId, List<String> permissions) async {
    await _dio.patch(
      '/v1/admin/grants/$grantId',
      data: {'permissions': permissions},
    );
  }

  Future<List<AdminAuditLogEntry>> fetchAuditLogs({
    int page = 1,
    int limit = 50,
    String? actorId,
    String? action,
    String? result,
  }) async {
    final res = await _dio.get(
      '/v1/admin/audit-logs',
      queryParameters: {
        'page': page,
        'limit': limit,
        if (actorId != null && actorId.isNotEmpty) 'actorId': actorId,
        if (action != null && action.isNotEmpty) 'action': action,
        if (result != null && result.isNotEmpty) 'result': result,
      },
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

  /// Domain proof. [institutionId] narrows to ONE institution — a filter the
  /// endpoint has always accepted and nothing ever sent.
  Future<List<AdminInstitutionDomain>> fetchInstitutionDomains({
    String? status,
    String? institutionId,
  }) async {
    final res = await _dio.get(
      '/v1/admin/institution-domains',
      queryParameters: {
        if (status != null) 'status': status,
        if (institutionId != null && institutionId.isNotEmpty)
          'institutionId': institutionId,
        'limit': 100,
      },
    );
    return _parseList(res.data, AdminInstitutionDomain.fromJson);
  }

  /// `action` is REQUIRED by the DTO even though the route already decides it:
  /// validation runs before the controller substitutes its own value, so a
  /// body without it is rejected as 400 before reaching any of that. The
  /// previous empty-body call could therefore never have approved anything.
  Future<void> approveDomain(String id, {String? reason}) async {
    await _dio.post(
      '/v1/admin/institution-domains/$id/approve',
      data: {
        'action': 'APPROVE',
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      },
    );
  }

  Future<void> rejectDomain(String id, {String? reason}) async {
    await _dio.post(
      '/v1/admin/institution-domains/$id/reject',
      data: {
        'action': 'REJECT',
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      },
    );
  }

  // ── Institutions ────────────────────────────────────────────────────────

  Future<List<AdminInstitutionSummary>> fetchInstitutions({String? status}) async {
    final res = await _dio.get(
      '/v1/institutions/admin',
      queryParameters: {
        if (status != null && status.isNotEmpty) 'status': status,
      },
    );
    return _parseList(res.data, AdminInstitutionSummary.fromJson);
  }

  /// ONE institution, resolved by id and NOT by searching the directory.
  ///
  /// The subject screen used to look its institution up inside the directory
  /// list. That list was status-filtered, so a suspended or pending
  /// institution — precisely the subject an operator is sent to review —
  /// resolved to "No such institution". A subject exists independently of
  /// whichever slice of the directory happens to be loaded.
  Future<AdminInstitutionSummary?> fetchInstitution(String institutionId) async {
    final res = await _dio.get('/v1/institutions/id/$institutionId');
    final body = res.data;
    final envelope = body is Map<String, dynamic>
        ? (body['data'] is Map<String, dynamic>
            ? body['data'] as Map<String, dynamic>
            : body)
        : const <String, dynamic>{};
    final institution = envelope['institution'];
    if (institution is! Map<String, dynamic>) return null;
    return AdminInstitutionSummary.fromJson(institution);
  }

  Future<List<AdminVerificationRequest>> fetchVerificationRequests({String? status}) async {
    final res = await _dio.get(
      '/v1/institutions/admin/verification-requests',
      queryParameters: {
        if (status != null && status.isNotEmpty) 'status': status,
      },
    );
    return _parseList(res.data, AdminVerificationRequest.fromJson);
  }

  Future<void> approveVerificationRequest(String id) async {
    await _dio.post('/v1/institutions/admin/verification-requests/$id/approve');
  }

  Future<void> rejectVerificationRequest(String id, {String? reason}) async {
    await _dio.post(
      '/v1/institutions/admin/verification-requests/$id/reject',
      data: {if (reason != null && reason.isNotEmpty) 'reason': reason},
    );
  }

  Future<void> needsInfoVerificationRequest(String id, {String? reason}) async {
    await _dio.post(
      '/v1/institutions/admin/verification-requests/$id/needs-info',
      data: {if (reason != null && reason.isNotEmpty) 'reason': reason},
    );
  }

  Future<List<AdminInstitutionMember>> fetchInstitutionMembers(String institutionId) async {
    final res = await _dio.get('/v1/institutions/$institutionId/members');
    final data = res.data;
    if (data is Map) {
      final items = data['members'];
      if (items is List) {
        return items
            .whereType<Map>()
            .map((e) => AdminInstitutionMember.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
    }
    return _parseList(data, AdminInstitutionMember.fromJson);
  }

  Future<void> updateInstitutionMemberRole(
    String institutionId,
    String targetUserId,
    String role,
  ) async {
    await _dio.patch(
      '/v1/institutions/$institutionId/members/$targetUserId/role',
      data: {'role': role},
    );
  }

  Future<void> removeInstitutionMember(String institutionId, String targetUserId) async {
    await _dio.delete('/v1/institutions/$institutionId/members/$targetUserId');
  }

  // ── Institution Ownership Continuity ─────────────────────────────────────
  //
  // Emergency ownership recovery is consequential, narrowly-scoped
  // platform governance authority, not ordinary member administration. The
  // backend is authoritative for both the recovery CONDITION and the
  // eligible replacement set; this surface only renders what it is told
  // and never derives eligibility of its own.

  Future<InstitutionOwnershipRecoveryState> fetchOwnershipRecoveryState(
    String institutionId,
  ) async {
    final res = await _dio.get(
      '/v1/institutions/$institutionId/authority/ownership-recovery-state',
    );
    final data = res.data;
    if (data is Map) {
      return InstitutionOwnershipRecoveryState.fromJson(
        Map<String, dynamic>.from(data),
      );
    }
    return const InstitutionOwnershipRecoveryState.notRequired();
  }

  Future<void> emergencyRecoverOwnership(
    String institutionId,
    String newOwnerUserId,
    String reason,
  ) async {
    await _dio.post(
      '/v1/institutions/$institutionId/authority/emergency-recover-ownership',
      data: {'newOwnerUserId': newOwnerUserId, 'reason': reason},
    );
  }

  // ── Review Queue ────────────────────────────────────────────────────────

  Future<List<ReviewQueueItem>> fetchReviewQueue({String? type, String? status}) async {
    final res = await _dio.get(
      '/v1/admin/review-queue',
      queryParameters: {
        if (type != null && type.isNotEmpty) 'type': type,
        if (status != null && status.isNotEmpty) 'status': status,
      },
    );
    return _parseList(res.data, ReviewQueueItem.fromJson);
  }

  Future<void> approveReview(String id, {String? note}) async {
    await _dio.post(
      '/v1/admin/review/$id/approve',
      data: {if (note != null && note.isNotEmpty) 'note': note},
    );
  }

  Future<void> rejectReview(String id, {String? note}) async {
    await _dio.post(
      '/v1/admin/review/$id/reject',
      data: {if (note != null && note.isNotEmpty) 'note': note},
    );
  }

  // ── Policies ────────────────────────────────────────────────────────────

  Future<AdminPolicy> fetchPolicies() async {
    try {
      final res = await _dio.get('/v1/admin/policies');
      final raw = res.data;
      if (raw is Map<String, dynamic>) return AdminPolicy.fromJson(raw);
      if (raw is Map) return AdminPolicy.fromJson(Map<String, dynamic>.from(raw));
    } catch (_) {}
    return AdminPolicy.defaults;
  }

  Future<void> updatePolicies(AdminPolicy policy) async {
    await _dio.put('/v1/admin/policies', data: policy.toJson());
  }

  // ── Moderation queue ─────────────────────────────────────────────────────

  Future<List<ModerationReport>> fetchModerationQueue({
    String? status,
    int take = 25,
    int skip = 0,
  }) async {
    final res = await _dio.get(
      '/v1/moderation/queue',
      queryParameters: {
        if (status != null) 'status': status,
        'take': take,
        'skip': skip,
      },
    );
    return _parseList(_asMap(res.data)['items'] ?? res.data, ModerationReport.fromJson);
  }

  Future<ModerationReport> fetchModerationReport(String id) async {
    final res = await _dio.get('/v1/moderation/reports/$id');
    final data = _asMap(res.data);
    return ModerationReport.fromJson(_asMap(data['report'] ?? data));
  }

  Future<void> setModerationReportStatus(
    String id, {
    required String status,
    String? outcomeSummary,
    String? privateNote,
  }) async {
    await _dio.post(
      '/v1/moderation/reports/$id/status',
      data: {
        'status': status,
        if (outcomeSummary != null) 'outcomeSummary': outcomeSummary,
        if (privateNote != null) 'privateNote': privateNote,
      },
    );
  }

  Future<void> submitModerationAction({
    required String actionType,
    required String targetType,
    required String targetId,
    String? reportId,
    String? reportStatus,
    String? note,
    String? outcomeSummary,
    String? privateNote,
  }) async {
    await _dio.post(
      '/v1/moderation/actions',
      data: {
        'actionType': actionType,
        'targetType': targetType,
        'targetId': targetId,
        if (reportId != null) 'reportId': reportId,
        if (reportStatus != null) 'reportStatus': reportStatus,
        if (note != null) 'note': note,
        if (outcomeSummary != null) 'outcomeSummary': outcomeSummary,
        if (privateNote != null) 'privateNote': privateNote,
      },
    );
  }

  // ── CH-12 E6 — media quarantine appeals ──────────────────────────────────
  //
  // Deliberately part of the EXISTING admin repository rather than a new
  // media-admin client. The authority is the same MODERATION_READ /
  // MODERATION_WRITE the moderation queue already uses; a separate client
  // would imply a separate authority and eventually acquire one.

  Future<List<MediaAppealSummary>> fetchMediaAppeals({int limit = 50}) async {
    final res = await _dio.get(
      '/v1/admin/media/appeals',
      queryParameters: {'limit': limit},
    );
    final body = _asMap(res.data);
    return _parseList(body['items'] ?? res.data, MediaAppealSummary.fromJson);
  }

  /// Decide an appeal. REVERSED releases the object through the canonical
  /// lifecycle; UPHELD leaves it quarantined and RETAINED — upholding is never
  /// deletion, and there is no client call that could make it one.
  Future<void> decideMediaAppeal(
    String appealId, {
    required String outcome,
    required String decisionSummary,
    String? privateNote,
  }) async {
    await _dio.post(
      '/v1/admin/media/appeals/$appealId/decide',
      data: {
        'outcome': outcome,
        'decisionSummary': decisionSummary,
        if (privateNote != null) 'privateNote': privateNote,
      },
    );
  }
}

/// One row of the governed appeal queue, as the reviewer sees it.
///
/// Carries the appellant's own statement and the governed restriction context.
/// It does NOT carry detector internals: the server's select decides that, and
/// this model has no field for a signature so a widening cannot leak through
/// the reviewer UI either.
class MediaAppealSummary {
  const MediaAppealSummary({
    required this.id,
    required this.mediaId,
    required this.status,
    required this.standingBasis,
    this.appellantUserId,
    this.statement,
    this.submittedAt,
    this.fileName,
    this.mimeType,
    this.quarantineReason,
    this.quarantineSource,
  });

  final String id;
  final String mediaId;
  final String status;
  final String standingBasis;
  final String? appellantUserId;
  final String? statement;
  final DateTime? submittedAt;

  final String? fileName;
  final String? mimeType;

  /// Reviewer-facing context. A reviewer, unlike a member, needs to know what
  /// the examiner actually said in order to decide.
  final String? quarantineReason;
  final String? quarantineSource;

  static MediaAppealSummary fromJson(Map<String, dynamic> json) {
    final media = json['media'] is Map
        ? Map<String, dynamic>.from(json['media'] as Map)
        : const <String, dynamic>{};
    return MediaAppealSummary(
      id: json['id']?.toString() ?? '',
      mediaId: json['mediaId']?.toString() ?? '',
      status: json['status']?.toString() ?? 'SUBMITTED',
      standingBasis: json['standingBasis']?.toString() ?? '',
      appellantUserId: json['appellantUserId']?.toString(),
      statement: json['statement']?.toString(),
      // Parsed, not localised — ProductTime owns presentation timezone.
      submittedAt: json['submittedAt'] == null
          ? null
          : DateTime.tryParse(json['submittedAt'].toString()),
      fileName: media['fileName']?.toString(),
      mimeType: media['mimeType']?.toString(),
      quarantineReason: media['quarantineReason']?.toString(),
      quarantineSource: media['quarantineSource']?.toString(),
    );
  }
}

// Standalone provider helper — used by admin_providers.dart.
AdminRepository adminRepositoryFromDio(Dio dio) => AdminRepository(dio);
