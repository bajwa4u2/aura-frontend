// AXR-1 — Universal Governed Tagging: token engine contract.
//
// These tests pin the behavior every composer relies on: when the
// autocomplete opens, what it considers the active token, the email
// guard, and how selection rewrites the text.
import 'package:flutter_test/flutter_test.dart';

import 'package:aura/core/tagging/tag_token.dart';

void main() {
  group('activeTagTokenAt', () {
    test('@ at start of text opens an empty-query member token', () {
      final t = activeTagTokenAt('@', 1);
      expect(t, isNotNull);
      expect(t!.sigil, '@');
      expect(t.query, '');
      expect(t.start, 0);
    });

    test('typing continues the token up to the cursor', () {
      final t = activeTagTokenAt('hello @msb', 10);
      expect(t, isNotNull);
      expect(t!.sigil, '@');
      expect(t.query, 'msb');
      expect(t.start, 6);
      expect(t.end, 10);
    });

    test('# invokes topic tokens with the same rules', () {
      final t = activeTagTokenAt('about #Tech', 11);
      expect(t, isNotNull);
      expect(t!.sigil, '#');
      expect(t.query, 'Tech');
    });

    test('email-style @ never activates (word char before sigil)', () {
      expect(activeTagTokenAt('mail me at x@y', 14), isNull);
    });

    test('cursor inside earlier prose does not activate a later tag', () {
      // Cursor at offset 3 ("hel|lo @msb") — not inside the token.
      expect(activeTagTokenAt('hello @msb', 3), isNull);
    });

    test('whitespace ends the token', () {
      // Cursor after the space that follows the handle.
      expect(activeTagTokenAt('@msb ', 5), isNull);
    });

    test('hyphens stay inside the token (institution slugs)', () {
      final t = activeTagTokenAt('@aura-platform', 14);
      expect(t, isNotNull);
      expect(t!.query, 'aura-platform');
    });

    test('punctuation before the sigil is a valid boundary', () {
      final t = activeTagTokenAt('(see @ms', 8);
      expect(t, isNotNull);
      expect(t!.query, 'ms');
    });
  });

  group('applyTagSelection', () {
    test('replaces the active token with canonical text plus space', () {
      final token = activeTagTokenAt('hello @msb', 10)!;
      final r = applyTagSelection('hello @msb', token, '@msbajwa');
      expect(r.text, 'hello @msbajwa ');
      expect(r.cursor, 'hello @msbajwa '.length);
    });

    test('preserves text after the token', () {
      const text = 'ask @msb about it';
      // Cursor right after "@msb" (offset 8).
      final token = activeTagTokenAt(text, 8)!;
      final r = applyTagSelection(text, token, '@msbajwa');
      expect(r.text, 'ask @msbajwa  about it');
      expect(r.cursor, 'ask @msbajwa '.length);
    });

    test('topic selection inserts the compact governed form', () {
      final token = activeTagTokenAt('news #pub', 9)!;
      final r = applyTagSelection('news #pub', token, '#PublicSafety');
      expect(r.text, 'news #PublicSafety ');
    });
  });
}
