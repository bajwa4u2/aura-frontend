import 'package:flutter_test/flutter_test.dart';

import 'package:aura/core/rich_content/html_to_markdown.dart';

void main() {
  group('htmlToMarkdown', () {
    test('converts plain text unchanged', () {
      expect(htmlToMarkdown('hello world'), 'hello world');
    });

    test('converts <b>/<strong> to **bold**', () {
      expect(htmlToMarkdown('<b>bold</b>'), '**bold**');
      expect(htmlToMarkdown('<strong>bold</strong>'), '**bold**');
    });

    test('converts <i>/<em> to *italic*', () {
      expect(htmlToMarkdown('<i>italic</i>'), '*italic*');
      expect(htmlToMarkdown('<em>italic</em>'), '*italic*');
    });

    test('converts <code> to inline `code`', () {
      expect(htmlToMarkdown('<code>npm test</code>'), '`npm test`');
    });

    test('converts <a href> to [label](url)', () {
      expect(
        htmlToMarkdown('<a href="https://example.com">the docs</a>'),
        '[the docs](https://example.com)',
      );
    });

    test('converts an unordered list to - items', () {
      expect(
        htmlToMarkdown('<ul><li>first</li><li>second</li></ul>'),
        '- first\n- second',
      );
    });

    test('converts an ordered list to 1./2. items', () {
      expect(
        htmlToMarkdown('<ol><li>first</li><li>second</li></ol>'),
        '1. first\n2. second',
      );
    });

    test('converts a blockquote to > lines', () {
      expect(htmlToMarkdown('<blockquote>a quote</blockquote>'), '> a quote');
    });

    test('converts a heading to plain text, no markdown heading syntax', () {
      expect(htmlToMarkdown('<h1>Big Title</h1>'), 'Big Title');
      expect(htmlToMarkdown('<h1>Big Title</h1>'), isNot(contains('#')));
    });

    test('drops an inline <img> entirely (media is a separate governed relationship)', () {
      expect(htmlToMarkdown('before <img src="x.png"> after'), 'before  after');
    });

    test('drops <script> and <style> content entirely', () {
      expect(htmlToMarkdown('<script>alert(1)</script>safe text'), 'safe text');
      expect(htmlToMarkdown('<style>.a{color:red}</style>safe text'), 'safe text');
    });

    test('flattens an unsupported tag to its text content', () {
      expect(htmlToMarkdown('<span class="x">plain</span>'), 'plain');
      expect(htmlToMarkdown('<font color="red">plain</font>'), 'plain');
    });

    test('separates paragraphs with a blank line', () {
      expect(htmlToMarkdown('<p>first</p><p>second</p>'), 'first\n\nsecond');
    });

    test('handles a realistic mixed article fragment', () {
      final html = '<h1>Advancing Public Discourse</h1>'
          '<p>This article covers <b>structural reform</b> and its <i>implications</i>.</p>'
          '<ul><li>Point one</li><li>Point two</li></ul>';
      final result = htmlToMarkdown(html);
      expect(result, contains('Advancing Public Discourse'));
      expect(result, contains('**structural reform**'));
      expect(result, contains('*implications*'));
      expect(result, contains('- Point one'));
      expect(result, contains('- Point two'));
    });

    test('handles empty input without throwing', () {
      expect(htmlToMarkdown(''), '');
    });
  });

  group('htmlFragmentHasRecognizedFormatting', () {
    test('is false for plain text with no tags', () {
      expect(htmlFragmentHasRecognizedFormatting('just plain text'), isFalse);
    });

    test('is false for a bare unformatted <span>', () {
      expect(htmlFragmentHasRecognizedFormatting('<span>plain</span>'), isFalse);
    });

    test('is true when bold formatting is present', () {
      expect(htmlFragmentHasRecognizedFormatting('<b>bold</b>'), isTrue);
    });

    test('is true when a link is present', () {
      expect(
        htmlFragmentHasRecognizedFormatting('<a href="https://x.com">x</a>'),
        isTrue,
      );
    });

    test('is true when formatting is nested inside an unsupported wrapper', () {
      expect(
        htmlFragmentHasRecognizedFormatting('<div><span><b>bold</b></span></div>'),
        isTrue,
      );
    });
  });
}
