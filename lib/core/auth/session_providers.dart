import 'package:dio/dio.dart';
import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config.dart';
import '../net/dio_provider.dart';
import 'auth_providers.dart';
import 'session_bootstrap.dart';

/// Auth lifecycle status:
/// - loading: tokens still being restored from storage / bootstrap in-flight
/// - authed: access token present
/// - unauthed: no access token
enum AuthStatus { loading, authed, unauthed }

/// Whether tokens have been loaded from storage.
final tokenStoreLoadedProvider = Provider<bool>((ref) {
  final store = ref.watch(tokenStoreProvider);
  return store.isLoaded;
});

/// True only when tokens are loaded AND we have an access token.
final isAuthedProvider = Provider<bool>((ref) {
  final store = ref.watch(tokenStoreProvider);
  return store.isLoaded && store.isAuthed;
});

/// Decodes the access token and reports whether it is a meeting GUEST token
/// (`type: guest`). Guests have no member identity, so member-only providers
/// (`/auth/me`, `/notifications`, `/realtime/sessions?scope=me`) must not fire
/// for them — those endpoints 401 for a guest and only add console noise and
/// interceptor churn. Pure/synchronous so callers can gate cheaply.
bool isGuestAccessToken(String? token) {
  final t = (token ?? '').trim();
  if (t.isEmpty) return false;
  try {
    final parts = t.split('.');
    if (parts.length != 3) return false;
    final payload =
        jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
    return payload is Map && payload['type'] == 'guest';
  } catch (_) {
    return false;
  }
}

/// True while the active session is a meeting guest (see [isGuestAccessToken]).
/// Watch this to skip member-only data fetches in guest mode.
final isGuestSessionProvider = Provider<bool>((ref) {
  final store = ref.watch(tokenStoreProvider);
  return isGuestAccessToken(store.accessToken);
});

/// Router/guards helper.
///
/// KEY RULE:
/// If bootstrap is still running, return AuthStatus.loading so router does NOT redirect.
final authStatusProvider = Provider<AuthStatus>((ref) {
  final boot = ref.watch(sessionBootstrapProvider);
  if (boot.isLoading) return AuthStatus.loading;

  final store = ref.watch(tokenStoreProvider);

  if (!store.isLoaded) return AuthStatus.loading;
  if (store.isAuthed) return AuthStatus.authed;
  return AuthStatus.unauthed;
});

Map<String, dynamic> _toMap(dynamic v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return v.map((k, val) => MapEntry(k.toString(), val));
  return <String, dynamic>{};
}

dynamic _unwrapData(dynamic v) {
  final m = _toMap(v);
  if (m.containsKey('data')) return m['data'];
  return m;
}

/// Fetches and caches the /auth/me response payload.
///
/// Watches tokenStoreProvider directly (not just isAuthedProvider) so it
/// re-fires on ANY token swap — including institution re-login while a
/// personal session is already active.
///
/// RC5 — "COULD NOT ASK" IS NOT "ASKED AND GOT NOTHING".
///
/// This used to answer `{}` for every failure, so a transient 500, a dropped
/// connection or a timeout was indistinguishable from a signed-out visitor.
/// Everything downstream then reasoned from a confident empty identity that
/// was never established, and the state never corrected itself because
/// nothing was ever in error.
///
/// Now the two are kept apart. A 401/403 genuinely means "no member session"
/// and still answers `{}`. Anything else propagates, so the provider is in
/// ERROR — a state consumers and the router can see, and one the boot
/// surface already bounds (F068: a bounded wait with an honest retry, never
/// an eternal spinner).
final authMeDataProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final store = ref.watch(tokenStoreProvider);
  if (!store.isAuthed) return {};
  // Guest mode: /auth/me is member-only (401 for guests). Skip the call — the
  // result is the same {} it would return on the 401, minus the noise/churn.
  if (isGuestAccessToken(store.accessToken)) return {};

  final dio = ref.watch(dioProvider);

  try {
    final res = await dio.get('/auth/me');
    final raw = res.data;

    // unwrap once or twice (handles {data:{data:{...}}})
    final level1 = _unwrapData(raw);
    final level2 = _unwrapData(level1);
    return _toMap(level2);
  } on DioException catch (e) {
    final code = e.response?.statusCode ?? 0;
    // The server answered, and its answer was "not you": that IS the result.
    if (code == 401 || code == 403) return {};
    // Anything else — 5xx, timeout, offline — leaves identity UNKNOWN.
    // Answering {} here would state something that was never established.
    rethrow;
  }
});

/// CANONICAL SIGNED-IN USER ID — the one place every surface asks "who am
/// I?" (founder evidence 2026-08-17: the call room read `me['id']` while
/// the conversation surface read `me['user']['id']`; when /auth/me nests
/// the person under `user`, the realtime surface silently resolved an
/// EMPTY id. Everything keyed on identity then failed quietly — host
/// detection said "not host" (Leave instead of End), the participant-role
/// lookup matched nobody, and the in-call Go Live control never appeared
/// even though it was implemented and deployed.)
///
/// Returns '' when unknown/unauthenticated — callers must treat empty as
/// "identity not resolved yet", never as "not me".
String readUserIdFromAuthMe(Map<String, dynamic> me) {
  final user = me['user'];
  if (user is Map) {
    final nested = (user['id'] ?? '').toString().trim();
    if (nested.isNotEmpty) return nested;
  }
  return (me['id'] ?? '').toString().trim();
}

/// WHO THIS CLIENT IS — ANSWERABLE WITHOUT WAITING.
///
/// `/auth/me` is a network call, so anything that reads identity only from it
/// has a window where the answer is "unknown". That window is not theoretical:
/// on a real device, 2026-09-05, the call room built while `authMeDataProvider`
/// was still `AsyncLoading` and every surface that identifies people by
/// "whoever is not me" excluded nobody. Both people were shown their OWN name
/// as the person they were calling.
///
/// The access token already carries the answer and is present the moment the
/// session is, so it is asked first. `/auth/me` remains the authority for
/// everything ELSE about the person; it is simply not the fastest way to learn
/// their id, and identity is needed before it arrives.
///
/// `.valueOrNull` rather than `maybeWhen(data:)` for the fallback, because a
/// provider refreshing in place still holds its previous value and discarding
/// it would reintroduce the same gap on every refresh.
final currentUserIdProvider = Provider<String>((ref) {
  final store = ref.watch(tokenStoreProvider);
  final fromToken = readUserIdFromAccessToken(store.accessToken);
  if (fromToken.isNotEmpty) return fromToken;

  final me = ref.watch(authMeDataProvider).valueOrNull;
  return me == null ? '' : readUserIdFromAuthMe(me);
});

/// The member id carried by an access token, or '' when there is none.
///
/// A guest token has no member identity and must return '' rather than a guest
/// session id — a guest is not a member, and passing one off as a member id
/// would put the wrong person into every "is this me?" comparison.
///
/// Pure and synchronous, so identity never has a loading state.
String readUserIdFromAccessToken(String? token) {
  final t = (token ?? '').trim();
  if (t.isEmpty) return '';
  try {
    final parts = t.split('.');
    if (parts.length != 3) return '';
    final payload = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
    );
    if (payload is! Map) return '';
    if (payload['type'] == 'guest') return '';
    // `sub` is the standard claim; the others are accepted because this is
    // read-only inference about our OWN token, and being wrong here means
    // showing no name rather than the wrong one.
    for (final key in const ['sub', 'userId', 'id']) {
      final value = (payload[key] ?? '').toString().trim();
      if (value.isNotEmpty) return value;
    }
    return '';
  } catch (_) {
    return '';
  }
}

/// Email verification / auth validity check.
///
/// Returns:
/// - true  — confirmed verified (or institution account)
/// - false — confirmed unverified (backend said emailVerified: false)
/// - null  — unknown: /auth/me failed, empty response, or unexpected error;
///           router must treat null as "stay/wait", NOT redirect to verify-pending.
///
/// Institution accounts (accountType: INSTITUTION) are considered verified —
/// they authenticate via a separate institution login flow and are not subject
/// to the member email verification requirement.
final emailVerifiedProvider = FutureProvider<bool?>((ref) async {
  final authed = ref.watch(isAuthedProvider);
  if (!authed) return false;

  try {
    final inner = await ref.watch(authMeDataProvider.future);

    // authMeDataProvider returns {} on any error (network failure, 401, etc.).
    // Return null so the router waits rather than flashing /verify-pending.
    if (inner.isEmpty) return null;

    // Institution accounts bypass email verification entirely.
    final accountType = (inner['accountType'] ?? '').toString().toUpperCase();
    if (accountType == 'INSTITUTION') return true;

    final direct = inner['emailVerified'];
    if (direct is bool) return direct;

    final user = inner['user'];
    if (user is Map) {
      final ev = user['emailVerifiedAt'];
      if (ev != null) return true;
    }

    return false;
  } catch (_) {
    return null;
  }
});

/// Identity Foundation Phase 1 — required identity baseline (Date of Birth).
///
/// Mirrors [emailVerifiedProvider] exactly: an independent "authed but
/// incomplete" gate, not layered on top of email verification, so an
/// unverified member is not blocked from completing DOB by a different
/// unrelated gate.
///
/// Returns:
/// - true  — confirmed complete (backend said identityBaselineComplete: true)
/// - false — confirmed incomplete
/// - null  — unknown: /auth/me failed, empty response, or unexpected error;
///           router must treat null as "stay/wait", NOT redirect.
///
/// Institution accounts bypass this requirement — same rule as email
/// verification, since they authenticate via a separate institution flow.
final identityBaselineCompleteProvider = FutureProvider<bool?>((ref) async {
  final authed = ref.watch(isAuthedProvider);
  if (!authed) return false;

  try {
    final inner = await ref.watch(authMeDataProvider.future);

    if (inner.isEmpty) return null;

    final accountType = (inner['accountType'] ?? '').toString().toUpperCase();
    if (accountType == 'INSTITUTION') return true;

    final direct = inner['identityBaselineComplete'];
    if (direct is bool) return direct;

    return false;
  } catch (_) {
    return null;
  }
});

/// Derived session values used by Dio and other layers.
class SessionState {
  SessionState({
    required this.baseUrl,
    this.accessToken,
    this.refreshToken,
  });

  final String baseUrl;
  final String? accessToken;
  final String? refreshToken;
}

final sessionStateProvider = Provider<SessionState>((ref) {
  final store = ref.watch(tokenStoreProvider);

  return SessionState(
    baseUrl: AppConfig.apiBaseUrl,
    accessToken: store.accessToken,
    refreshToken: store.refreshToken,
  );
});

/// A simple auth "event bus" for GoRouter refresh.
/// We trigger it whenever TokenStore notifies.
final authEventsProvider = StreamProvider<void>((ref) {
  final controller = StreamController<void>.broadcast();

  void emit() {
    if (!controller.isClosed) controller.add(null);
  }

  emit();

  final store = ref.watch(tokenStoreProvider);

  void listener() => emit();
  store.addListener(listener);

  ref.onDispose(() {
    store.removeListener(listener);
    controller.close();
  });

  return controller.stream;
});
