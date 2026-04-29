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
  } else if (normalizedPath == '/settings/communications') {
    normalizedPath = '/me/settings/communications';
  } else if (normalizedPath == '/correspondence') {
    normalizedPath = '/messages';
  } else if (normalizedPath.startsWith('/correspondence/')) {
    normalizedPath = '/me$normalizedPath';
  } else if (normalizedPath == '/conversations') {
    normalizedPath = '/messages';
  } else if (normalizedPath.startsWith('/spaces/')) {
    normalizedPath = '/me/correspondence/${normalizedPath.substring('/spaces/'.length)}';
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
      path.startsWith('/support/') ||
      path == '/institutions' ||
      path.startsWith('/institutions/');
}
