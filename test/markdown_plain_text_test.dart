import 'package:flutter_test/flutter_test.dart';

import 'package:aura/core/rich_content/markdown_plain_text.dart';

void main() {
  group('markdownToPlainText', () {
    test('leaves plain text untouched', () {
      expect(markdownToPlainText('Hello world'), 'Hello world');
    });

    test('strips bold/italic markers, keeping the inner text', () {
      expect(
        markdownToPlainText('**bold** and *italic* and __also bold__'),
        'bold and italic and also bold',
      );
    });

    test('reduces a link to its label', () {
      expect(
        markdownToPlainText('See [the announcement](https://example.com/a)'),
        'See the announcement',
      );
    });

    test('reduces an image to its alt text', () {
      expect(
        markdownToPlainText('![Quarterly chart](https://example.com/c.png)'),
        'Quarterly chart',
      );
    });

    test('strips heading markers', () {
      expect(markdownToPlainText('# Title\n\nBody text'), 'Title\n\nBody text');
    });

    test('strips blockquote markers', () {
      expect(markdownToPlainText('> A quoted line'), 'A quoted line');
    });

    test('strips list markers', () {
      expect(
        markdownToPlainText('- first\n- second\n1. one\n2. two'),
        'first\nsecond\none\ntwo',
      );
    });

    test('strips inline and fenced code markers, keeping the code text', () {
      expect(markdownToPlainText('run `npm test` please'), 'run npm test please');
      expect(markdownToPlainText('```\nconst x = 1;\n```'), 'const x = 1;');
    });

    test('preserves @mention and #hashtag tokens unchanged', () {
      expect(markdownToPlainText('hello @jane, see #topic'), 'hello @jane, see #topic');
    });

    test('collapses excessive blank lines', () {
      expect(markdownToPlainText('a\n\n\n\n\nb'), 'a\n\nb');
    });

    test('handles empty input without throwing', () {
      expect(markdownToPlainText(''), '');
    });
  });
}
