import 'package:flutter_test/flutter_test.dart';

import 'package:aura/core/rich_content/inline_markdown.dart';

void main() {
  group('tokenizeInlineMarkdown', () {
    InlineMarkdownToken text(String s) =>
        InlineMarkdownToken(InlineMarkdownTokenType.text, s);

    test('returns a single text token for plain text', () {
      expect(tokenizeInlineMarkdown('hello world'), [text('hello world')]);
    });

    test('parses **bold**', () {
      expect(
        tokenizeInlineMarkdown('a **bold** word'),
        [
          text('a '),
          const InlineMarkdownToken(InlineMarkdownTokenType.bold, 'bold'),
          text(' word'),
        ],
      );
    });

    test('parses __bold__ (alternate syntax)', () {
      expect(
        tokenizeInlineMarkdown('__bold__'),
        [const InlineMarkdownToken(InlineMarkdownTokenType.bold, 'bold')],
      );
    });

    test('parses *italic*', () {
      expect(
        tokenizeInlineMarkdown('a *italic* word'),
        [
          text('a '),
          const InlineMarkdownToken(InlineMarkdownTokenType.italic, 'italic'),
          text(' word'),
        ],
      );
    });

    test('parses `inline code`', () {
      expect(
        tokenizeInlineMarkdown('run `npm test` now'),
        [
          text('run '),
          const InlineMarkdownToken(InlineMarkdownTokenType.code, 'npm test'),
          text(' now'),
        ],
      );
    });

    test('parses [text](url) links', () {
      expect(
        tokenizeInlineMarkdown('see [the docs](https://example.com)'),
        [
          text('see '),
          const InlineMarkdownToken(
            InlineMarkdownTokenType.link,
            'the docs',
            url: 'https://example.com',
          ),
        ],
      );
    });

    test('does not confuse **bold** with two *italic* runs', () {
      expect(
        tokenizeInlineMarkdown('**bold**'),
        [const InlineMarkdownToken(InlineMarkdownTokenType.bold, 'bold')],
      );
    });

    test('handles multiple constructs in one string', () {
      final tokens = tokenizeInlineMarkdown('**bold** and *italic* and `code`');
      expect(tokens, [
        const InlineMarkdownToken(InlineMarkdownTokenType.bold, 'bold'),
        text(' and '),
        const InlineMarkdownToken(InlineMarkdownTokenType.italic, 'italic'),
        text(' and '),
        const InlineMarkdownToken(InlineMarkdownTokenType.code, 'code'),
      ]);
    });

    test('leaves unmatched/malformed syntax as plain text (degrades safely)', () {
      expect(tokenizeInlineMarkdown('an unclosed **bold'), [
        text('an unclosed **bold'),
      ]);
    });

    test('handles empty input', () {
      expect(tokenizeInlineMarkdown(''), <InlineMarkdownToken>[]);
    });

    test('leaves @mention and #hashtag characters untouched (not this tokenizer\'s concern)', () {
      expect(tokenizeInlineMarkdown('hello @jane #topic'), [
        text('hello @jane #topic'),
      ]);
    });
  });
}
