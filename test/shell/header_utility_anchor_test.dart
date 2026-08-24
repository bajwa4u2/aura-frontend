import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// THE DESKTOP UTILITY CLUSTER IS ANCHORED TO THE TRAILING EDGE.
///
/// Founder live finding (2026-08-23): on the deployed desktop view, Search /
/// Attention / Live / Account floated toward the middle of the header instead
/// of forming a right-aligned utility cluster.
///
/// The cause was a flex arithmetic error, not styling. The header row was
/// `[wordmark, Spacer(), Flexible(tools)]`. `Spacer` is `Expanded(flex: 1)`
/// and `Flexible` also defaults to `flex: 1`, so the free width was divided
/// equally between the gap and the tools slot, and the content-sized cluster
/// sat at the START of its half.
///
/// The geometry is proven here directly, because that is where the defect
/// lived: the same two shapes are laid out and measured. The source gate below
/// then holds the shell to the shape that measures correctly.
void main() {
  const inset = 24.0;
  const headerWidth = 1142.0; // the founder's measured viewport
  final clusterKey = UniqueKey();

  /// The default test surface is 800px wide, which would silently clamp every
  /// width under test and make the measurements meaningless. The view is sized
  /// explicitly instead, and reset afterwards.
  Future<Rect> layoutAt(
      WidgetTester tester, double width, Widget row) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = Size(width, 200);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: inset),
            child: row,
          ),
        ),
      ),
    );
    return tester.getRect(find.byKey(clusterKey));
  }

  Future<Rect> layout(WidgetTester tester, Widget row) =>
      layoutAt(tester, headerWidth, row);

  Widget cluster(Key key) =>
      SizedBox(key: key, width: 260, height: 40, child: const Placeholder());

  group('the header anchors its utilities', () {
    testWidgets('the shipped shape left the cluster near the middle',
        (tester) async {
      // An executable record of the defect, so a future revert is read as a
      // regression rather than a simplification.
      final rect = await layout(
        tester,
        Row(children: [
          const SizedBox(width: 140, height: 40),
          const Spacer(),
          Flexible(child: cluster(clusterKey)),
        ]),
      );

      final trailingGap = headerWidth - inset - rect.right;
      expect(trailingGap, greaterThan(100),
          reason: 'the fifty-fifty split stranded the cluster mid-header');
    });

    testWidgets('one Expanded with a trailing Align anchors it', (tester) async {
      final rect = await layout(
        tester,
        Row(children: [
          const SizedBox(width: 140, height: 40),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: cluster(clusterKey),
            ),
          ),
        ]),
      );

      // Flush against the outer inset, at the width the founder is using.
      expect(rect.right, moreOrLessEquals(headerWidth - inset, epsilon: 0.5));
    });

    testWidgets('it stays anchored as the width degrades', (tester) async {
      // Tablet and intermediate widths must degrade deliberately rather than
      // re-centring or colliding with the wordmark.
      for (final width in [1440.0, 1142.0, 900.0, 760.0]) {
        final rect = await layoutAt(
          tester,
          width,
          Row(children: [
            const SizedBox(width: 140, height: 40),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: cluster(clusterKey),
              ),
            ),
          ]),
        );
        expect(rect.right, moreOrLessEquals(width - inset, epsilon: 0.5),
            reason: 'anchoring must hold at ${width}px');
        expect(rect.left, greaterThanOrEqualTo(140 + inset),
            reason: 'must not collide with the wordmark at ${width}px');
      }
    });
  });

  group('the shell keeps the shape that measures correctly', () {
    final source =
        File('lib/app/shell/global_platform_shell.dart').readAsStringSync();

    test('the utilities sit in a trailing-aligned Expanded', () {
      expect(source, contains('alignment: Alignment.centerRight'));
      expect(source, contains('child: ShellHeaderTools('));
    });

    test('the Spacer beside a flexible tools slot does not come back', () {
      // The two together are the defect; either alone is harmless, so the
      // pairing is what is asserted against.
      final headerRow = source.substring(
        source.indexOf('AuraShellWordmark'),
        source.indexOf('_goHome(BuildContext'),
      );
      expect(
        headerRow.contains('const Spacer()') &&
            headerRow.contains('Flexible(') ,
        isFalse,
        reason: 'Spacer + Flexible(flex: 1) splits the free width in half',
      );
    });
  });
}
