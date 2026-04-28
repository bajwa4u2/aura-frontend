import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/session_bootstrap.dart';
import '../../../core/auth/session_providers.dart';
import '../../../core/net/dio_provider.dart';
import 'admin_repository.dart';

export 'admin_models.dart';
export 'admin_repository.dart' show AdminRepository;

// ── Repository ────────────────────────────────────────────────────────────

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return AdminRepository(ref.watch(dioProvider));
});

// ── /v1/admin/me ─────────────────────────────────────────────────────────

final adminMeProvider = FutureProvider<AdminAccess?>((ref) async {
  await ref.watch(sessionBootstrapProvider.future);

  final authStatus = ref.watch(authStatusProvider);
  if (authStatus != AuthStatus.authed) return null;

  try {
    return await ref.watch(adminRepositoryProvider).fetchMe();
  } on DioException catch (e) {
    final code = e.response?.statusCode;
    if (code == 401 || code == 403 || code == 404) return null;
    rethrow;
  }
});

// ── /v1/admin/metrics/overview ────────────────────────────────────────────

final adminMetricsProvider = FutureProvider<AdminMetricOverview?>((ref) async {
  final me = await ref.watch(adminMeProvider.future);
  if (me == null) return null;

  try {
    return await ref.watch(adminRepositoryProvider).fetchMetrics();
  } on DioException catch (e) {
    final code = e.response?.statusCode;
    if (code == 401 || code == 403) return null;
    rethrow;
  }
});

// ── /v1/admin/health ──────────────────────────────────────────────────────

final adminHealthProvider = FutureProvider<AdminHealthSnapshot?>((ref) async {
  final me = await ref.watch(adminMeProvider.future);
  if (me == null) return null;

  try {
    return await ref.watch(adminRepositoryProvider).fetchHealth();
  } on DioException catch (e) {
    final code = e.response?.statusCode;
    if (code == 401 || code == 403) return null;
    rethrow;
  }
});

// ── /v1/admin/users ───────────────────────────────────────────────────────

final adminUsersProvider = FutureProvider<List<AdminUserSummary>>((ref) async {
  final me = await ref.watch(adminMeProvider.future);
  if (me == null) return const [];

  try {
    return await ref.watch(adminRepositoryProvider).fetchUsers();
  } on DioException catch (e) {
    final code = e.response?.statusCode;
    if (code == 401 || code == 403) return const [];
    rethrow;
  }
});

// ── /v1/admin/grants ──────────────────────────────────────────────────────

final adminGrantsProvider = FutureProvider<List<AdminGrant>>((ref) async {
  final me = await ref.watch(adminMeProvider.future);
  if (me == null) return const [];

  try {
    return await ref.watch(adminRepositoryProvider).fetchGrants();
  } on DioException catch (e) {
    final code = e.response?.statusCode;
    if (code == 401 || code == 403) return const [];
    rethrow;
  }
});

// ── /v1/admin/audit-logs ──────────────────────────────────────────────────

final adminAuditLogsProvider = FutureProvider<List<AdminAuditLogEntry>>((ref) async {
  final me = await ref.watch(adminMeProvider.future);
  if (me == null) return const [];

  try {
    return await ref.watch(adminRepositoryProvider).fetchAuditLogs();
  } on DioException catch (e) {
    final code = e.response?.statusCode;
    if (code == 401 || code == 403) return const [];
    rethrow;
  }
});

// ── /v1/admin/settings ────────────────────────────────────────────────────

final adminSettingsProvider = FutureProvider<List<AdminSetting>>((ref) async {
  final me = await ref.watch(adminMeProvider.future);
  if (me == null) return const [];

  try {
    return await ref.watch(adminRepositoryProvider).fetchSettings();
  } on DioException catch (e) {
    final code = e.response?.statusCode;
    if (code == 401 || code == 403) return const [];
    rethrow;
  }
});

// ── /v1/admin/feature-flags ───────────────────────────────────────────────

final adminFeatureFlagsProvider = FutureProvider<List<AdminFeatureFlag>>((ref) async {
  final me = await ref.watch(adminMeProvider.future);
  if (me == null) return const [];

  try {
    return await ref.watch(adminRepositoryProvider).fetchFeatureFlags();
  } on DioException catch (e) {
    final code = e.response?.statusCode;
    if (code == 401 || code == 403) return const [];
    rethrow;
  }
});

// ── /v1/admin/institution-domains ─────────────────────────────────────────

final adminInstitutionDomainsProvider = FutureProvider<List<AdminInstitutionDomain>>((ref) async {
  final me = await ref.watch(adminMeProvider.future);
  if (me == null) return const [];

  try {
    return await ref.watch(adminRepositoryProvider).fetchInstitutionDomains(
      status: 'pending',
    );
  } on DioException catch (e) {
    final code = e.response?.statusCode;
    if (code == 401 || code == 403) return const [];
    rethrow;
  }
});
