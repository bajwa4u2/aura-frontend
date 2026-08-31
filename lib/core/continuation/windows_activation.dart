/// WINDOWS ACTIVATION — turning a launch argument into a destination.
///
/// Android and iOS hand a link to the framework, and with deep linking enabled
/// the router receives it. Windows does not: an App URI Handler or an `aura://`
/// protocol activation LAUNCHES THE PROCESS with the URL as a command-line
/// argument, and Flutter forwards those to `main(List<String> args)` and no
/// further. Nothing reads them, so the app opened at its default route and the
/// destination was gone — the same failure as mobile, arriving by a different
/// road.
///
/// This is the parser for that argument list. It is deliberately strict: the
/// arguments of a process are not a trusted channel. Anything can be passed on
/// a command line, so an argument only becomes a destination when it names one
/// of the association hosts (or the app's own scheme) AND resolves to a path
/// the app already models.
library;

import 'native_continuation.dart';

/// The destination Windows launched us with, captured in `main` before the
/// first frame. Null on every other platform and on a normal launch.
String? kWindowsActivationPath;

/// Hosts Aura is associated with. Mirrors `associationScope.hosts` in
/// `contracts/native_continuation_contract.json`.
const Set<String> kAssociationHosts = {
  'auraplatform.org',
  'app.auraplatform.org',
};

/// The app's own protocol scheme, declared in `msix_config.protocol_activation`.
const String kAppScheme = 'aura';

/// Extracts an in-app destination from Windows activation arguments.
///
/// Returns null when no argument is an activation URL — the overwhelmingly
/// common case, since a normal launch passes none.
String? initialPathFromActivationArgs(Iterable<String> args) {
  for (final arg in args) {
    final path = destinationFromActivationUrl(arg);
    if (path != null) return path;
  }
  return null;
}

/// Converts a single activation URL into an in-app path, or null.
///
/// Accepts:
///   * `https://auraplatform.org/<path>` — App URI Handler activation
///   * `aura://<path>` — protocol activation
///
/// Rejects everything else, including https URLs for hosts Aura is not
/// associated with. A foreign host arriving here would mean either a
/// misconfiguration or someone passing an argument deliberately; in both cases
/// opening its path inside Aura is wrong.
String? destinationFromActivationUrl(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;

  Uri uri;
  try {
    uri = Uri.parse(trimmed);
  } on FormatException {
    return null;
  }

  String path;
  if (uri.scheme == 'https' && kAssociationHosts.contains(uri.host)) {
    path = uri.path;
  } else if (uri.scheme == kAppScheme) {
    // `aura://p/art/x` parses with host 'p' and path '/art/x'. The authority
    // is a path segment here, not a host, so it is folded back in.
    final authority = uri.host;
    path = authority.isEmpty ? uri.path : '/$authority${uri.path}';
  } else {
    return null;
  }

  if (path.isEmpty) return null;
  if (!path.startsWith('/')) path = '/$path';

  // A canonical share URL is translated to its destination; anything else is
  // passed through as a path. Either way the router still classifies and gates
  // it — this decides WHERE to go, never WHETHER the person may.
  final target = resolveCanonicalShare(path);
  if (target != null) {
    final query = uri.query;
    return query.isEmpty ? target.appPath : '${target.appPath}?$query';
  }

  // An unresolvable share URL must not become an arbitrary path: `/p/zz/thing`
  // is a real object this build does not understand, and `/p/zz/thing` is not
  // a route. Send it to the public surface rather than a dead end.
  if (isCanonicalSharePath(path)) return '/public';

  final query = uri.query;
  return query.isEmpty ? path : '$path?$query';
}
