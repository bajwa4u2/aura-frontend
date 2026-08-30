import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// ONE SCROLL OWNER PER COMPOSER.
///
/// The reported defect: on a short viewport the announcement editor could not
/// be scrolled to the bottom with a pointer. Distribution, Pin and Publish were
/// unreachable, while Tab still reached them.
///
/// It was not a Publish-button defect. `maxLines: 14` gave the body TextField
/// its own Scrollable, and Flutter does not chain a leftover wheel delta from
/// an inner Scrollable out to an enclosing one — so a gesture that began over
/// the body was consumed there and went nowhere. At roughly 613 CSS px of
/// viewport the field fills most of the screen, so almost every natural scroll
/// began over it; a taller window left somewhere else to put the pointer, which
/// is why it looked like a private-window-versus-normal-window difference.
///
/// The widget test below reproduces the trapping mechanism directly, at the
/// level the defect actually lives — a bounded-maxLines field creates a
/// competing scrollable, an unbounded one does not. The source assertions then
/// hold the fix in place across both composers.
///
/// WHAT THIS DOES NOT PROVE: that a real browser scrolls. That is a
/// real-boundary claim and was checked by interacting with the deployed page,
/// not here.
void main() {
  group('the inner field only traps the wheel when it can scroll', () {
    /// The largest scroll extent among the field's own scrollables.
    ///
    /// A TextField ALWAYS contains a Scrollable — EditableText builds one
    /// regardless of maxLines — so merely counting them proves nothing. What
    /// decides whether a wheel gesture is swallowed is whether that inner
    /// scrollable has anywhere to go: a Scrollable with zero extent passes the
    /// gesture on, one with extent consumes it and does not chain the
    /// remainder outward.
    Future<double> innerExtent(WidgetTester tester, int? maxLines) async {
      final controller = TextEditingController(
        text: List.generate(60, (i) => 'line $i').join('\n'),
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              // The founder-class viewport that reproduced it.
              height: 613,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    TextField(
                      controller: controller,
                      maxLines: maxLines,
                      minLines: 10,
                    ),
                    const SizedBox(height: 400),
                    const Text('Publish announcement'),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final inner = tester
          .stateList<ScrollableState>(
            find.descendant(
              of: find.byType(TextField),
              matching: find.byType(Scrollable),
            ),
          )
          .map((s) => s.position.maxScrollExtent)
          .fold<double>(0, (a, b) => b > a ? b : a);
      return inner;
    }

    testWidgets('bounded maxLines gives the field its own scroll extent', (tester) async {
      // The defect, reproduced: the field can scroll, so it consumes the
      // wheel and the outer view never moves.
      expect(await innerExtent(tester, 14), greaterThan(0));
    });

    testWidgets('unbounded maxLines leaves the field with nothing to scroll', (tester) async {
      // The fix: the field grows to its content, so there is no inner extent
      // to swallow the gesture and the outer view owns all of it.
      expect(await innerExtent(tester, null), 0);
    });
  });

  group('both composers keep a single scroll owner', () {
    String source(String path) => File(path).readAsStringSync();

    /// Comments stripped: the fix is documented at each site with prose that
    /// quotes the very value being asserted absent.
    String code(String s) => s
        .split('\n')
        .map((line) {
          final i = line.indexOf('//');
          return i < 0 ? line : line.substring(0, i);
        })
        .join('\n');

    const composers = <String, String>{
      'announcement editor':
          'lib/features/announcements/presentation/announcement_editor_screen.dart',
      'institution post composer':
          'lib/features/institutions/posts/institution_post_composer_screen.dart',
    };

    composers.forEach((label, path) {
      test('$label declares no bounded multi-line field', () {
        final src = code(source(path));
        // A bounded maxLines above 1 is the trap. `maxLines: 1` is a
        // single-line field and creates no scrollable, so it stays allowed.
        final bounded = RegExp(r'maxLines:\s*(\d+)')
            .allMatches(src)
            .map((m) => int.parse(m.group(1)!))
            .where((n) => n > 1)
            .toList();
        expect(
          bounded,
          isEmpty,
          reason:
              'A bounded multi-line TextField becomes a second Scrollable and '
              'traps the wheel on short viewports. Use maxLines: null with '
              'minLines for the initial height.',
        );
      });

      test('$label still owns exactly one outer scroll view', () {
        final src = code(source(path));
        final owners = RegExp(r'SingleChildScrollView\(|CustomScrollView\(|ListView\(')
            .allMatches(src)
            .length;
        expect(
          owners,
          1,
          reason:
              'The composer must have one canonical scroll owner. Two would '
              'reintroduce the same ambiguity from the other direction.',
        );
      });
    });
  });

  group('the sections below the body remain part of that one scrollable', () {
    test('Distribution, Pin and Publish are inside the editor scroll view', () {
      final src = File(
        'lib/features/announcements/presentation/announcement_editor_screen.dart',
      ).readAsStringSync();

      final scrollAt = src.indexOf('SingleChildScrollView(');
      expect(scrollAt, greaterThanOrEqualTo(0));

      // If any of these were lifted out into a fixed footer or a sibling of
      // the scroll view, reachability would depend on viewport height again.
      for (final marker in [
        "Text('Distribution'",
        'Pin this notice',
        'Publish announcement',
      ]) {
        final at = src.indexOf(marker);
        expect(at, greaterThan(scrollAt), reason: '$marker moved outside the scroll owner');
      }
    });
  });
}
