String normalizeAppLocation(
  String? location, {
  String fallback = '/home',
}) {
  final raw = (location ?? '').trim();
  if (raw.isEmpty) return fallback;

  Uri? uri;
  try {
    uri = Uri.parse(raw);
  } catch (_) {
    return fallback;
  }

  var path = uri.path.trim();
  if (path.isEmpty || path == '/') return fallback;

  // Keep this intentionally narrow.
  // Only normalize member-facing legacy paths that are already known to be stale.
  switch (path) {
    case '/correspondence':
      path = '/me/correspondence';
      break;
    case '/notification':
    case '/notifications':
      path = '/activity';
      break;
  }

  return uri.replace(path: path).toString();
}
