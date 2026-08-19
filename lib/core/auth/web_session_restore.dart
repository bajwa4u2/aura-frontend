/// WEB SESSION RESTORE — RC1, the decision half.
///
/// FOUNDER CONTRACT: **REFRESH IS NOT NAVIGATION.** Reloading on a legitimate
/// destination must reconstruct that destination.
///
/// THE DEFECT. On web the token store restores nothing — the refresh token is
/// an HttpOnly cookie Dart cannot read, so the only restore path is a cold
/// `POST /auth/refresh`. The bootstrap skipped that call entirely unless a
/// device-local hint boolean said a session had once existed here.
///
/// The hint's WRITE side has since been fixed: it is now written inside
/// `TokenStore.setSession`, the choke point every authentication path funnels
/// through, so no path can forget it. What remained is the READ side, where a
/// hint of `false` still means three different things:
///
///   * this browser genuinely never held a session — the case the hint was
///     added for, and the only case where skipping is correct;
///   * the hint was destroyed by a transient refusal, or aged out, while the
///     cookie is still alive;
///   * storage could not be read at all (private browsing throws).
///
/// In the last two, skipping the refresh states a FALSE PREMISE — "not
/// authenticated" — and every downstream gate then fires correctly against
/// it: the router discards the destination and the person lands on /home or
/// /login having lost where they were. That is the shared root cause beneath
/// F059, F061, F062 and F063.
///
/// THE CORRECTION. The hint stays an optimisation, applied ONLY where it was
/// ever justified: a fresh tab landing on a genuinely public page, where a
/// speculative refresh would produce nothing but a `401 Missing refresh
/// token` in the console. Anywhere else — a member destination, an unknown
/// route, an identity ceremony, or a device that cannot answer — Aura asks.
/// The cost of asking wrongly is one 401; the cost of skipping wrongly is a
/// person losing their place.
///
/// UNKNOWN ROUTES FAIL TOWARD ASKING. `classifyRoute` already fails closed to
/// MEMBER for anything unclassified, so a route nobody remembered to classify
/// causes an extra speculative refresh rather than a lost destination.
library;

import '../../app/route_classification.dart';
import 'session_hint.dart';

/// Why the decision came out the way it did — carried so a log line or a test
/// failure names the actual reason rather than just `false`.
enum RestoreDecisionReason {
  /// A session existed here; ask for it back.
  hintPresent,

  /// The device could not be asked. "I cannot know" is not "never signed in".
  hintUnavailable,

  /// No hint, but this destination is not a public page — it needs a session
  /// to mean anything, so a speculative refresh is worth one possible 401.
  destinationRequiresSession,

  /// No hint and a public landing page: the one case skipping is correct.
  publicLandingWithoutHint,
}

class WebSessionRestoreDecision {
  const WebSessionRestoreDecision(this.attempt, this.reason);

  final bool attempt;
  final RestoreDecisionReason reason;
}

/// Pure, so the rule is testable without a browser, a router or a clock.
WebSessionRestoreDecision decideWebSessionRestore({
  required SessionHintStatus status,
  required String landingPath,
}) {
  switch (status) {
    case SessionHintStatus.present:
      return const WebSessionRestoreDecision(
          true, RestoreDecisionReason.hintPresent);
    case SessionHintStatus.unavailable:
      return const WebSessionRestoreDecision(
          true, RestoreDecisionReason.hintUnavailable);
    case SessionHintStatus.absent:
      break;
  }

  // `/_boot` is the router's own transient path, not a destination anyone
  // browses to. Reloading while it is on screen must still restore, or the
  // reload lands permanently signed-out on what is meant to be a moment.
  if (isBootPath(landingPath)) {
    return const WebSessionRestoreDecision(
        true, RestoreDecisionReason.destinationRequiresSession);
  }

  // PUBLIC covers marketing, published reading and the plain sign-in pages.
  // Identity ceremonies (/complete-identity, /verify-pending) classify as
  // AUTH_ACTION, not PUBLIC, and REQUIRE a session — skipping there would
  // strand someone mid-ceremony on reload.
  if (classifyRoute(landingPath) == RouteClass.public) {
    return const WebSessionRestoreDecision(
        false, RestoreDecisionReason.publicLandingWithoutHint);
  }

  return const WebSessionRestoreDecision(
      true, RestoreDecisionReason.destinationRequiresSession);
}
