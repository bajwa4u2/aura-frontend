// Centralized path builders for the institution workspace.
//
// Routing-hardening pass — every CTA, tab, and `returnTo` reference
// in the institution workspace now goes through this helper instead
// of hand-building strings. Two outcomes follow:
//
//  1. The id-aware canonical pattern is the only way to construct a
//     workspace URL — there is no place left in the app where a
//     scoped path can be built without an explicit id.
//  2. If the section names ever change, they change in one place.
//
// Shorthand routes (`/institution/<section>` without an id) are NOT
// returned by these helpers. They exist purely as redirect entries in
// the router; nothing in the runtime constructs them.

/// Sections recognized by the institution workspace shell.
///
/// Wire values map 1:1 to GoRoute paths:
///   `/institution/:institutionId/<value>`
enum InstitutionSection {
  dashboard('dashboard'),
  profile('profile'),
  editProfile('edit-profile'),
  requestVerification('request-verification'),
  correspondence('correspondence'),
  domains('domains'),
  announcements('announcements'),
  spaces('spaces'),
  messages('messages'),
  activity('activity'),
  liveRooms('live-rooms'),
  invites('invites'),
  members('members'),
  joinRequests('join-requests'),
  explore('explore'),
  units('units'),
  billing('billing');

  const InstitutionSection(this.wire);
  final String wire;
}

/// Build a canonical institution-scoped path. Returns the empty string
/// when [institutionId] is empty so callers can decide whether to gate
/// the CTA (e.g. show the tab as disabled) instead of producing a
/// shorthand path that would route through a redirect.
/// THE ADDRESS IS THE SLUG (founder ruling AD2, 2026-08-23).
///
/// Callers pass an institution's canonical ADDRESS, not its persistence id.
/// The parameter is named `address` deliberately: `institutionId` is what let
/// database identity become the product's information architecture by
/// accident, and a name that says "id" invites the next caller to pass one.
///
/// A raw id still RESOLVES (the router canonicalizes it on arrival, so durable
/// links keep working) but nothing here may MINT one — that is the difference
/// between compatibility and drift.
String institutionWorkspacePath(
  String address,
  InstitutionSection section,
) {
  final a = address.trim();
  if (a.isEmpty) return '';
  return '/institution/$a/${section.wire}';
}

/// One UNIT, as an operating context inside the institution.
///
/// Owned here rather than minted at call sites: a unit's address is navigation
/// grammar like any other, and the Navigation Authority is where that lives.
/// A unit's address is BOTH slugs — matching the public precedent
/// `/institutions/:slug/units/:unitSlug` rather than inventing a second shape
/// for the same resource inside the workspace.
String institutionUnitContextPath(String address, String unitAddress) {
  final a = address.trim();
  final unit = unitAddress.trim();
  if (a.isEmpty || unit.isEmpty) return '';
  return '/institution/$a/units/$unit';
}

/// String overload — handy when the section is a constant literal that
/// hasn't been promoted to the enum yet (e.g. legacy code paths).
/// Prefer the enum variant for type safety.
String institutionWorkspacePathString(String address, String section) {
  final a = address.trim();
  final s = section.trim();
  if (a.isEmpty || s.isEmpty) return '';
  return '/institution/$a/$s';
}
