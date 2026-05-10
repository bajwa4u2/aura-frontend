import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/session_bootstrap.dart';
import '../auth/session_providers.dart';
import '../net/dio_provider.dart';

enum AppAdminState {
  none,
  admin,
}

class AppAdminAccess {
  final AppAdminState state;
  final Map<String, dynamic>? me;

  const AppAdminAccess({
    required this.state,
    this.me,
  });

  bool get isAdmin => state == AppAdminState.admin;
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

Map<String, dynamic> _unwrapAdminMe(dynamic raw) {
  final root = _asMap(raw);

  final user = root['user'];
  if (user is Map) return Map<String, dynamic>.from(user);

  final data = root['data'];
  if (data is Map) {
    final nested = Map<String, dynamic>.from(data);
    final nestedUser = nested['user'];
    if (nestedUser is Map) return Map<String, dynamic>.from(nestedUser);
    return nested;
  }

  return root;
}

// ─────────────────────────────────────────────────────────────────────────────
// LAZY ADMIN PROBE — Phase 2 of admin route gating
// ─────────────────────────────────────────────────────────────────────────────
//
// Until this refactor `appAdminAccessProvider` fired `GET /v1/admin/me` for
// every signed-in user simply because non-admin shells (Me, Announcements,
// Create, Communications) were watching it to decide whether to render an
// admin entry point. Each non-admin user was producing one
// `admin.access.denied` audit-log entry per route change — observation noise,
// not security signal.
//
// New contract:
//
//   * The probe is FORBIDDEN unless one of:
//       - the router has set `appAdminProbeAllowedProvider = true`
//         (it does this when `requiresAppAdmin(path)` is true)
//       - `cachedAdminAuthorityProvider` already says `true` (the user has
//         been confirmed admin earlier this session, so re-validation is
//         allowed and expected)
//
//   * Non-admin shells must NOT watch `appAdminAccessProvider`. They watch
//     `appAdminCachedDisplayProvider` instead — a synchronous getter that
//     returns the cached value without ever firing a probe.
//
//   * The cache is session-scoped and cleared on sign-out. A returning
//     admin who signs in fresh sees their admin entry only after they have
//     navigated to `/admin/*` once that session.

/// True once any callsite has explicitly granted permission for the admin
/// probe to fire. Latches: once true, stays true for the rest of the auth
/// session. Reset on sign-out by `_AdminAuthorityResetter` below.
final appAdminProbeAllowedProvider = StateProvider<bool>((_) => false);

/// Last known admin authority — `true` confirmed admin, `false` confirmed
/// non-admin, `null` unknown (never probed this session). Read-only from
/// outside; updated only by the probe path inside `appAdminAccessProvider`.
class _AdminAuthorityCache extends StateNotifier<bool?> {
  _AdminAuthorityCache() : super(null);

  void setKnown(bool value) {
    if (state != value) state = value;
  }

  void reset() {
    if (state != null) state = null;
  }
}

final cachedAdminAuthorityProvider =
    StateNotifierProvider<_AdminAuthorityCache, bool?>((ref) {
  final cache = _AdminAuthorityCache();
  // Sign-out resets cache + the latch so a different user signing in on the
  // same device starts cold (no inherited admin trust).
  ref.listen<bool>(isAuthedProvider, (prev, next) {
    if (prev == true && next == false) {
      cache.reset();
      ref.read(appAdminProbeAllowedProvider.notifier).state = false;
    }
  });
  return cache;
});

/// Synchronous display gate consumed by non-admin shells. Returns `true`
/// only when the cache has been populated with a confirmed-admin signal.
/// Reading this NEVER fires `/admin/me`.
final appAdminCachedDisplayProvider = Provider<bool>((ref) {
  return ref.watch(cachedAdminAuthorityProvider) == true;
});

/// Backend-hydrated admin access.
/// Authority is derived exclusively from GET /v1/admin/me.
/// 403 / 404 means the user has no admin grant — treated as none, not a crash.
///
/// Slice-D admin gating: this provider now early-returns `none` WITHOUT
/// firing any HTTP call when the probe has not been explicitly allowed AND
/// the cache does not already vouch for the user. Only `/admin/*` route
/// entry (or a returning-admin re-validation) triggers a real probe.
final appAdminAccessProvider = FutureProvider<AppAdminAccess>((ref) async {
  await ref.watch(sessionBootstrapProvider.future);

  final authStatus = ref.watch(authStatusProvider);
  if (authStatus != AuthStatus.authed) {
    return const AppAdminAccess(state: AppAdminState.none);
  }

  final probeAllowed = ref.watch(appAdminProbeAllowedProvider);
  // ref.read (not watch) for the cache — the probe itself updates this
  // cache, so watching it would invalidate this FutureProvider mid-probe
  // and produce a duplicate request on the very first admin confirmation.
  // Cache changes that matter (sign-out/sign-in) already invalidate via
  // the authStatus watch above.
  final cached = ref.read(cachedAdminAuthorityProvider);

  // Skip the probe entirely unless we have a reason to fire it.
  // - probeAllowed=false + cached=null   → user has not asked for admin and
  //                                         we have no prior signal; do NOT
  //                                         emit an audit-log denial just
  //                                         because they signed in.
  // - probeAllowed=false + cached=false  → already confirmed non-admin this
  //                                         session; no point re-asking.
  if (!probeAllowed && cached != true) {
    return const AppAdminAccess(state: AppAdminState.none);
  }

  final dio = ref.watch(dioProvider);

  try {
    final res = await dio.get('/v1/admin/me');
    final me = _unwrapAdminMe(res.data);
    ref.read(cachedAdminAuthorityProvider.notifier).setKnown(true);
    return AppAdminAccess(state: AppAdminState.admin, me: me);
  } on DioException catch (e) {
    final code = e.response?.statusCode;
    if (code == 401 || code == 403 || code == 404) {
      ref.read(cachedAdminAuthorityProvider.notifier).setKnown(false);
      return const AppAdminAccess(state: AppAdminState.none);
    }
    rethrow;
  }
});
