/// NATIVE CONTINUATION — canonical public URL to in-app destination.
///
/// Governed by `contracts/native_continuation_contract.json`. This file is the
/// Dart half of that contract and is held to it by
/// `test/continuation/native_continuation_contract_test.dart`.
///
/// WHY THIS EXISTS
/// ---------------
/// The URL a person actually shares is the canonical one: `/p/art/my-essay`,
/// `/p/u/someone`, `/p/m/ABC123`. Those are backend-rendered share surfaces —
/// they are NOT Flutter routes. So when Android or iOS hands such a URL to the
/// app, the router has nothing to match and the person lands on home with the
/// thing they tapped gone.
///
/// That was live: the Android manifest claimed every URL on both hosts, the
/// asset-links statement validated, and every shared link therefore opened the
/// app at home. Association infrastructure was working perfectly and the
/// product consequence was destination loss on every share.
///
/// WHAT THIS IS NOT
/// ----------------
/// This is a NAME RESOLVER, not an authority. Mapping `/p/art/x` to
/// `/articles/x` grants nothing: the destination is still classified by
/// `route_classification.dart`, still gated by the router's redirect, and the
/// object's own visibility still decides what the server will return. Knowing a
/// URL has never been authorization and this must not become the thing that
/// changes that.
library;

/// A resolved continuation target.
class ContinuationTarget {
  const ContinuationTarget({required this.appPath, required this.family});

  /// In-app destination, e.g. `/articles/my-essay`.
  final String appPath;

  /// Object family from the contract, e.g. `ARTICLE`.
  final String family;

  @override
  String toString() => '$family -> $appPath';
}

/// The canonical share prefix. Everything under it is a public share URL.
const String kCanonicalSharePrefix = '/p';

/// Rejects segments that must never be interpolated into a route.
///
/// Path traversal is the obvious one, but the empty segment matters just as
/// much: `/p/art//` would otherwise resolve to `/articles/`, a different route
/// entirely, reached from a URL that looks like an article.
bool _isSafeSegment(String segment) {
  if (segment.isEmpty) return false;
  if (segment == '.' || segment == '..') return false;
  if (segment.contains('/') || segment.contains(r'\')) return false;
  // Control characters and whitespace-only segments are never legitimate ids.
  for (final unit in segment.codeUnits) {
    if (unit < 0x20 || unit == 0x7f) return false;
  }
  if (segment.trim().isEmpty) return false;
  return true;
}

/// Splits a path into non-empty segments, or null if any segment is unsafe.
List<String>? _safeSegments(String path) {
  final raw = path.split('/');
  final out = <String>[];
  for (final part in raw) {
    if (part.isEmpty) continue; // leading/duplicate separators
    if (!_isSafeSegment(part)) return null;
    out.add(part);
  }
  return out;
}

/// Maps a canonical public share path to its in-app destination.
///
/// Returns null when the path is not a canonical share URL, is malformed, or
/// names a family this build does not understand. Null means "do not claim
/// this" — the caller must fall back rather than invent a destination.
ContinuationTarget? resolveCanonicalShare(String path) {
  // A deep link is an absolute path. Accepting 'p/art/x' as well would mean a
  // relative string from anywhere resolves to a real destination, which is a
  // wider door than this needs to be.
  if (!path.startsWith('/')) return null;
  final segments = _safeSegments(path);
  if (segments == null || segments.isEmpty) return null;
  if (segments.first != 'p') return null;
  if (segments.length < 2) return null;

  final kind = segments[1];
  final rest = segments.sublist(2);

  // Whole-SEGMENT matching, deliberately. Character-prefix matching would let
  // 'a' claim '/p/art/...', because 'a' is a character prefix of 'art'. The
  // families are distinguished by whole segments and nothing else.
  switch (kind) {
    case 'i':
      // /p/i/:institutionId/:postId
      if (rest.length != 2) return null;
      return ContinuationTarget(
        appPath: '/institutions/${rest[0]}/posts/${rest[1]}',
        family: 'INSTITUTION_POST',
      );
    case 'a':
      if (rest.length != 1) return null;
      return ContinuationTarget(
        appPath: '/announcements/${rest[0]}',
        family: 'ANNOUNCEMENT',
      );
    case 'art':
      if (rest.length != 1) return null;
      return ContinuationTarget(
        appPath: '/articles/${rest[0]}',
        family: 'ARTICLE',
      );
    case 'u':
      if (rest.length != 1) return null;
      return ContinuationTarget(
        appPath: '/u/${rest[0]}',
        family: 'PERSON_PROFILE',
      );
    case 'org':
      if (rest.length != 1) return null;
      return ContinuationTarget(
        appPath: '/institutions/${rest[0]}',
        family: 'INSTITUTION_PROFILE',
      );
    case 'm':
      if (rest.length != 1) return null;
      return ContinuationTarget(
        appPath: '/meetings/join/${rest[0]}',
        family: 'MEETING',
      );
    default:
      // USER_POST is the catch-all `/p/:id`, so it is tried LAST and only when
      // there is exactly one segment after `/p`. Any deeper path with an
      // unknown prefix is an unknown family, not a post id — claiming it would
      // send someone to a post that does not exist.
      if (rest.isEmpty) {
        return ContinuationTarget(
          appPath: '/posts/$kind',
          family: 'USER_POST',
        );
      }
      return null;
  }
}

/// True when the path is addressed to the canonical share surface at all.
///
/// Used to tell "a share URL this build cannot resolve" apart from "not a share
/// URL". The first must not silently become app home; it is a real object this
/// client is too old to understand, and the honest answer is the web page.
bool isCanonicalSharePath(String path) {
  if (!path.startsWith('/')) return false;
  final segments = _safeSegments(path);
  return segments != null && segments.isNotEmpty && segments.first == 'p';
}
