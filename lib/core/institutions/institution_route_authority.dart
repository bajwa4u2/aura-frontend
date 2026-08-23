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
    this.slugToId = const <String, String>{},
    this.idToSlug = const <String, String>{},
  });

  /// ADDRESS → IDENTITY, for institutions this person holds.
  ///
  /// Founder ruling AD2 (2026-08-23): the workspace addresses an institution by
  /// its canonical slug. Authorization is unchanged and still runs against the
  /// resolved id, so this map only answers WHICH institution an address names —
  /// never whether the viewer may be there.
  ///
  /// Keys are lower-cased, because two addresses differing only in case are one
  /// identity and must not resolve differently.
  final Map<String, String> slugToId;

  /// The reverse, so a legacy id-shaped address can be canonicalized to the
  /// slug rather than merely tolerated.
  final Map<String, String> idToSlug;

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
  final slugToId = <String, String>{};
  final idToSlug = <String, String>{};
  for (final m in access.memberships) {
    final id = m.id.trim();
    final slug = m.slug.trim();
    if (id.isEmpty) continue;
    if (slug.isNotEmpty) {
      slugToId[slug.toLowerCase()] = id;
      idToSlug[id] = slug;
    }
  }

  return InstitutionAuthoritySnapshot(
    resolved: true,
    activeId: identity?.id,
    authorizedIds: <String>[
      for (final m in access.memberships)
        if (m.id.trim().isNotEmpty) m.id.trim(),
    ],
    slugToId: slugToId,
    idToSlug: idToSlug,
  );
});

/// What an address in a workspace path names, and whether it is canonical.
///
/// Founder ruling AD2/step 7: a legacy id-shaped address must RESOLVE and then
/// be canonicalized to the slug — never merely tolerated, or production would
/// keep both forms alive indefinitely.
class InstitutionAddress {
  const InstitutionAddress({
    required this.institutionId,
    required this.canonicalSlug,
    required this.isCanonical,
  });

  final String institutionId;
  final String canonicalSlug;

  /// True when the caller already used the current slug.
  final bool isCanonical;
}

/// Resolve a workspace address segment to an institution this person holds.
///
/// Returns null when the segment names nothing the snapshot knows — which
/// includes a HISTORICAL slug, since retired addresses live server-side. The
/// caller treats null as "not resolvable here" and falls through to the
/// existing governed decision rather than guessing.
///
/// RESOLUTION IS NOT AUTHORIZATION. This answers which institution is
/// addressed; standing and capability are decided afterwards, unchanged.
InstitutionAddress? resolveInstitutionAddress(
  InstitutionAuthoritySnapshot snapshot,
  String? segment,
) {
  final raw = (segment ?? '').trim();
  if (raw.isEmpty) return null;

  final bySlug = snapshot.slugToId[raw.toLowerCase()];
  if (bySlug != null) {
    return InstitutionAddress(
      institutionId: bySlug,
      canonicalSlug: snapshot.idToSlug[bySlug] ?? raw,
      // Canonical only when the case matches too: two spellings of one address
      // are one identity, and the canonical one is what gets linked.
      isCanonical: snapshot.idToSlug[bySlug] == raw,
    );
  }

  final slugForId = snapshot.idToSlug[raw];
  if (slugForId != null) {
    return InstitutionAddress(
      institutionId: raw,
      canonicalSlug: slugForId,
      isCanonical: false,
    );
  }

  return null;
}


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

// ─────────────────────────────────────────────────────────────────────────────
// THREE DESTINATIONS THAT WERE ONE CONSTANT
// ─────────────────────────────────────────────────────────────────────────────
//
// `kInstitutionDashboardRoute` was doing three different jobs at once:
//
//   1. where a person LANDS when they enter an institution;
//   2. where a person is SENT when an institution refuses them (RC4 terminal
//      denial);
//   3. where a shorthand resolves when the person holds NO institution at all.
//
// One string, three meanings, so any change to one silently changed the other
// two. Founder ruling 2026-08-22 moves institution ENTRY to Explore — and
// repointing the shared constant would have made Explore the refusal
// destination too, handing a denied person the very workspace they were just
// refused.
//
// These are now named separately. They may currently resolve to the same
// address in some cases; what matters is that they are separate QUESTIONS, so
// answering one never silently answers another.

/// Where entering an institution lands.
///
/// Founder ruling 2026-08-22: **Explore**, not Overview. Overview is
/// administrative/operational standing and setup information; the institution's
/// primary experience is what is happening inside it.
String institutionEntryDestination(String institutionId) {
  final id = institutionId.trim();
  return id.isEmpty ? kInstitutionNoAffiliationDestination : '/institution/$id/explore';
}

/// Where a person is sent when an institution REFUSES them.
///
/// RC4 terminal denial: standing inside an institution is granted by that
/// institution, never by arriving at a screen, so this deliberately keeps
/// nothing to return to. It must never follow the entry destination — a person
/// refused admin access has not earned the workspace front door.
const String kInstitutionStandingRoute = '/institution/standing';

const String kInstitutionDenialDestination =
    '$kInstitutionStandingRoute?reason=denied';

/// Where a shorthand resolves for a person who holds NO institution.
///
/// Not a refusal and not an entry: there is nothing to enter and nobody has
/// said no. The selector/standing surface is the honest answer.
const String kInstitutionNoAffiliationDestination =
    '$kInstitutionStandingRoute?reason=no-affiliation';
