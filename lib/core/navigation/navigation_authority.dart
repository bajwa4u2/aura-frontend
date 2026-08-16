/// C3 — CANONICAL NAVIGATION / SURFACE AUTHORITY.
///
/// A destination is a PRODUCT CONCEPT; a route is one address for it. This
/// authority owns destination identity, canonical route generation, path →
/// destination matching (including legacy aliases), and presentation-shell
/// context classification. Feature code and shells consume it; nothing else
/// may define what a primary destination is.
///
/// ── FOUNDER-FROZEN PRIMARY IA (C3 destination checkpoint, 2026-08-16) ────
/// Authenticated primaries — exactly five, frozen:
///   HOME · MESSAGES · DISCOVER · MEETINGS · ME
/// Public primaries: HOME · DISCOVER. About is informational depth; Sign
/// in / Join are account actions. Admin is a separate governed shell,
/// reached contextually from Me — never primary chrome. CREATE is a
/// contextual consequential action, not a destination. Mobile and desktop
/// present the SAME five destination identities.
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

/// The five founder-frozen authenticated primary destinations.
enum PrimaryDestination {
  home('Home', '/home'),
  messages('Messages', '/messages'),
  discover('Discover', '/discover'),
  meetings('Meetings', '/meetings'),
  me('Me', '/me');

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

  /// Founder-frozen: exactly these five, in this order.
  static const List<PrimaryDestination> authenticatedPrimaries = [
    PrimaryDestination.home,
    PrimaryDestination.messages,
    PrimaryDestination.discover,
    PrimaryDestination.meetings,
    PrimaryDestination.me,
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
        p == '/conversations' ||
        p == '/me/correspondence' ||
        p.startsWith('/me/correspondence/')) {
      return PrimaryDestination.messages;
    }
    if (p == '/discover' ||
        p.startsWith('/discover/') ||
        p == '/search' ||
        p == '/institutions' ||
        p == '/spaces') {
      return PrimaryDestination.discover;
    }
    if (p == '/meetings' || p.startsWith('/meetings/')) {
      return PrimaryDestination.meetings;
    }
    if (p == '/me' || (p.startsWith('/me/') && !p.startsWith('/me/correspondence'))) {
      return PrimaryDestination.me;
    }
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

  // ── Canonical object route builders ──────────────────────────────

  static String personRoute(String handle) => '/u/$handle';
  static String institutionRoute(String slug) => '/institutions/$slug';
  static String threadRoute(String id) => '/thread/$id';
  static String directThreadRoute(String id) => '/direct/$id';
  static String postRoute(String id) => '/posts/$id';

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
