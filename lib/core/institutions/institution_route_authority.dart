/// INSTITUTION ROUTE AUTHORITY — RC2 + RC3.
///
/// FOUNDER CONTRACT: **REFRESH IS NOT NAVIGATION.** Reloading on a legitimate
/// destination must reconstruct that destination.
///
/// ─────────────────────────────────────────────────────────────────────────
/// RC2 — LOADING IS NOT ABSENCE
/// ─────────────────────────────────────────────────────────────────────────
///
/// `institutionIdentityProvider` is a synchronous view over an ASYNC source:
/// it reads `institutionAccessProvider.valueOrNull` and returns null. That
/// null means three different things — still loading, no affiliation, and no
/// access — and the route redirects read it as the second. So a cold load of
/// `/institution/edit-profile` decided "no institution" while the answer was
/// still in flight and hard-landed on the dashboard. The destination could
/// never survive a refresh, not because the person lacked authority but
/// because the router asked before the answer existed.
///
/// The snapshot below keeps the three apart. UNRESOLVED is a first-class
/// outcome, and the router parks on the existing `/_boot?redirect=` decision
/// point — the same mechanism F068 already governs, with the destination
/// preserved — instead of guessing.
///
/// No timers, no retry loops, no delays: the router already re-runs its
/// redirects when the underlying providers settle.
///
/// ─────────────────────────────────────────────────────────────────────────
/// RC3 — A PATH ID IS A CLAIM, NOT AUTHORITY
/// ─────────────────────────────────────────────────────────────────────────
///
/// The old rule was "provider identity outranks the URL": any path id that
/// disagreed with the active identity was rewritten to the active one. For a
/// member of two institutions, refreshing on institution B's page silently
/// delivered institution A's — the URL was overruled by ambient state, which
/// is precisely backwards for a destination the person typed or bookmarked.
///
/// The rule here: the path id is VALIDATED against the memberships the
/// backend reports, and only a validated claim is honoured. An id that is
/// stale, removed, unknown or foreign is NOT silently swapped for whichever
/// institution happens to be active — it goes to the governed dashboard,
/// because quietly showing someone a different institution than the one they
/// asked for is a truthfulness defect, not a convenience.
///
/// This does not make the path an authority. It makes the path a claim that
/// resolved membership either supports or refuses — the same discipline
/// `ActingContextAuthority` applies to acting identity ("a path can never
/// make someone an institution").
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'institution_access_provider.dart';

enum InstitutionRouteOutcome {
  /// Authority is still resolving. NOT "no institution". Decide nothing.
  unresolved,

  /// The path names an institution this person holds, and it is the one the
  /// workspace is currently bound to. Proceed unchanged.
  proceed,

  /// The path carries no id (a legacy shorthand). Rewrite to the canonical
  /// URL of the institution in context.
  canonicalize,

  /// The path names an institution this person genuinely holds, but NOT the
  /// one the ambient workspace is bound to.
  ///
  /// This used to canonicalise to the ambient institution, because the
  /// workspace screens read ambient state and proceeding would have rendered
  /// institution A's data under institution B's URL. That half is now closed:
  /// `/institutions/me` answers about a NAMED institution the caller holds,
  /// and the bound screens read it through
  /// `institutionWorkspaceProvider`. So this outcome now PROCEEDS — the
  /// person asked for an institution they hold, and they get it.
  authorizedElsewhere,

  /// The path names an institution this person does not hold — stale,
  /// removed, unknown or foreign. Governed fallback, never a silent swap.
  notAuthorized,

  /// Resolved, and this person holds no institution at all.
  noAffiliation,
}

class InstitutionRouteDecision {
  const InstitutionRouteDecision(this.outcome, [this.institutionId]);

  final InstitutionRouteOutcome outcome;

  /// The institution the destination should be expressed in terms of. Set for
  /// [InstitutionRouteOutcome.proceed], [canonicalize] and
  /// [authorizedElsewhere]; null otherwise.
  final String? institutionId;
}

/// Institution authority as the router needs it: resolved-ness first, then
/// what is actually held.
class InstitutionAuthoritySnapshot {
  const InstitutionAuthoritySnapshot({
    required this.resolved,
    this.activeId,
    this.authorizedIds = const <String>[],
  });

  /// False while `/institutions/me` is still in flight. The single most
  /// important bit in this file.
  final bool resolved;

  /// The institution the workspace is currently bound to, when there is one.
  final String? activeId;

  /// Every institution this person holds, from `memberships[]`. The active
  /// one is included when it is known.
  final List<String> authorizedIds;

  bool holds(String id) => authorizedIds.contains(id) || activeId == id;
}

/// Pure. No providers, no route, no clock — so every branch is testable.
InstitutionRouteDecision decideInstitutionRoute({
  required InstitutionAuthoritySnapshot snapshot,
  required String? pathId,
}) {
  if (!snapshot.resolved) {
    return const InstitutionRouteDecision(InstitutionRouteOutcome.unresolved);
  }

  final path = (pathId ?? '').trim();
  final active = (snapshot.activeId ?? '').trim();

  if (path.isEmpty) {
    if (active.isNotEmpty) {
      return InstitutionRouteDecision(
          InstitutionRouteOutcome.canonicalize, active);
    }
    if (snapshot.authorizedIds.length == 1) {
      return InstitutionRouteDecision(
          InstitutionRouteOutcome.canonicalize, snapshot.authorizedIds.single);
    }
    // None, or several with no bound context: the dashboard selector is the
    // governed answer. Choosing one arbitrarily is exactly the ambient-guess
    // this authority exists to remove.
    return const InstitutionRouteDecision(
        InstitutionRouteOutcome.noAffiliation);
  }

  if (active.isNotEmpty && path == active) {
    return InstitutionRouteDecision(InstitutionRouteOutcome.proceed, path);
  }

  if (snapshot.holds(path)) {
    return InstitutionRouteDecision(
        InstitutionRouteOutcome.authorizedElsewhere, path);
  }

  return const InstitutionRouteDecision(InstitutionRouteOutcome.notAuthorized);
}

/// The snapshot, read from the canonical access provider. `isLoading` is what
/// separates "still resolving" from "resolved and absent" — the distinction
/// `valueOrNull` destroys.
final institutionAuthoritySnapshotProvider =
    Provider<InstitutionAuthoritySnapshot>((ref) {
  final async = ref.watch(institutionAccessProvider);

  // An error is RESOLVED-but-unknown, not "still loading": parking forever on
  // a failed load would replace a lost destination with an eternal spinner,
  // which F068 forbids. It falls through to the governed fallback.
  if (async.isLoading && !async.hasValue) {
    return const InstitutionAuthoritySnapshot(resolved: false);
  }

  final access = async.valueOrNull;
  if (access == null || !access.hasAccess) {
    return const InstitutionAuthoritySnapshot(resolved: true);
  }

  final identity = ref.watch(institutionIdentityProvider);
  return InstitutionAuthoritySnapshot(
    resolved: true,
    activeId: identity?.id,
    authorizedIds: <String>[
      for (final m in access.memberships)
        if (m.id.trim().isNotEmpty) m.id.trim(),
    ],
  );
});


/// ─────────────────────────────────────────────────────────────────────────
/// MAPPING THE DECISION ONTO A ROUTE
/// ─────────────────────────────────────────────────────────────────────────
///
/// Two shapes, one decision. Kept here, pure, so the mapping is testable
/// rather than buried in a router closure.
///
/// The route constants are passed in rather than imported: this library must
/// not depend on the router it serves.

/// Canonical routes carry an id AND have a builder, so "decide nothing" can
/// be expressed literally — return null, stay put, and let the screen show
/// its own loading state. The router re-runs redirects when the provider
/// settles, so nothing has to poll, wait or retry.
String? institutionCanonicalRedirect(
  InstitutionRouteDecision decision, {
  required String section,
  required String dashboardRoute,
}) {
  switch (decision.outcome) {
    case InstitutionRouteOutcome.unresolved:
    case InstitutionRouteOutcome.proceed:
      return null;
    case InstitutionRouteOutcome.authorizedElsewhere:
      // The URL asked for an institution this person holds, and the screens
      // are now bound to the institution the URL names. Rewriting it would
      // be substituting a different institution for the one requested.
      return null;
    case InstitutionRouteOutcome.canonicalize:
      return '/institution/${decision.institutionId}/$section';
    case InstitutionRouteOutcome.notAuthorized:
    case InstitutionRouteOutcome.noAffiliation:
      return dashboardRoute;
  }
}

/// Shorthand routes carry no id and have NO builder, so they must resolve to
/// some address. While authority is unresolved that address is the existing
/// destination-preserving park (`/_boot?redirect=`), never the dashboard —
/// landing on the dashboard because the answer had not arrived yet is
/// precisely RC2.
String? institutionShorthandRedirect(
  InstitutionRouteDecision decision, {
  required String section,
  required String dashboardRoute,
}) {
  switch (decision.outcome) {
    case InstitutionRouteOutcome.unresolved:
      // STAY PUT. This used to park on `/_boot?redirect=…`, which is a real
      // navigation: it put Aura's machinery in the address bar, pushed a
      // transit page into history, and made a refresh mid-resolution re-enter
      // the transit page instead of the destination.
      //
      // "Not resolved yet" is not a destination. Returning null leaves the
      // person exactly where they asked to be while the authority settles, and
      // the router re-evaluates as soon as it does — the same shape every
      // other still-loading branch here already uses.
      return null;
    case InstitutionRouteOutcome.proceed:
    case InstitutionRouteOutcome.canonicalize:
    case InstitutionRouteOutcome.authorizedElsewhere:
      return '/institution/${decision.institutionId}/$section';
    case InstitutionRouteOutcome.notAuthorized:
    case InstitutionRouteOutcome.noAffiliation:
      return dashboardRoute;
  }
}
