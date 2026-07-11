bool isAdminShellPath(String path) {
  return path == '/admin' || path.startsWith('/admin/');
}

bool isInstitutionShellPath(String path) {
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
      path == '/announcements/create' ||
      path == '/ai/claim-audit' ||
      path == '/me' ||
      path == '/me/edit' ||
      path == '/me/settings/communications' ||
      path == '/settings/communications' ||
      path == '/security' ||
      path == '/me/follow-requests' ||
      path == '/me/invitations' ||
      path == '/invite' ||
      path == '/invite/create' ||
      path == '/me/correspondence' ||
      path == '/me/correspondence/create/conversation' ||
      path == '/me/correspondence/create/space' ||
      path.startsWith('/me/correspondence/') ||
      // `/meetings/join` (codeless legacy links) is a PUBLIC guest recovery
      // route — exclude it from member gating so guests are never bounced to
      // login / verify-email. Real meeting detail ids still gate normally.
      (RegExp(r'^/meetings/[^/]+$').hasMatch(path) &&
          path != '/meetings/join') ||
      // Institution onboarding/entry points — these require personal auth
      // before institution auth. NOTE: `/institutions` itself is *public*
      // discovery (the directory), so it must NOT be classified as a
      // member-shell path. Detail pages (`/institutions/:slug`, units, etc.)
      // are also public and handled by the public router.
      path == '/institutions/get-started' ||
      path == '/enter-institution' ||
      isInstitutionShellPath(path);
}

bool isPublicInviteAcceptPath(String path) => path == '/invite/accept';

/// True for the ACTIVE meeting room — a focus surface, not a normal workspace
/// page. In these routes the shell drops its persistent left navigation rail
/// (and context rail) down to a hamburger drawer so the participant grid takes
/// the full width. Matches both the member (`/meetings/:id/live`) and
/// institution (`/institution/:id/meetings/:id/live`) live routes, but NOT the
/// correspondence thread live route (`.../live/:sessionId`) or `/live-rooms`.
bool isMeetingFocusPath(String path) {
  return path.endsWith('/live') && path.contains('/meetings/');
}
