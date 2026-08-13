/// Item 15 — Rich-Text Composition + Structured-Content Boundary.
///
/// A deliberately lightweight, CONVERSATIONAL subset of Aura's canonical
/// markdown vocabulary (`aura-backend/src/common/content/rich-content-policy.ts`):
/// **bold**, *italic*, `inline code`, and [text](url) links only -- no
/// headings/lists/blockquotes/code-fences here. Those stay exclusive to
/// `AuraPublicationMarkdown` (Institution Posts / Announcements, the
/// long-form/official surfaces) -- this is the "lighter formatting UX"
/// the founder's Item 15 hybrid directive calls for on Posts/Threads/
/// Spaces/DMs: the SAME canonical stored format, a smaller interpreted
/// subset, never a second/competing format.
///
/// Pure tokenizer producing a flat, non-overlapping token list -- no
/// Flutter dependency, so it's independently testable. The widget layer
/// (`inline_rich_span_builder.dart`) turns tokens into `InlineSpan`s.
library;

enum InlineMarkdownTokenType { text, bold, italic, code, link }

class InlineMarkdownToken {
  const InlineMarkdownToken(this.type, this.text, {this.url});

  final InlineMarkdownTokenType type;
  final String text;
  final String? url;

  @override
  bool operator ==(Object other) =>
      other is InlineMarkdownToken &&
      other.type == type &&
      other.text == text &&
      other.url == url;

  @override
  int get hashCode => Object.hash(type, text, url);

  @override
  String toString() => 'InlineMarkdownToken($type, "$text"${url != null ? ', $url' : ''})';
}

// Ordered so the earliest-starting, longest match wins at each position:
// bold (**/__) before italic (*/_) so `**x**` isn't parsed as two italics.
final RegExp _tokenPattern = RegExp(
  r'(\*\*|__)(.+?)\1' // bold
  r'|(\*|_)(.+?)\3' // italic
  r'|`([^`]+)`' // inline code
  r'|\[([^\]]+)\]\(([^)]+)\)', // link
);

/// Tokenizes a plain-text segment (already sanitized/persisted server-side)
/// into a flat run of text/bold/italic/code/link tokens. Never throws --
/// unmatched/malformed syntax degrades to plain text automatically (the
/// regex simply doesn't match it).
List<InlineMarkdownToken> tokenizeInlineMarkdown(String input) {
  final tokens = <InlineMarkdownToken>[];
  var cursor = 0;

  for (final match in _tokenPattern.allMatches(input)) {
    if (match.start < cursor) continue; // overlapping match, skip
    if (match.start > cursor) {
      tokens.add(InlineMarkdownToken(
        InlineMarkdownTokenType.text,
        input.substring(cursor, match.start),
      ));
    }

    if (match.group(1) != null) {
      tokens.add(InlineMarkdownToken(InlineMarkdownTokenType.bold, match.group(2)!));
    } else if (match.group(3) != null) {
      tokens.add(InlineMarkdownToken(InlineMarkdownTokenType.italic, match.group(4)!));
    } else if (match.group(5) != null) {
      tokens.add(InlineMarkdownToken(InlineMarkdownTokenType.code, match.group(5)!));
    } else if (match.group(6) != null) {
      tokens.add(InlineMarkdownToken(
        InlineMarkdownTokenType.link,
        match.group(6)!,
        url: match.group(7),
      ));
    }

    cursor = match.end;
  }

  if (cursor < input.length) {
    tokens.add(InlineMarkdownToken(InlineMarkdownTokenType.text, input.substring(cursor)));
  }

  return tokens;
}
