/// AXR-1 — Universal Governed Tagging: active-token detection.
///
/// Pure text/cursor math, no Flutter imports — unit-testable in isolation.
/// Mirrors the backend `extractHandles` boundary rule: a sigil counts only
/// at the start of the text or after a non-word character, so email
/// addresses (`x@y.z`) never trigger member autocomplete.
library;

/// The token being typed at the cursor, if any.
class ActiveTagToken {
  const ActiveTagToken({
    required this.sigil,
    required this.query,
    required this.start,
    required this.end,
  });

  /// `@` or `#`.
  final String sigil;

  /// Text typed after the sigil, up to the cursor. May be empty (the
  /// user just typed the sigil).
  final String query;

  /// Offset of the sigil character in the full text.
  final int start;

  /// Offset just past the last character of the token (== cursor).
  final int end;
}

final RegExp _wordChar = RegExp(r'[a-zA-Z0-9_]');

/// Characters allowed inside a token query while it is being typed.
/// Letters, digits, underscore, hyphen (institution slugs use hyphens).
final RegExp _tokenChar = RegExp(r'[a-zA-Z0-9_\-]');

/// Returns the tag token the cursor is currently inside, or null.
///
/// Rules:
///  * scan left from the cursor while characters match [_tokenChar];
///  * the character immediately left of that run must be `@` or `#`;
///  * the character left of the sigil must be absent (start of text) or
///    a non-word character (whitespace, punctuation) — the email guard;
///  * the cursor must sit at the end of the run (typing continues the
///    token; moving the caret into earlier prose deactivates it).
ActiveTagToken? activeTagTokenAt(String text, int cursor) {
  if (cursor < 1 || cursor > text.length) return null;

  var i = cursor;
  while (i > 0 && _tokenChar.hasMatch(text[i - 1])) {
    i--;
  }
  if (i == 0) return null;

  final sigil = text[i - 1];
  if (sigil != '@' && sigil != '#') return null;

  final beforeSigil = i - 2;
  if (beforeSigil >= 0 && _wordChar.hasMatch(text[beforeSigil])) {
    // `x@y` — email-style; not a tag.
    return null;
  }

  return ActiveTagToken(
    sigil: sigil,
    query: text.substring(i, cursor),
    start: i - 1,
    end: cursor,
  );
}

/// Replaces [token] in [text] with [insertText] plus a trailing space,
/// returning the new text and the cursor offset just past the space.
({String text, int cursor}) applyTagSelection(
  String text,
  ActiveTagToken token,
  String insertText,
) {
  final before = text.substring(0, token.start);
  final after = text.substring(token.end);
  final inserted = '$insertText ';
  return (
    text: '$before$inserted$after',
    cursor: before.length + inserted.length,
  );
}
