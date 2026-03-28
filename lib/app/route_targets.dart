String normalizeMemberFacingRoute(
  String? raw, {
  String fallback = '/home',
}) {
  final value = (raw ?? '').trim();
  if (value.isEmpty) return fallback;
  if (!value.startsWith('/')) return fallback;

  final uri = Uri.tryParse(value);
  if (uri == null) return fallback;

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
    normalizedPath = '/security';
  } else if (normalizedPath == '/correspondence') {
    normalizedPath = '/me/correspondence';
  } else if (normalizedPath.startsWith('/correspondence/')) {
    normalizedPath = '/me$normalizedPath';
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
      path.startsWith('/announcements/');
}
