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
String institutionWorkspacePath(
  String institutionId,
  InstitutionSection section,
) {
  final id = institutionId.trim();
  if (id.isEmpty) return '';
  return '/institution/$id/${section.wire}';
}

/// String overload — handy when the section is a constant literal that
/// hasn't been promoted to the enum yet (e.g. legacy code paths).
/// Prefer the enum variant for type safety.
String institutionWorkspacePathString(String institutionId, String section) {
  final id = institutionId.trim();
  final s = section.trim();
  if (id.isEmpty || s.isEmpty) return '';
  return '/institution/$id/$s';
}
