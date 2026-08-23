/// C3 — CANONICAL NAVIGATION / SURFACE AUTHORITY.
///
/// A destination is a PRODUCT CONCEPT; a route is one address for it. This
/// authority owns destination identity, canonical route generation, path →
/// destination matching (including legacy aliases), and presentation-shell
/// context classification. Feature code and shells consume it; nothing else
/// may define what a primary destination is.
///
/// ── FOUNDER-APPROVED PRIMARY IA (founder-observed correction,
/// 2026-08-16 — amends the original C3 destination checkpoint) ──────────
/// Authenticated primaries — exactly four:
///   HOME · MESSAGES · DISCOVER · CREATE
/// The governing test: PRIMARY NAVIGATION REPRESENTS A FUNDAMENTAL,
/// RECURRING HUMAN INTENTION (see / continue · communicate · discover ·
/// create). Architecture proposes coherence; human use validates meaning.
///
/// Amendments by founder ruling after production observation:
///  * ME removed — identity/profile/account depth, persistently served by
///    the identity/avatar chrome; not a distinct recurring intention.
///    `/me` and all personal depth remain as destinations.
///  * MEETINGS removed — MEETINGS ARE AN INSTITUTIONAL DOMAIN. The
///    institution owns the meeting lifecycle; a member's relationship is
///    contextual (booking, invitation/attention, Me → Participations,
///    deep links). No personal meetings landing exists or is manufactured.
///  * CREATE restored — creation itself is a persistent primary human
///    intention ("I want to create something"), independent of having
///    navigated to the object's contextual home first. GLOBAL CREATE and
///    CONTEXTUAL CREATE are complementary: one lifecycle per creation
///    kind, multiple legitimate entry points.
///  * No fifth destination is invented or reserved. Attention may argue
///    for primary status at C4's own founder checkpoint, on its merits.
///
/// Public primaries: HOME · DISCOVER. Admin is a separate governed shell,
/// reached contextually from the Me destination — never primary chrome.
/// Mobile and desktop present the SAME four destination identities.
///
/// DISCOVER is the canonical consolidated intention "find something or
/// someone relevant" — People / Institutions / Spaces / search results are
/// truthful facets that remain distinct objects. Search is a mechanism;
/// Discover is the intention.
///
/// ── SHELL CONTEXT ≠ ACTING AUTHORITY ─────────────────────────────────────
/// [contextOf] classifies which PRESENTATION shell frames a path. That is
/// visual chrome only. It confers no acting identity and no authority:
/// C1 froze acting context as per-act, and no path prefix may ever decide
/// who a Person is acting as. The former `resolveActorContext` path
/// inference was retired with this authority's adoption.
library;

/// The four founder-approved authenticated primary destinations.
///
/// DECLARATION ORDER IS THE CANONICAL ORDER. Founder ruling 2026-08-22:
/// **Home · Create · Messages · Discover.** Create is a primary product
/// action, not a trailing destination parked after the browsing surfaces, so
/// it sits immediately after Home.
///
/// The order lived in a private `static const` list inside `MemberShell`. That
/// happened to feed all three of that shell's forms — rail, bottom bar and
/// drawer — so mobile and desktop agreed by construction. But nothing ENFORCED
/// it: another shell, or another platform presentation, could declare its own
/// list and drift, and no test would notice because each list would be
/// internally consistent on its own. That is the shape the notification
/// resolvers had, where ten places each answered one question correctly and
/// disagreed with each other.
///
/// So order is stated once, here, and shells consume `values`. A shell decides
/// how a destination LOOKS on its form factor — icon, label visibility, rail
/// versus bar versus drawer. It does not decide what the destinations are, or
/// what order they come in.
///
/// The PUBLIC shell is deliberately not a consumer: signed-out navigation is a
/// separately frozen set (Home · Discover), because Create and Messages are
/// not public destinations. A different question, not a divergent answer.
enum PrimaryDestination {
  home('Home', '/home'),
  create('Create', '/create'),
  messages('Messages', '/messages'),
  discover('Discover', '/discover');

  const PrimaryDestination(this.label, this.route);

  /// Canonical human label (C0 Product Language).
  final String label;

  /// The canonical route for this destination.
  final String route;
}

/// Which presentation shell frames a destination. PRESENTATION ONLY —
/// never acting authority (see library doc).
enum ShellContext { public, member, institution, admin }

class NavigationAuthority {
  const NavigationAuthority._();

  /// Founder-approved: exactly these four, in this order.
  static const List<PrimaryDestination> authenticatedPrimaries = [
    PrimaryDestination.home,
    PrimaryDestination.messages,
    PrimaryDestination.discover,
    PrimaryDestination.create,
  ];

  /// Founder-frozen public product navigation.
  static const List<PrimaryDestination> publicPrimaries = [
    PrimaryDestination.home,
    PrimaryDestination.discover,
  ];

  /// Resolves which primary destination a path belongs to, for truthful
  /// selected-state presentation. Returns null on detail routes that are
  /// not conceptually inside a primary (truthful "nothing selected").
  ///
  /// Legacy fragmented discovery entry points (search, the institutions
  /// directory, spaces discovery) are FACETS of Discover — they highlight
  /// Discover in primary navigation. The institution OBJECT route
  /// (`/institutions/:slug`) is an object detail, not the directory, and
  /// deliberately maps to no primary.
  static PrimaryDestination? primaryOf(String path) {
    final p = _normalize(path);
    if (p == '/home' || p == '/' || p == '/public') {
      return PrimaryDestination.home;
    }
    if (p == '/messages' ||
        p.startsWith('/messages/') ||
        p == '/conversations') {
      return PrimaryDestination.messages;
    }
    if (p == '/discover' ||
        p.startsWith('/discover/') ||
        p == '/search' ||
        p == '/institutions' ||
        p == '/spaces') {
      return PrimaryDestination.discover;
    }
    // The composer is the Create intention's canonical lifecycle surface;
    // it lights Create up regardless of which entry point reached it.
    if (p == '/create' || p == '/compose') {
      return PrimaryDestination.create;
    }
    // `/me` and `/meetings/…` are DEPTH, not primaries (founder-observed
    // correction 2026-08-16): personal depth is reached through the
    // identity/avatar chrome; meetings are an institutional domain with
    // contextual personal relationships. Truthful no-selection.
    return null;
  }

  /// PRESENTATION shell classification (chrome only — never authority).
  ///
  /// Post-DR4 this is DESTINATION-IDENTITY classification, not path
  /// inference: the per-route demolition test proved `/institution/:id/…`
  /// is the single canonical address space of institution-owned contextual
  /// depth (the two pure duplicates were retired to aliases), so matching
  /// that space identifies WHICH destinations these are — it manufactures
  /// nothing. Acting identity remains per-act (C1) and is pinned as
  /// independent of this classification.
  static ShellContext contextOf(String path, {required bool isAuthed}) {
    // Alias-aware: a retired mirror address classifies as its CANONICAL
    // destination, so a legacy alias can never summon institution chrome
    // for a non-institution destination (defense in depth — the router
    // redirects aliases before any shell builds, but the classification
    // must be truthful on its own).
    final canonical = legacyAliasTarget(path);
    final p = _normalize(canonical ?? path);
    if (p == '/admin' || p.startsWith('/admin/')) return ShellContext.admin;
    if (p == '/institution' || p.startsWith('/institution/')) {
      return ShellContext.institution;
    }
    return isAuthed ? ShellContext.member : ShellContext.public;
  }

  // ── Canonical global actions ─────────────────────────────────────

  /// INSTITUTION ONBOARDING — a first-class ACQUISITION ACTION whose
  /// visibility is LIFECYCLE-CONTEXTUAL, not a permanent primary
  /// (founder ruling 2026-08-16): prominent while the member has no
  /// institutional participation (desktop header action), and an
  /// accessible secondary action afterwards (account menu — multi-
  /// institution membership is a real supported case, so the action
  /// never disappears entirely). It is NOT a Create domain (§42/§53). It is NOT a primary destination,
  /// NOT a Discover tenant, and never buried behind redirects. This
  /// address is the ONE canonical onboarding journey — every entry point
  /// routes here; nothing may fork a second wizard.
  static const String institutionOnboardingRoute = '/institutions/get-started';

  /// NEW CONVERSATION — the one canonical conversation-creation flow of
  /// the clean-sheet Conversation System (canon 2026-08-16): choose a
  /// person, the conversation opens, talk immediately. Contextual entry
  /// on Messages and global entry from Create both lead HERE — one
  /// lifecycle, multiple legitimate entry points.
  static const String newConversationRoute = '/messages/new';

  /// Canonical Conversation address (Conversation System, 2026-08-16).
  static String conversationRoute(String conversationId) =>
      '/messages/c/$conversationId';

  /// INVITATION — person-owned invitation creation (into Aura, a space,
  /// or a thread). A creation intention: lives in Create and in Me →
  /// Connections; it is NOT global header chrome (the old header invite
  /// icon was dead parameter surface and is retired).
  static const String inviteHubRoute = '/invite';

  /// MESSAGES — the conversation primary's canonical address (used by
  /// in-body headers navigating "back to Messages" when there is no
  /// pop stack, e.g. a direct deep link).
  static const String messagesRoute = '/messages';

  /// CREATE — the creation primary's canonical address.
  static const String createRoute = '/create';

  // ── Canonical object route builders ──────────────────────────────

  static String personRoute(String handle) => '/u/$handle';
  static String institutionRoute(String slug) => '/institutions/$slug';

  /// The institution's own Spaces list. RC-C7 reconstruction: Spaces are an
  /// institution-owned contextual destination, so their address lives in the
  /// `/institution/:id/…` space this authority already governs, and the
  /// reconstructed Space surface asks here rather than composing a literal.
  static String institutionSpacesRoute(String institutionId) =>
      '/institution/$institutionId/spaces';

  static String institutionSpaceRoute(String institutionId, String spaceId) =>
      '/institution/$institutionId/spaces/$spaceId';
  static String threadRoute(String id) => '/thread/$id';
  static String directThreadRoute(String id) => '/direct/$id';
  static String postRoute(String id) => '/posts/$id';

  /// Realtime session entry (Conversation calls, Go Live broadcasts) —
  /// capabilities attach; the session screen is the one transport surface.
  static String realtimeSessionRoute(String sessionId) =>
      '/realtime/$sessionId';

  /// Joining a session directly (accepting a ring, watching a Live). The
  /// `action=join` intent belongs to the address, not to scattered string
  /// building at each call site.
  ///
  /// [returnTo] travels WITH the intent rather than instead of it. The accept
  /// path used to navigate to `?returnTo=…` alone, so the room mounted with no
  /// join intent in its address: the person who had just accepted was shown
  /// "Ready to join / Tap Join call to enter" and had to accept a second time
  /// — the classical stall. F044 named this exact state (POST-ACCEPT) and
  /// repaired the in-frame flash, but the address itself still said nothing,
  /// so whenever the join did not survive the navigation the instruction was
  /// not a flash but a dead end.
  static String realtimeSessionJoinRoute(String sessionId, {String? returnTo}) {
    final base = '${realtimeSessionRoute(sessionId)}?action=join';
    final target = (returnTo ?? '').trim();
    if (target.isEmpty) return base;
    return '$base&returnTo=${Uri.encodeComponent(target)}';
  }

  /// The global Live directory — "what is live on Aura right now".
  /// Discovery only; Live never originates here (founder ruling
  /// 2026-08-17: origination is contextual, discovery is global).
  static const String liveDirectoryRoute = '/realtime';

  /// Published Article canonical address (identity survives revision —
  /// founder ruling 2026-08-16: same identity, same canonical URL).
  static String articleRoute(String slug) => '/articles/$slug';

  /// Article editor for an existing draft or published article.
  static String articleEditorRoute(String articleId) =>
      '/articles/write/$articleId';

  /// DR4 — legacy mirrored-alias resolution. The per-route demolition test
  /// (roadmap C3) proved exactly TWO mirrors were pure duplicates of
  /// global objects; their addresses survive only as aliases resolved
  /// here. Everything else under `/institution/:id/…` is genuinely
  /// institution-owned contextual depth — the single canonical home of
  /// those destinations, not a mirror of anything.
  ///
  /// Returns the canonical route for a retired legacy path, or null when
  /// the path is not a retired alias.
  static String? legacyAliasTarget(String path) {
    final p = _normalize(path);
    final person = RegExp(r'^/institution/[^/]+/u/([^/]+)$').firstMatch(p);
    if (person != null) return personRoute(person.group(1)!);
    final inst =
        RegExp(r'^/institution/[^/]+/institutions/([^/]+)$').firstMatch(p);
    if (inst != null) return institutionRoute(inst.group(1)!);
    return null;
  }

  static String _normalize(String path) {
    var p = path.trim();
    if (p.isEmpty) return '/';
    final q = p.indexOf('?');
    if (q >= 0) p = p.substring(0, q);
    if (p.length > 1 && p.endsWith('/')) p = p.substring(0, p.length - 1);
    return p;
  }
}
