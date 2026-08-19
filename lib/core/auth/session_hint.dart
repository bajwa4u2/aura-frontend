/// SESSION HINT — the device-local record that "a real member session has
/// existed in this browser", which gates the cold-load `/auth/refresh`
/// attempt in `sessionBootstrapProvider`.
///
/// RC1 / F065 (founder-frozen doctrine: AUTHENTICATION UNKNOWN/RESTORING IS
/// NOT UNAUTHENTICATED). The hint used to be written by exactly two call
/// sites — password login and code verification — while sessions are in
/// fact established by many paths (institution sign-in, guest/booker auth,
/// bootstrap refresh, silent re-auth after a 401). Any session created
/// through those other paths left the hint unwritten, so the NEXT reload
/// skipped the refresh entirely, the app reported "not authenticated",
/// and the router discarded the destination — the refresh-loses-my-place
/// class of defect.
///
/// The correction is structural, not another call site: the hint is now a
/// consequence of holding a member session (written inside
/// `TokenStore.setSession`), so no future authentication path can forget
/// it. These primitives live in their own library so both the token store
/// and the bootstrap can depend on them without an import cycle.
library;

import 'package:shared_preferences/shared_preferences.dart';

const String kSessionHintPrefKey = 'aura_session_hint';

/// Companion timestamp (epoch millis) of when the hint was last refreshed.
/// The bootstrap skips `/auth/refresh` once the hint is older than the
/// refresh-cookie max-age, because by then the cookie is guaranteed gone.
const String kSessionHintAtPrefKey = 'aura_session_hint_at';

/// Refresh-cookie max-age set by the backend (`auth.controller.ts`): 30 days.
const Duration kSessionHintMaxAge = Duration(days: 30);

/// What the device can actually tell us about a prior session.
///
/// RC1, second half. `hasSessionHint()` collapsed three different facts into
/// one boolean: "there was a session", "there was never a session", and "this
/// browser will not tell me". The third is the dangerous one — private
/// browsing makes SharedPreferences throw, and answering `false` there turned
/// "I cannot know" into "definitely never signed in", which skipped the
/// restore and declared a signed-in person unauthenticated on every reload.
enum SessionHintStatus {
  /// A member session existed on this device, recently enough that the
  /// refresh cookie can still be alive.
  present,

  /// This device says, reliably, that no usable session was established here.
  absent,

  /// The device could not be asked. Never treat this as `absent`.
  unavailable,
}

/// The tri-state read. `hasSessionHint()` remains as the boolean view for
/// callers that genuinely only care about the positive case.
Future<SessionHintStatus> readSessionHintStatus() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final flag = prefs.getBool(kSessionHintPrefKey) ?? false;
    if (!flag) return SessionHintStatus.absent;
    // Entries written before the timestamp existed carry none; treat them
    // as valid so existing users are never signed out by an upgrade.
    final at = prefs.getInt(kSessionHintAtPrefKey);
    if (at == null) return SessionHintStatus.present;
    final age = DateTime.now().millisecondsSinceEpoch - at;
    if (age < 0 || age > kSessionHintMaxAge.inMilliseconds) {
      // Older than the cookie can possibly be: the device is now reliably
      // telling us there is nothing to restore.
      return SessionHintStatus.absent;
    }
    return SessionHintStatus.present;
  } catch (_) {
    return SessionHintStatus.unavailable;
  }
}

Future<bool> hasSessionHint() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final flag = prefs.getBool(kSessionHintPrefKey) ?? false;
    if (!flag) return false;
    // Entries written before the timestamp existed carry none; treat them
    // as valid so existing users are never signed out by an upgrade.
    final at = prefs.getInt(kSessionHintAtPrefKey);
    if (at == null) return true;
    final age = DateTime.now().millisecondsSinceEpoch - at;
    if (age < 0 || age > kSessionHintMaxAge.inMilliseconds) return false;
    return true;
  } catch (_) {
    // SharedPreferences can throw in private-browsing mode; assume none.
    return false;
  }
}

Future<void> setSessionHint(bool value) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    if (value) {
      await prefs.setBool(kSessionHintPrefKey, true);
      await prefs.setInt(
        kSessionHintAtPrefKey,
        DateTime.now().millisecondsSinceEpoch,
      );
    } else {
      await prefs.remove(kSessionHintPrefKey);
      await prefs.remove(kSessionHintAtPrefKey);
    }
  } catch (_) {
    // best-effort — never let hint bookkeeping break authentication
  }
}
