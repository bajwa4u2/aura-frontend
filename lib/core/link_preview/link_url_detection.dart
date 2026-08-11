/// Compose Link Intelligence / OG Preview -- Phase 1.
///
/// Detects the first http(s) URL present in free-form compose text.
/// Deliberately a simple, bounded regex scan over the whole text (not a
/// cursor-anchored live-token scan like `core/tagging/tag_token.dart`'s
/// `@`/`#` detection) -- a URL isn't typed character-by-character the same
/// way a mention is; the composer calls this on every text change and
/// compares the result to what's currently attached, not on every
/// keystroke's cursor position.
library;

final RegExp _urlPattern = RegExp(
  r'(https?://[^\s<>"' r"']+)",
  caseSensitive: false,
);

/// Returns the first http(s) URL found in [text], or null if none.
/// A trailing sentence-punctuation character immediately after the URL
/// (`.`, `,`, `)`, `!`, `?`) is stripped, since it's almost always
/// punctuation rather than part of the link.
String? firstUrlIn(String text) {
  final match = _urlPattern.firstMatch(text);
  if (match == null) return null;
  var url = match.group(0)!;
  while (url.isNotEmpty && '.,!?)'.contains(url[url.length - 1])) {
    url = url.substring(0, url.length - 1);
  }
  return url.isEmpty ? null : url;
}
