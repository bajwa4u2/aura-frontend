String normalizeMemberFacingRoute(
  String? raw, {
  String fallback = '/home',
}) {
  final value = (raw ?? '').trim();
  if (value.isEmpty) return fallback;
  if (!value.startsWith('/')) return fallback;

  // A backslash is not a path separator in the URI grammar, but browsers
  // normalise it to one -- so `/\evil.com/x` becomes `//evil.com/x` and leaves
  // the site. Rejected before parsing, because Uri keeps it in the path and
  // every check below would then pass.
  if (value.contains('\\')) return fallback;

  final uri = Uri.tryParse(value);
  if (uri == null) return fallback;

  // OPEN REDIRECT. A preserved destination is always SITE-RELATIVE. Requiring
  // a leading '/' is not enough: `//evil.com/path` starts with '/' and is a
  // protocol-relative URL, so a browser sends the person to evil.com. It was
  // reachable as `?redirect=//evil.com/...` on the auth screens -- a genuine
  // Aura link that logs someone in and then hands them to another site, which
  // is the shape every credential-phishing chain wants.
  //
  // The authority also survived `uri.replace(path: ...)` below, so even the
  // normalisation branches carried it through intact.
  if (uri.hasScheme || uri.hasAuthority) return fallback;

  final path = uri.path.trim();
  if (path.isEmpty || path == '/') return fallback;

  String normalizedPath = path;

  if (normalizedPath == '/notifications' || normalizedPath == '/notification') {
    normalizedPath = '/activity';
  } else if (normalizedPath == '/updates') {
    normalizedPath = '/activity';
  } else if (normalizedPath == '/profile') {
    normalizedPath = '/me';
  } else if (normalizedPath == '/edit-profile') {
    normalizedPath = '/me/edit';
  } else if (normalizedPath == '/settings') {
    // A bare /settings means "take me to my settings", and that answer is now
    // the Preferences landing. It used to resolve to /security, which sent
    // anyone following an old link straight past everything except sessions.
    normalizedPath = '/me/preferences';
  } else if (normalizedPath == '/settings/communications') {
    normalizedPath = '/me/settings/communications';
  } else if (normalizedPath == '/correspondence') {
    normalizedPath = '/messages';
  } else if (normalizedPath.startsWith('/correspondence/')) {
    normalizedPath = '/me$normalizedPath';
  } else if (normalizedPath == '/conversations') {
    normalizedPath = '/messages';
    // `/spaces/...` IS DELIBERATELY NOT REWRITTEN. It used to be sent to
    // /messages on the reasoning that a bare `/spaces/:id` named a retired
    // personal correspondence space — but that prefix is also the live
    // PublicSpace address, and the rule could not tell them apart.
    //
    // Measured 2026-08-23: production holds ZERO persisted deeplinks naming
    // `/spaces/`, while the product offers TEN Space addresses through the
    // public registry (civic, climate, culture, economy, education, health,
    // justice, local, science, technology). Six of those carry a PublicSpace
    // row; the other four resolve through the registry fallback and were
    // verified rendering correctly in production. Every one of the ten is a
    // live address this rule would have rewritten.
    //
    // SCOPE, stated precisely. This normaliser governs three entries only —
    // the post-sign-in `?redirect=` destination, Activity attention
    // deeplinks, and notification deeplinks. Direct URL navigation and
    // in-app Discover taps never reach it, and were never affected;
    // /spaces/civic was verified rendering correctly in production while the
    // rule was still live. The reachable exposure was the sign-in redirect:
    // arriving signed-out at a Space, then authenticating, normalised
    // `/spaces/civic` to `/messages` and lost the destination.
    //
    // A genuinely retired `/spaces/<legacy-id>` now resolves to the
    // PublicSpace surface and honestly finds nothing, which is the truthful
    // answer for a retired address — better than landing somewhere unrelated.
  } else if (normalizedPath.startsWith('/threads/')) {
    final threadId = normalizedPath.substring('/threads/'.length).trim();
    if (threadId.isNotEmpty) {
      normalizedPath = '/conversations';
      final mergedQuery = <String, String>{
        ...uri.queryParameters,
        'threadId': threadId,
      };
      final normalizedUri = uri.replace(
        path: normalizedPath,
        queryParameters: mergedQuery,
      );
      final result = normalizedUri.toString().trim();
      return result.isEmpty ? fallback : result;
    }
  } else if (normalizedPath.startsWith('/author/')) {
    normalizedPath = '/u/${normalizedPath.substring('/author/'.length)}';
  }

  final normalizedUri = uri.replace(path: normalizedPath);
  final result = normalizedUri.toString().trim();
  return result.isEmpty ? fallback : result;
}

bool shouldUseMemberShellForAuthed(String path) {
  return path == '/search' ||
      path.startsWith('/posts/') ||
      path.startsWith('/u/') ||
      path.startsWith('/announcements/') ||
      path.startsWith('/support/');
}
