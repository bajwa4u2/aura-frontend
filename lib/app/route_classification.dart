/// ROUTE CLASSIFICATION AUTHORITY — founder ruling 2026-08-17 (F069).
///
/// Frozen invariants:
///   1. **UNKNOWN IS NOT PUBLIC.**
///   2. Every route declared by Aura's router must be explicitly classified.
///   3. Minimum semantic classes: PUBLIC · MEMBER · AUTH_ACTION ·
///      GUEST_REACHABLE. Further classes only where a genuinely distinct
///      authority model exists, explicitly named and tested.
///   4. GUEST_REACHABLE describes a route's permitted ENTRY MODEL. It does
///      NOT itself authorize the visitor — guest admission still depends on
///      the canonical guest/invitation/Meeting/realtime authority for that
///      destination.
///   5. Unknown/unclassified routes **fail closed** (treated as MEMBER)
///      rather than silently rendering unauthenticated.
///
/// Why this exists: classification used to live inside the router closure
/// as an un-testable, hand-maintained allowlist that failed OPEN. Verified
/// consequence — `/articles/write` was excluded from the public list but
/// never added to the member list, so an unauthenticated visitor reached
/// the authoring surface with no redirect and no destination preservation
/// (a second root cause of "my article draft disappeared on refresh",
/// independent of durable draft identity).
///
/// The `c3_route_classification_gate` test proves every path declared in
/// `router.dart` lands in an explicit class, so a future route cannot
/// silently bypass this contract.
library;

/// The four canonical entry models. See invariant 3.
enum RouteClass {
  /// Open to the internet: marketing, discovery, published reading.
  public,

  /// Requires an authenticated Aura member session.
  member,

  /// Authentication ceremonies (login, verification, identity completion).
  authAction,

  /// A guest MAY enter without a member session — the destination's own
  /// canonical authority decides whether this particular guest is admitted.
  guestReachable,
}

const String kRouterBootPath = '/_boot';
const String kCompleteIdentityPath = '/complete-identity';

bool isBootPath(String path) => path == kRouterBootPath;

bool isPlainAuthPage(String path) =>
    path == '/login' || path == '/register' || path == '/auth';

bool isAuthActionPath(String path) {
  return path == '/forgot-password' ||
      path == '/reset-password' ||
      path == '/verify-email' ||
      path == '/verify-pending' ||
      // Institution sign-in is an authentication ceremony, not a member
      // surface: a person must be able to reach it to establish
      // institution authority (F069 sweep — previously unclassified).
      path == '/institution/sign-in' ||
      path == kCompleteIdentityPath;
}

/// GUEST_REACHABLE — booking and meeting-entry surfaces an invited guest
/// legitimately reaches without an Aura account. Deliberately NOT collapsed
/// into PUBLIC (founder ruling): these are not open reading surfaces, they
/// are guarded destinations with a guest entry model. Meeting admission
/// semantics are untouched by this classification.
bool isGuestReachablePath(String path) {
  // Public booking pages (personal and institution-owned).
  if (path.startsWith('/meet/')) return true;
  if (path.startsWith('/i/')) return true;

  // Pre-join / code-entry recovery — an external guest must never hit a
  // login wall here.
  if (path == '/meetings/join') return true;
  if (path == '/meetings/join-error') return true;
  if (path.startsWith('/meetings/join/')) return true;

  // The meeting room itself: lobby, waiting, live, summary.
  if (RegExp(
    r'^/meetings/[^/]+/(room|waiting|live|summary|post-meeting)$',
  ).hasMatch(path)) {
    return true;
  }

  // Realtime session surfaces accept guest entry (meeting guests arrive
  // with a guestId); the realtime authority still adjudicates admission.
  if (path == '/realtime' || path.startsWith('/realtime/')) return true;

  return false;
}

bool isPublicInviteAcceptPath(String path) => path == '/invite/accept';

/// PUBLIC — open to the internet.
/// True for the authoring/editing tail of an otherwise public object route.
/// Kept explicit rather than inferred: this names the ACT, not the prefix.
bool _isEditingPath(String path) {
  final segments = path.split('?').first.split('/')
    ..removeWhere((s) => s.isEmpty);
  return segments.isNotEmpty &&
      (segments.last == 'edit' || segments.last == 'write');
}

bool isPublicPath(String path) {
  if (path == '/' || path == '/public') return true;
  if (isBootPath(path)) return true;
  if (isPlainAuthPage(path)) return true;
  if (isAuthActionPath(path)) return true;

  if (path == '/mission' ||
      path == '/white-paper' ||
      path == '/terms' ||
      path == '/founder' ||
      path == '/privacy' ||
      path == '/child-safety' ||
      path == '/safety' ||
      path == '/trust-safety' ||
      path == '/contact' ||
      path == '/account-deletion' ||
      path == '/investors' ||
      // Institutional discovery — directory, detail and public unit pages
      // are browsable without sign-in; only the onboarding wizard is gated
      // (matched by isMemberShellPath).
      path == '/institutions' ||
      (path.startsWith('/institutions/') &&
          path != '/institutions/get-started') ||
      path == '/patrons' ||
      path == '/supporters' ||
      path == '/search' ||
      path == '/discover' ||
      // SPACES — public subject-based discovery and participation
      // contexts (founder ruling 2026-08-17). A signed-out visitor may
      // browse the directory, open a Space, consume its legitimate public
      // content and understand its subject. PARTICIPATION remains governed
      // independently: route classification describes what may RENDER, it
      // never grants authority to act. See the classification-is-not-
      // authorization invariant in the F069 gate.
      path == '/spaces' ||
      path.startsWith('/spaces/') ||
      // RC6 — READING a post is public; EDITING one is not. The broad
      // `/posts/` prefix classified `/posts/:id/edit` PUBLIC, and because
      // the public check runs before the member matcher, the post editor was
      // reachable by classification without a session. A read-only sibling
      // being public never implies its editor is.
      (path.startsWith('/posts/') && !_isEditingPath(path)) ||
      path.startsWith('/u/') ||
      path.startsWith('/author/') ||
      path.startsWith('/support/') ||
      isPublicInviteAcceptPath(path)) {
    return true;
  }

  if (path == '/announcements') return true;
  if (path.startsWith('/announcements/')) return true;

  // Articles are durable public thought — READING is public; the authoring
  // paths are member-gated (see isMemberShellPath).
  if (path == '/discover/articles') return true;

  // INSTITUTIONS DISCOVERY is public for the same reason the directory is:
  // institutional participation is public record, and a signed-out visitor may
  // browse it. Relevance ordering is the part that needs a session, and the
  // surface reads the PUBLIC projections when there is none — so classifying
  // this public grants no personal recommendation to anyone.
  if (path == '/discover/institutions') return true;
  if (path.startsWith('/articles/') && !path.startsWith('/articles/write')) {
    return true;
  }

  return false;
}

/// The single classification entry point. Order matters: explicit member
/// authoring paths win over the broad public article prefix, and the
/// fall-through is MEMBER — never public (invariant 1 + 5).
RouteClass classifyRoute(String path) {
  // Order is behavioral, not cosmetic. Open-entry models are evaluated
  // BEFORE the member allowlist because the member matcher is partly
  // pattern-based: `^/meetings/[^/]+$` legitimately claims meeting detail
  // pages but also swallows `/meetings/join-error`, a guest recovery
  // screen. Under the old router that collision was masked (the blanket
  // isPublic check won); classifying member-first would have started
  // bouncing meeting guests to a login wall — a Meetings regression the
  // F069 gate caught before it shipped.
  if (isAuthActionPath(path)) return RouteClass.authAction;
  if (isGuestReachablePath(path)) return RouteClass.guestReachable;
  if (isPublicPath(path)) return RouteClass.public;
  if (isMemberShellPath(path)) return RouteClass.member;
  return RouteClass.member; // fail closed — unknown is not public
}

/// True when a visitor without a member session may legitimately *reach*
/// this route (they may still be refused by the destination's own
/// authority — see invariant 4). Replaces the router's former blanket
/// `isPublic` check so guest and auth-ceremony routes keep behaving
/// exactly as before while remaining distinctly classified.
bool routeAllowsUnauthenticatedEntry(String path) {
  final c = classifyRoute(path);
  return c == RouteClass.public ||
      c == RouteClass.authAction ||
      c == RouteClass.guestReachable;
}

bool isAdminShellPath(String path) {
  return path == '/admin' || path.startsWith('/admin/');
}

bool isInstitutionShellPath(String path) {
  // STANDING IS NOT THE WORKSPACE (founder ruling D5). A person who was
  // refused, or who holds no institution, must not be dressed in workspace
  // chrome — that would present a denial as though they had entered.
  if (path == '/institution/standing') return false;

  if (path == '/institution/create' ||
      path == '/institution/dashboard' ||
      path == '/institution/domains' ||
      path == '/institution/profile' ||
      path == '/institution/edit-profile' ||
      path == '/institution/request-verification' ||
      path == '/institution/announcements' ||
      path == '/institution/correspondence' ||
      path == '/institution/live-rooms') {
    return true;
  }
  // /institution/:id/... — dynamic id-based institution workspace routes
  return RegExp(r'^/institution/[^/]+/').hasMatch(path);
}

bool isMemberShellPath(String path) {
  return path == '/home' ||
      // Institution STANDING (D5). A person who was refused, or who holds no
      // institution, is still a member of Aura — they get ordinary member
      // chrome, never workspace chrome. Classified explicitly so a refresh on
      // this address reconstructs it instead of falling through unknown.
      path == '/institution/standing' ||
      // CH-12 E6 — the restricted-attachment surface. MEMBER, not public: it
      // is reached from a quarantine notice addressed to one person, and the
      // server shows nothing at all to a caller without standing. Classifying
      // it public would put a governed restriction behind a URL anyone could
      // try, even though the answer would be empty.
      RegExp(r'^/media/[^/]+/restricted$').hasMatch(path) ||
      path == '/messages' ||
      path.startsWith('/messages/') ||
      path.startsWith('/direct/') ||
      path == '/direct-intent' ||
      path == '/notifications' ||
      path == '/saved' ||
      path == '/updates' ||
      path == '/conversations' ||
      path == '/activity' ||
      path == '/create' ||
      path == '/compose' ||
      // Share creates content as this member, so it is member-owned for the
      // same reason /compose is: an unauthenticated visitor has nothing to
      // share from and nowhere to share it to.
      path == '/share' ||
      path == '/announcements/create' ||
      path == '/ai/claim-audit' ||
      path == '/me' ||
      path == '/me/edit' ||
      path == '/me/settings/communications' ||
      // Preferences and its privacy surface. MEMBER: they read and write this
      // account's own settings, so an unauthenticated visitor must be sent to
      // sign in with the destination preserved rather than reaching an empty
      // shell — the F069 failure this allowlist exists to prevent.
      path == '/me/preferences' ||
      path == '/me/blocked' ||
      path == '/settings/communications' ||
      path == '/security' ||
      path == '/me/follow-requests' ||
      path == '/me/invitations' ||
      path == '/invite' ||
      path == '/invite/create' ||
      // Article AUTHORING (F069 evidence): reading an article is public,
      // but composing/editing one is a member act. This was excluded from
      // the public list yet never added here, leaving it unclassified and
      // failing open — an unauthenticated visitor reached the editor with
      // no login redirect and no destination preservation.
      path == '/articles/write' ||
      path.startsWith('/articles/write/') ||
      // RC6 — POST AUTHORING, the same shape one object over. Reading a post
      // is public; editing one is a member act. Excluding it from the public
      // prefix is only half the correction: the F069 invariant is that every
      // route matches an EXPLICIT predicate, never that it merely lands on
      // member by fall-through. (The F069 gate caught exactly that omission
      // when this fix was first written.)
      _isEditingPath(path) && path.startsWith('/posts/') ||
      // ── F069 sweep (2026-08-17): routes the router declares that the
      // classification allowlist never covered. Every one of them used to
      // fail OPEN — `requiresAuth` returned false, so an unauthenticated
      // visitor reached the surface with no login redirect and no
      // destination preservation. Admin is the starkest case: the entire
      // /admin workspace was unclassified.
      isAdminShellPath(path) ||
      path == '/thread' ||
      path.startsWith('/thread/') ||
      path == '/aura/participation' ||
      path == '/discover/people' ||
      path == '/devices' ||
      path == '/change-password' ||
      path == '/invite/import' ||
      RegExp(r'^/meetings/[^/]+/prep$').hasMatch(path) ||
      // Meeting DETAIL pages are member surfaces, but the same shape also
      // matches guest recovery screens (`/meetings/join`,
      // `/meetings/join-error`). Excluding every GUEST_REACHABLE path here
      // keeps the two classes genuinely disjoint rather than relying on
      // evaluation order to mask the overlap — guests are never bounced to
      // a login/verify wall, and Meetings behavior is unchanged.
      (RegExp(r'^/meetings/[^/]+$').hasMatch(path) &&
          !isGuestReachablePath(path)) ||
      // Institution onboarding/entry points — these require personal auth
      // before institution auth. NOTE: `/institutions` itself is *public*
      // discovery (the directory), so it must NOT be classified as a
      // member-shell path. Detail pages (`/institutions/:slug`, units, etc.)
      // are also public and handled by the public router.
      path == '/institutions/get-started' ||
      path == '/enter-institution' ||
      isInstitutionShellPath(path);
}

/// True for the ACTIVE meeting room — a focus surface, not a normal workspace
/// page. In these routes the shell drops its persistent left navigation rail
/// (and context rail) down to a hamburger drawer so the participant grid takes
/// the full width. Matches both the member (`/meetings/:id/live`) and
/// institution (`/institution/:id/meetings/:id/live`) live routes, but NOT the
/// correspondence thread live route (`.../live/:sessionId`) or `/live-rooms`.
bool isMeetingFocusPath(String path) {
  return path.endsWith('/live') && path.contains('/meetings/');
}


// ─────────────────────────────────────────────────────────────────────────
// RC6 — INSTITUTION ROUTE POLICY, DECLARED PER SECTION
// ─────────────────────────────────────────────────────────────────────────
//
// THE DEFECT. `requiresInstitutionAdmin` in the router matched exactly two
// SHORTHAND constants — `/institution/edit-profile` and
// `/institution/domains`. The canonical forms of the same destinations,
// `/institution/:id/edit-profile` and `/institution/:id/domains`, matched
// nothing and carried NO admin gate at all.
//
// That was already a hole. RC2/RC3 made it total: the shorthand routes are
// now pure redirects to the canonical form, so the only two paths the admin
// gate could ever match stopped rendering anything. An institution member
// without admin standing could open the institution's profile editor.
//
// THE CORRECTION. Policy is declared once per SECTION, and both URL forms of
// a destination resolve to the same section — so an equivalence that used to
// depend on someone remembering to list two strings is now structural.
//
// AUTHORITY BOUNDARY. This declares WHICH policy applies, never who the
// actor is or whether they satisfy it. `"/institution/" means admin` is
// exactly the inference this replaces: the section is looked up in an
// explicit table, and a section nobody declared FAILS CLOSED to the
// strictest institutional policy rather than to none.

/// What an institution destination requires of the acting member. Evaluated
/// by the router against the canonical institution authorities — this enum
/// names the requirement, it does not decide it.
enum InstitutionRoutePolicy {
  /// Not an institution workspace destination at all.
  notInstitutional,

  /// Institution access only — any member of the institution may be here.
  member,

  /// Speaking for the institution, or operational leadership.
  adminOrSpeaker,

  /// Operational leadership only.
  admin,
}

/// Declared policy per workspace section. A section absent from this map is
/// NOT assumed harmless — see `institutionRoutePolicyFor`.
const Map<String, InstitutionRoutePolicy> kInstitutionSectionPolicy = {
  // Owner/admin-held configuration: editing the institution's public identity
  // and proving ownership of its domains.
  'edit-profile': InstitutionRoutePolicy.admin,
  'domains': InstitutionRoutePolicy.admin,

  // Speaking in the institution's voice, or administering what it says.
  'announcements': InstitutionRoutePolicy.adminOrSpeaker,
  'live-rooms': InstitutionRoutePolicy.adminOrSpeaker,
  'request-verification': InstitutionRoutePolicy.adminOrSpeaker,

  // Ordinary workspace surfaces: membership is the requirement.
  'dashboard': InstitutionRoutePolicy.member,
  'profile': InstitutionRoutePolicy.member,
  'messages': InstitutionRoutePolicy.member,
  'correspondence': InstitutionRoutePolicy.member,
  'members': InstitutionRoutePolicy.member,
  'invites': InstitutionRoutePolicy.member,
  'join-requests': InstitutionRoutePolicy.member,
  'units': InstitutionRoutePolicy.member,
  'spaces': InstitutionRoutePolicy.member,
  'posts': InstitutionRoutePolicy.member,
  'public-engagement': InstitutionRoutePolicy.member,
  'meetings': InstitutionRoutePolicy.member,
  'activity': InstitutionRoutePolicy.member,
  'settings': InstitutionRoutePolicy.member,
  'analytics': InstitutionRoutePolicy.member,
  'billing': InstitutionRoutePolicy.member,
  'materials': InstitutionRoutePolicy.member,
  'summaries': InstitutionRoutePolicy.member,
  'recordings': InstitutionRoutePolicy.member,
  'availability': InstitutionRoutePolicy.member,
  'bookings': InstitutionRoutePolicy.member,

  // Member surfaces viewed from inside the institution shell — browsing,
  // a person's profile, an institution page, a direct thread. Being in the
  // workspace is the requirement; none of them is a leadership act. Found by
  // the RC6 gate rather than by memory, which is the point of the gate.
  'explore': InstitutionRoutePolicy.member,
  'u': InstitutionRoutePolicy.member,
  'institutions': InstitutionRoutePolicy.member,
  'direct': InstitutionRoutePolicy.member,
};

/// The workspace section a path addresses, in either URL form:
/// `/institution/<section>` (legacy shorthand) or
/// `/institution/:id/<section>` (canonical). Null when the path is not an
/// institution workspace destination.
String? institutionSectionOf(String path) {
  final segments = path.split('?').first.split('/')
    ..removeWhere((s) => s.isEmpty);
  if (segments.length < 2 || segments.first != 'institution') return null;

  // `/institution/<something>`: a declared section is the shorthand form;
  // anything else is an institution id addressed without a section.
  if (segments.length == 2) {
    return kInstitutionSectionPolicy.containsKey(segments[1])
        ? segments[1]
        : null;
  }
  // `/institution/:id/<section>/...`
  return segments[2];
}

/// The policy a path declares. A section that exists but was never declared
/// fails CLOSED to `admin` — the strictest institutional requirement — so a
/// new workspace surface cannot ship ungated because nobody remembered it.
/// The RC6 gate makes that failure loud rather than silent.
InstitutionRoutePolicy institutionRoutePolicyFor(String path) {
  final section = institutionSectionOf(path);
  if (section == null) {
    // `/institution/:id` alone is the workspace root: membership.
    final segments = path.split('?').first.split('/')
      ..removeWhere((s) => s.isEmpty);
    if (segments.length == 2 && segments.first == 'institution') {
      return InstitutionRoutePolicy.member;
    }
    return InstitutionRoutePolicy.notInstitutional;
  }
  return kInstitutionSectionPolicy[section] ?? InstitutionRoutePolicy.admin;
}
