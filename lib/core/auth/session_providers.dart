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

/// How this account came to be admitted.
///
/// BOTH VALUES MEAN ADMITTED. They differ only in which policy answered.
enum AdmissionBasis {
  /// Admitted by the prospective floor, evaluated before the row existed.
  /// Registration collects every baseline fact, so such an account arrives
  /// complete by construction.
  prospective,

  /// Admitted before Aura asked for these facts. Continuity, never
  /// re-litigated, never retroactively suspended.
  continuity,
}

/// The person identity state `/auth/me` reports.
///
/// ── WHY THIS IS NOT ONE BOOLEAN ─────────────────────────────────────────
///
/// It used to be, and the boolean was doing the work of three separate
/// questions at once, so the router asked the wrong one. It gated ACCESS on
/// COMPLETENESS. Applied honestly — and the backend contract is honest now —
/// that locks out every member who joined before Aura asked for a date of
/// birth and a jurisdiction, which is nearly everyone on the platform today.
///
/// Founder correction, 2026-09-09: *legacy account continuity is not identity
/// baseline completeness.* They are different facts and each gets its own
/// field.
///
///   [admissionBasis]    WHICH POLICY admitted this account. Provenance, not
///                       status: both values mean admitted, so this never
///                       answers "may they operate?" and never carries
///                       suspension, revocation or session validity.
///   [baselineComplete]  Does Aura know the required facts, today, honestly?
///   [missingFields]     Which ones it does not know. A PROMPT, not a block.
///
/// A legacy member is `continuity` + incomplete. That is not a defect and not
/// a contradiction — it is the ordinary condition of someone who joined
/// before the question was asked.
class IdentityState {
  const IdentityState({
    required this.admissionBasis,
    required this.baselineComplete,
    required this.missingFields,
  });

  final AdmissionBasis admissionBasis;
  final bool baselineComplete;
  final List<String> missingFields;

  /// THE ONLY CONDITION THAT MAY HOLD SOMEONE AT THE DOOR.
  ///
  /// A prospective account is expected to be complete the moment it exists,
  /// because registration establishes the baseline before the account row is
  /// created. If one is somehow incomplete, asking once is right.
  ///
  /// A continuity account is NEVER held here. Aura may invite that person to
  /// fill the gaps; it does not make their account conditional on it.
  bool get mustCompleteBeforeUse =>
      !baselineComplete && admissionBasis == AdmissionBasis.prospective;

  /// Worth inviting the person to complete, without standing in their way.
  bool get shouldInviteCompletion => !baselineComplete && !mustCompleteBeforeUse;

  @override
  bool operator ==(Object other) =>
      other is IdentityState &&
      other.admissionBasis == admissionBasis &&
      other.baselineComplete == baselineComplete &&
      other.missingFields.length == missingFields.length &&
      other.missingFields.join(',') == missingFields.join(',');

  @override
  int get hashCode =>
      Object.hash(admissionBasis, baselineComplete, missingFields.join(','));
}

/// Identity Foundation — the canonical client view of person identity state.
///
/// Returns null when the state is UNKNOWN (/auth/me failed, was empty, or
/// errored). The router must treat null as "stay/wait", never as a reason to
/// redirect: guessing in either direction is how a transient network failure
/// becomes either a lockout or an unguarded account.
///
/// Institution accounts authenticate through a separate flow and carry no
/// person baseline, so they are reported as settled and never gated.
final identityStateProvider = FutureProvider<IdentityState?>((ref) async {
  final authed = ref.watch(isAuthedProvider);
  // No session, no person to describe — and deliberately no /auth/me call.
  // The router consults identity only for a signed-in member, so unknown is
  // both honest and inert here.
  if (!authed) return null;

  try {
    final inner = await ref.watch(authMeDataProvider.future);
    if (inner.isEmpty) return null;

    final accountType = (inner['accountType'] ?? '').toString().toUpperCase();
    if (accountType == 'INSTITUTION') {
      return const IdentityState(
        admissionBasis: AdmissionBasis.continuity,
        baselineComplete: true,
        missingFields: [],
      );
    }

    // Absent means CONTINUITY. Deliberately the conservative direction: a
    // response that does not say a floor was applied is not evidence that one
    // was, and the consequence of guessing `prospective` is holding a legacy
    // member at a door they should never have seen.
    final admissionBasis =
        (inner['admissionBasis'] ?? '').toString().toUpperCase() ==
            'PROSPECTIVE'
        ? AdmissionBasis.prospective
        : AdmissionBasis.continuity;

    final missing = <String>[
      for (final field in (inner['identityMissingFields'] as List? ?? const []))
        field.toString(),
    ];

    final reported = inner['identityBaselineComplete'];
    // A server that does not report completeness at all leaves nothing to
    // prompt about — and nothing that could justify holding anyone. It is not
    // treated as incomplete.
    final complete = reported is bool ? reported : missing.isEmpty;

    return IdentityState(
      admissionBasis: admissionBasis,
      baselineComplete: complete,
      missingFields: missing,
    );
  } catch (_) {
    return null;
  }
});

/// Completeness alone, for surfaces that only need the prompt signal.
///
/// NOT AN ACCESS GATE — see [IdentityState.mustCompleteBeforeUse] for the one
/// condition that is. null still means unknown.
final identityBaselineCompleteProvider = FutureProvider<bool?>((ref) async {
  final state = await ref.watch(identityStateProvider.future);
  return state?.baselineComplete;
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
