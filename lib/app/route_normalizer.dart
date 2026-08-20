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
    // '/correspondence' normalised into '/me/correspondence', which Phase 5
    // retired. Normalising a stale address into a dead one is worse than
    // leaving it alone, so it now goes where personal messaging actually is.
    case '/correspondence':
    case '/me/correspondence':
      path = '/messages';
      break;
    case '/notification':
    case '/notifications':
      path = '/activity';
      break;
  }

  return uri.replace(path: path).toString();
}
