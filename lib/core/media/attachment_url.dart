// Canonical URL resolution for any attachment / media payload returned
// from the backend. Extracted from
// `lib/features/correspondence/presentation/thread/thread_utils.dart`
// (which had the most complete set of fallback keys) and from the post
// card's avatar-only helper at `post_card.dart:24`.
//
// Aura's backend returns one of six URL keys depending on the surface:
//   `displayUrl`, `playbackUrl`, `url`, `publicUrl`, `signedUrl`,
//   `originalUrl`, and (legacy) `sourceUrl` / `fileUrl` / `href` / `src`
//   / `downloadUrl`. The same priority order works for every surface,
//   so feature-local resolvers were duplicating a no-op — promoted here.

String _pickString(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final raw = map[key];
    if (raw == null) continue;
    final s = raw.toString().trim();
    if (s.isNotEmpty) return s;
  }
  return '';
}

/// Best playable / displayable URL for an attachment payload. Empty
/// string when no URL is present (caller decides whether to render a
/// placeholder).
String resolveAttachmentUrl(Map<String, dynamic> attachment) {
  return _pickString(attachment, const [
    'displayUrl',
    'playbackUrl',
    'url',
    'publicUrl',
    'signedUrl',
    'sourceUrl',
    'fileUrl',
    'href',
    'src',
    'downloadUrl',
    'originalUrl',
  ]);
}

/// Best thumbnail / preview URL for an attachment payload. Falls back
/// to the full URL when no dedicated thumb is present, so video tiles
/// always have *something* to show.
String resolveAttachmentThumbUrl(Map<String, dynamic> attachment) {
  return _pickString(attachment, const [
    'thumbnailUrl',
    'thumbUrl',
    'previewUrl',
    'posterUrl',
    'displayUrl',
    'publicUrl',
    'signedUrl',
    'url',
  ]);
}

/// Rewrite a relative avatar / media URL onto the configured uploads
/// origin. Replaces the post-card-only helper at
/// `lib/features/feed/presentation/post_card.dart::_resolveAvatarUrl`,
/// which was the only place this rewrite happened — messages and feed
/// cards never did it, so a relative URL rendered only in posts.
///
/// Behaviour:
///   * absolute URL → returned unchanged
///   * empty / null → returned as null
///   * relative path → joined with the configured `UPLOADS_BASE_URL`
///     environment value if defined; otherwise returned unchanged so
///     callers can still attempt to resolve relative-to-the-API-host.
String? rewriteRelativeMediaUrl(String? raw, {String? uploadsBaseUrl}) {
  if (raw == null) return null;
  final v = raw.trim();
  if (v.isEmpty) return null;
  if (v.startsWith('http://') || v.startsWith('https://')) return v;
  if (v.startsWith('data:') || v.startsWith('blob:')) return v;
  final base = (uploadsBaseUrl ?? const String.fromEnvironment('UPLOADS_BASE_URL')).trim();
  if (base.isEmpty) return v;
  if (base.endsWith('/') && v.startsWith('/')) return '$base${v.substring(1)}';
  if (!base.endsWith('/') && !v.startsWith('/')) return '$base/$v';
  return '$base$v';
}
