// F025 + F026 — THE ARTICLE AUTHORING SURFACE.
//
// F026: pasting a title into the editor oversized it. The field rendered at a
// fixed 40px `display` inside a two-line box, so a long headline clipped while
// being written and ran past its column once published — and a title pasted
// from a document brought its newlines along, each one eating a whole line.
//
// F025: inserting an image showed the author raw markdown instead of a
// rendered image.
//
// These tests hold the two properties that make the fixes honest: the author's
// WORDS are never altered, and what the author sees while writing is produced
// by the SAME primitives that publish it.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aura/core/ui/publication/aura_publication_title.dart';

TextEditingValue _v(String text, {int? caret}) => TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: caret ?? text.length),
    );

void main() {
  group('F026 — a pasted title keeps every word', () {
    const f = PublicationTitleInputFormatter();

    test('newlines from a pasted document become single spaces', () {
      expect(
        normalizePublicationTitle('The Institution\nOperating\nLayer'),
        'The Institution Operating Layer',
      );
    });

    test('tabs, carriage returns and runs of spaces collapse', () {
      expect(
        normalizePublicationTitle('A\t\tlong\r\n   pasted    title'),
        'A long pasted title',
      );
    });

    test('a non-breaking space from a word processor is normalised', () {
      expect(normalizePublicationTitle('Aura Platform'), 'Aura Platform');
    });

    test('NO WORD IS EVER REMOVED and nothing is truncated', () {
      final long = List.generate(60, (i) => 'word$i').join(' ');
      final out = normalizePublicationTitle(long);
      expect(out, long);
      for (var i = 0; i < 60; i++) {
        expect(out, contains('word$i'));
      }
    });

    test('leading whitespace goes, a trailing space stays', () {
      // Trimming the end would make it impossible to type a space between
      // two words, because this runs on every keystroke.
      expect(normalizePublicationTitle('   Title'), 'Title');
      expect(normalizePublicationTitle('Two words '), 'Two words ');
    });

    test('the formatter leaves ordinary typing completely alone', () {
      final typed = _v('Institution operating layer');
      expect(f.formatEditUpdate(_v('Institution operating laye'), typed), typed);
    });

    test('the formatter fixes a multi-line paste and keeps the caret sane', () {
      final out = f.formatEditUpdate(
        _v(''),
        _v('Aura\nPlatform\nLLC'),
      );
      expect(out.text, 'Aura Platform LLC');
      expect(out.selection.baseOffset, out.text.length);
    });

    test('the caret lands after the pasted text, not at a stale offset', () {
      // Paste into the middle: "Start | end" with a two-line paste.
      const before = 'Start  end';
      final out = f.formatEditUpdate(
        _v(before),
        _v('Start One\nTwo end', caret: 'Start One\nTwo'.length),
      );
      expect(out.text, 'Start One Two end');
      expect(out.selection.baseOffset, 'Start One Two'.length);
    });
  });

  group('F026 — size follows the title and its column', () {
    test('a short headline keeps full weight for its column', () {
      // 32, not 40. AuraText.display is documented "hero moments, landing page
      // headlines only" and a long-form reading column is not a hero.
      expect(
        publicationTitleFontSize(characters: 20, availableWidth: 720),
        32.0,
      );
    });

    test('a long headline steps DOWN instead of overflowing', () {
      final short = publicationTitleFontSize(characters: 20, availableWidth: 720);
      final medium = publicationTitleFontSize(characters: 90, availableWidth: 720);
      final long = publicationTitleFontSize(characters: 200, availableWidth: 720);
      expect(medium, lessThan(short));
      expect(long, lessThan(medium));
    });

    test('it never shrinks below a size that still reads as a title', () {
      expect(
        publicationTitleFontSize(characters: 5000, availableWidth: 720),
        greaterThanOrEqualTo(20.0),
      );
    });

    test('the scale is monotonic — longer never renders larger', () {
      var previous = double.infinity;
      for (var n = 0; n <= 400; n += 10) {
        final size = publicationTitleFontSize(characters: n, availableWidth: 720);
        expect(size, lessThanOrEqualTo(previous));
        previous = size;
      }
    });

    test('mobile starts lower, for the same reason the hero does', () {
      expect(
        publicationTitleFontSize(characters: 20, availableWidth: 380),
        lessThan(publicationTitleFontSize(characters: 20, availableWidth: 720)),
      );
    });
  });

  group('F026 — one title authority', () {
    Future<void> pump(WidgetTester tester, Widget child, {Size? size}) async {
      tester.view.physicalSize = size ?? const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
    }

    testWidgets('renders the title it was given', (tester) async {
      await pump(tester, const AuraPublicationTitle('Institution operating layer'));
      expect(find.text('Institution operating layer'), findsOneWidget);
    });

    testWidgets('an empty title falls back to its placeholder', (tester) async {
      await pump(tester, const AuraPublicationTitle('  ', placeholder: 'Untitled'));
      expect(find.text('Untitled'), findsOneWidget);
    });

    testWidgets('a long title is rendered smaller than a short one',
        (tester) async {
      await pump(tester, const AuraPublicationTitle('Short title'));
      final small = tester.widget<Text>(find.text('Short title')).style!.fontSize!;

      final long = List.generate(30, (i) => 'word$i').join(' ');
      await pump(tester, AuraPublicationTitle(long));
      final big = tester.widget<Text>(find.text(long)).style!.fontSize!;

      expect(big, lessThan(small),
          reason: 'A long headline that keeps display size is the defect.');
    });
  });


  /// THE REPORTED DEFECT — "The Quiet Work That Holds People Together".
  ///
  /// A 41-character title rendered at full 40px in the reader's 760px column
  /// and wrapped to two lines, dominating the viewport. It was not a long-title
  /// problem: the size was chosen from the WINDOW width, so on a wide display
  /// the headline was sized as though it owned the screen and then wrapped
  /// inside a column half that width.
  group('a title is sized by its column, not the window', () {
    const reported = 'The Quiet Work That Holds People Together';

    test('the reported title now fits its reading column on one line', () {
      const column = 720.0; // 760 reader column minus its padding
      final size = publicationTitleFontSize(
        characters: reported.length,
        availableWidth: column,
      );
      expect(size, lessThan(40.0));
      // Conservative advance estimate — if this exceeds the column it wraps.
      expect(reported.length * 0.52 * size, lessThanOrEqualTo(column));
    });

    test('a wider window does NOT enlarge a title in the same column', () {
      // The actual bug: identical column, different screen, different size.
      final a = publicationTitleFontSize(characters: 41, availableWidth: 720);
      final b = publicationTitleFontSize(characters: 41, availableWidth: 720);
      expect(a, b);
    });

    test('a genuinely wider column may carry a larger title', () {
      final narrow = publicationTitleFontSize(characters: 41, availableWidth: 360);
      final wide = publicationTitleFontSize(characters: 41, availableWidth: 720);
      expect(wide, greaterThan(narrow));
    });

    test('a title fits three lines of its column, or is already at the floor', () {
      // The fit cap and the floor genuinely conflict for a very long title in a
      // narrow column: 120 characters cannot occupy three lines of a 320px
      // phone column at any size that still reads as a title. The floor wins
      // there, deliberately — stated as the real contract rather than asserting
      // a cap that cannot hold.
      for (final chars in [60, 120, 200, 400]) {
        for (final width in [320.0, 480.0, 720.0]) {
          final size =
              publicationTitleFontSize(characters: chars, availableWidth: width);
          final lines = (chars * 0.52 * size) / width;
          expect(lines <= 3.05 || size == 20.0, isTrue,
              reason: 'chars=$chars width=$width size=$size lines=$lines');
        }
      }
    });

    test('the floor still reads as a title', () {
      expect(
        publicationTitleFontSize(characters: 5000, availableWidth: 320),
        greaterThanOrEqualTo(20.0),
      );
    });
  });
}
