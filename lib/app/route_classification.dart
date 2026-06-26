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
      // Meetings platform
      path == '/meetings' ||
      path == '/meetings/new' ||
      path.startsWith('/meetings/') ||
      path == '/availability' ||
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
