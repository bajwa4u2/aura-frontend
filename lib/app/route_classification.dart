bool isAdminShellPath(String path) {
  return path == '/admin' ||
      path == '/admin/communications' ||
      path == '/admin/support';
}

bool isInstitutionShellPath(String path) {
  return path == '/enter-institution' ||
      path == '/institution/sign-in' ||
      path == '/institution/create' ||
      path == '/institution/dashboard' ||
      path == '/institution/domains' ||
      path == '/institution/profile' ||
      path == '/institution/request-verification' ||
      path == '/institution/announcements' ||
      path == '/institution/correspondence';
}

bool isMemberShellPath(String path) {
  return path == '/home' ||
      path == '/messages' ||
      path.startsWith('/messages/') ||
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
      path == '/realtime' ||
      path.startsWith('/realtime/') ||
      path == '/me/correspondence' ||
      path == '/me/correspondence/create/conversation' ||
      path == '/me/correspondence/create/space' ||
      path.startsWith('/me/correspondence/') ||
      isInstitutionShellPath(path);
}

bool isPublicInviteAcceptPath(String path) => path == '/invite/accept';
