import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/admin_access_provider.dart';
import '../../../core/net/dio_provider.dart';
import '../domain/operator_freshness.dart';
import '../domain/operator_signal.dart';
import '../domain/platform_health.dart';
import 'admin_repository.dart';
import 'operator_cache.dart';

export '../domain/platform_health.dart';
export 'admin_models.dart';
export 'admin_repository.dart' show AdminRepository;

// ── Repository ────────────────────────────────────────────────────────────

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return AdminRepository(ref.watch(dioProvider));
});

// ── /v1/admin/me ─────────────────────────────────────────────────────────

/// ONE AUTHORITY BOOTSTRAP, NOT TWO.
///
/// PERFORMANCE IS PRODUCT (founder, this chapter). This provider used to fire
/// its own `GET /v1/admin/me` — the SECOND one the console makes, because
/// `appAdminAccessProvider` has already made that exact request to decide
/// whether the operator may enter at all.
///
/// The cost was not one wasted request. EVERY gated provider in the console
/// awaits this future before issuing its own read, so the entire data layer
/// sat behind a round trip whose answer was already in memory. On a cold
/// Railway connection that is the difference between a console that paints
/// and a console an operator watches.
///
/// It also produced two audit events per entry for one act of entering.
///
/// The probe keeps its discipline — it still refuses to fire for a signed-in
/// non-operator, which is what stopped every route change writing an
/// `admin.access.denied` entry. This simply stops asking the same question
/// twice.
final adminMeProvider = FutureProvider<AdminAccess?>((ref) async {
  final access = await ref.watch(appAdminAccessProvider.future);
  final me = access.me;
  if (me == null) return null;
  return AdminAccess.fromJson(me);
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

/// Per-container memory of the last good reading for each authority.
///
/// A plain `Provider`, so it lives and dies with the container: a test starts
/// with no memory, and one test cannot leak a reading into the next.
final operatorReadingMemoryProvider =
    Provider<OperatorReadingMemory>((ref) => OperatorReadingMemory());

// ── /v1/admin/health ──────────────────────────────────────────────────────

/// PLATFORM HEALTH — the only place the console learns whether Aura is well.
///
/// Returns a signal rather than a nullable value. `null` could not distinguish
/// "you may not see this", "we could not ask" and "everything is fine and
/// there is nothing to report", and the surface guessed — which is how a
/// healthy platform got reported as degraded.
final platformHealthProvider =
    FutureProvider.autoDispose<OperatorSignal<PlatformHealth>>((ref) async {
  // Read by NOW and by PLATFORM. Moving between them re-asked whether Aura
  // was well, behind a skeleton, when the answer was seconds old.
  cacheOperatorReading(ref);
  final memory = ref.watch(operatorReadingMemoryProvider);
  try {
    final health = await ref.watch(adminRepositoryProvider).fetchHealth();
    final readAt = DateTime.now();
    memory.remember(OperatorReadingKey.health, health, readAt);
    return OperatorSignal.complete(health, readAt: readAt);
  } on DioException catch (e) {
    final code = e.response?.statusCode;
    if (code == 401 || code == 403) {
      // AN AUTHORITY CHANGE INVALIDATES WHAT WE HELD.
      //
      // A reading taken as one operator must never be shown to another, and
      // "stale" would be exactly that: last-known state from a session that no
      // longer applies. Forget it before refusing.
      memory.forget();
      return const OperatorSignal.unauthorized(needs: 'system health');
    }
    // A REFRESH THAT FAILED IS NOT A READING THAT NEVER HAPPENED.
    //
    // This used to discard the health we already held and report a read
    // failure, so an operator watching a live console lost the last known
    // state at the moment the network got worse. If a good reading exists it
    // is shown as what it is — old, with its age, and refreshable.
    final held = memory.recall<PlatformHealth>(OperatorReadingKey.health);
    if (held != null) {
      return OperatorSignal.stale(held.value, readAt: held.readAt);
    }
    // Cold into a failure: nothing old to show, so say we could not ask.
    return const OperatorSignal.unavailable(detail: 'could not be reached');
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
      status: 'PENDING',
    );
  } on DioException catch (e) {
    final code = e.response?.statusCode;
    if (code == 401 || code == 403) return const [];
    rethrow;
  }
});

// ── /v1/admin/review-queue ─────────────────────────────────────────────────

final adminReviewQueueProvider = FutureProvider<List<ReviewQueueItem>>((ref) async {
  final me = await ref.watch(adminMeProvider.future);
  if (me == null) return const [];

  try {
    return await ref.watch(adminRepositoryProvider).fetchReviewQueue();
  } on DioException catch (e) {
    final code = e.response?.statusCode;
    if (code == 401 || code == 403) return const [];
    rethrow;
  }
});

// ── /v1/admin/policies ────────────────────────────────────────────────────

final adminPoliciesProvider = FutureProvider<AdminPolicy>((ref) async {
  final me = await ref.watch(adminMeProvider.future);
  if (me == null) return AdminPolicy.defaults;

  try {
    return await ref.watch(adminRepositoryProvider).fetchPolicies();
  } on DioException catch (e) {
    final code = e.response?.statusCode;
    if (code == 401 || code == 403) return AdminPolicy.defaults;
    rethrow;
  }
});

// ── /v1/moderation/queue ─────────────────────────────────────────────────

/// CH-12 E6 — the governed media-appeal queue.
///
/// Mirrors the moderation-queue provider exactly, including returning empty on
/// 401/403 rather than throwing: a reviewer without MODERATION_READ should see
/// an empty surface, not a crash, and the SERVER is what decided they may not
/// see it. The client never checks the permission itself.
final adminMediaAppealsProvider =
    FutureProvider.autoDispose<List<MediaAppealSummary>>((ref) async {
  final me = await ref.watch(adminMeProvider.future);
  if (me == null) return const [];

  try {
    return await ref.watch(adminRepositoryProvider).fetchMediaAppeals();
  } on DioException catch (e) {
    final code = e.response?.statusCode;
    if (code == 401 || code == 403) return const [];
    rethrow;
  }
});

final adminModerationQueueProvider =
    FutureProvider.family<List<ModerationReport>, String?>((ref, status) async {
  final me = await ref.watch(adminMeProvider.future);
  if (me == null) return const [];

  try {
    return await ref.watch(adminRepositoryProvider).fetchModerationQueue(status: status);
  } on DioException catch (e) {
    final code = e.response?.statusCode;
    if (code == 401 || code == 403) return const [];
    rethrow;
  }
});

// ── /v1/admin/migrations/direct-thread-convergence ───────────────────────

/// Unlike the list providers above, a permission failure here is NOT collapsed
/// into an empty value. Reconciliation evidence that silently renders as
/// "nothing to see" would be indistinguishable from "converged", which is the
/// exact confusion this surface exists to remove.
final adminConvergenceReportProvider =
    FutureProvider<AdminConvergenceReport>((ref) async {
  final me = await ref.watch(adminMeProvider.future);
  if (me == null) {
    throw StateError('Admin access is required to read migration reconciliation.');
  }
  return ref.watch(adminRepositoryProvider).fetchDirectThreadConvergence();
});
