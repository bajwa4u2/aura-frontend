/// Item 15 — Rich Paste (the originally-scoped, not-yet-delivered half of
/// Item 15's structured-content boundary).
///
/// Converts a bounded, safe subset of pasted HTML into Aura's canonical
/// Markdown vocabulary (`aura-backend/src/common/content/rich-content-policy.ts`)
/// -- the SAME format every composer already persists and every renderer
/// already interprets, so nothing downstream needs to change to consume
/// pasted rich content. Deliberately NOT a general HTML-to-Markdown library:
/// only recognizes the constructs Aura's canonical vocabulary already
/// supports (bold, italic, links, lists, blockquote, inline/block code) and
/// flattens everything else (headings collapse to plain text + a line
/// break, images are dropped per the same reasoning `markdown-sanitizer.ts`
/// drops them server-side, styles/classes/scripts/unknown tags are
/// stripped entirely). The server-side `sanitizeMarkdown` authority still
/// runs on whatever this produces before persistence -- this converter is
/// a paste-time convenience, not a trusted security boundary of its own.
///
/// Pure Dart, no Flutter/web dependency, so it is independently testable
/// and reusable from any platform-specific clipboard-reading layer.
library;

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

const Set<String> _blockTags = {
  'p', 'div', 'br', 'ul', 'ol', 'li', 'blockquote', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'pre',
};

/// Converts an HTML fragment (as read from the `text/html` clipboard
/// flavor) into Aura's canonical Markdown syntax.
String htmlToMarkdown(String html) {
  final document = html_parser.parseFragment(html);
  final buffer = StringBuffer();
  _renderNodes(document.nodes, buffer, listDepth: 0, ordered: false, orderIndex: 0);
  var result = buffer.toString();
  // Collapse runs of blank lines a sequence of block-level conversions can
  // produce (e.g. an empty <div> between paragraphs) and trim edges.
  result = result.replaceAll(RegExp(r'[ \t]+\n'), '\n');
  result = result.replaceAll(RegExp(r'\n{3,}'), '\n\n');
  return result.trim();
}

void _renderNodes(
  List<dom.Node> nodes,
  StringBuffer buffer, {
  required int listDepth,
  required bool ordered,
  required int orderIndex,
}) {
  var index = orderIndex;
  for (final node in nodes) {
    if (node is dom.Text) {
      buffer.write(node.text.replaceAll(RegExp(r'\s+'), ' '));
      continue;
    }
    if (node is! dom.Element) continue;
    final tag = node.localName?.toLowerCase() ?? '';

    switch (tag) {
      case 'script':
      case 'style':
      case 'img':
      case 'svg':
        // Never carried into the canonical vocabulary -- scripts/styles
        // for safety (sanitizeMarkdown would strip remnants anyway, but
        // there is no reason to even try), images because inline media
        // is a separate governed object relationship, not body content.
        break;

      case 'br':
        buffer.write('\n');

      case 'p':
      case 'div':
        _renderNodes(node.nodes, buffer, listDepth: listDepth, ordered: false, orderIndex: 0);
        buffer.write('\n\n');

      case 'b':
      case 'strong':
        final inner = _renderInline(node);
        if (inner.trim().isNotEmpty) buffer.write('**$inner**');

      case 'i':
      case 'em':
        final inner = _renderInline(node);
        if (inner.trim().isNotEmpty) buffer.write('*$inner*');

      case 'code':
        final inner = _renderInline(node);
        if (inner.trim().isNotEmpty) buffer.write('`$inner`');

      case 'pre':
        final inner = node.text;
        buffer.write('```\n$inner\n```\n\n');

      case 'a':
        final href = node.attributes['href'] ?? '';
        final label = _renderInline(node).trim();
        if (label.isEmpty) {
          // No visible label -- nothing worth preserving.
        } else if (href.isEmpty) {
          buffer.write(label);
        } else {
          buffer.write('[$label]($href)');
        }

      case 'blockquote':
        final inner = htmlToMarkdown(node.innerHtml);
        for (final line in inner.split('\n')) {
          buffer.write('> $line\n');
        }
        buffer.write('\n');

      case 'ul':
      case 'ol':
        _renderNodes(
          node.nodes,
          buffer,
          listDepth: listDepth + 1,
          ordered: tag == 'ol',
          orderIndex: 1,
        );
        if (listDepth == 0) buffer.write('\n');

      case 'li':
        final marker = ordered ? '$index. ' : '- ';
        buffer.write(marker);
        _renderNodes(node.nodes, buffer, listDepth: listDepth, ordered: ordered, orderIndex: 0);
        buffer.write('\n');
        index += 1;

      case 'h1':
      case 'h2':
      case 'h3':
      case 'h4':
      case 'h5':
      case 'h6':
        // Headings collapse to plain emphasized-free text -- Aura's
        // conversational/lightweight rendering subset doesn't interpret
        // headings; preserve the words, not a construct nothing renders.
        buffer.write(_renderInline(node).trim());
        buffer.write('\n\n');

      default:
        // Unknown/unsupported tag (span/font/table/etc.) -- flatten to
        // its text content, matching "unsupported formatting degrades
        // predictably rather than corrupting content."
        _renderNodes(node.nodes, buffer, listDepth: listDepth, ordered: ordered, orderIndex: 0);
    }
  }
}

String _renderInline(dom.Element node) {
  final buffer = StringBuffer();
  _renderNodes(node.nodes, buffer, listDepth: 0, ordered: false, orderIndex: 0);
  return buffer.toString();
}

/// True when the clipboard's `text/html` payload is worth converting at
/// all -- an empty/whitespace-only fragment, or one with no recognized
/// formatting tags, isn't worth the conversion pass; callers should fall
/// back to the plain-text clipboard flavor in that case (never worse than
/// today's plain-paste behavior).
bool htmlFragmentHasRecognizedFormatting(String html) {
  final document = html_parser.parseFragment(html);
  return _containsFormattingTag(document.nodes);
}

bool _containsFormattingTag(List<dom.Node> nodes) {
  for (final node in nodes) {
    if (node is! dom.Element) continue;
    final tag = node.localName?.toLowerCase() ?? '';
    if (_blockTags.contains(tag) ||
        {'b', 'strong', 'i', 'em', 'code', 'pre', 'a', 'ul', 'ol', 'li'}.contains(tag)) {
      return true;
    }
    if (_containsFormattingTag(node.nodes)) return true;
  }
  return false;
}
