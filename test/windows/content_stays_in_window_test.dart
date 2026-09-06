import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aura/core/ui/aura_responsive.dart';
import 'package:aura/core/ui/aura_scaffold.dart';
import 'package:aura/core/ui/aura_window.dart';
import 'package:aura/core/ui/surface/surface_composition.dart';

/// CONTENT STAYS INSIDE THE WINDOW.
///
/// Windows captures at 1400 px showed Home and Discover content running to the
/// right edge with a margin only on the left. Screenshots at 125% display
/// scaling are an unreliable ruler — the image is in physical pixels and the
/// layout is in logical ones — so this measures the real thing: the exact tree
/// those screens build, at the exact widths, asserting that the work column
/// fits inside the space it was given and is centred within it.
///
/// A regression guard as much as a diagnosis. The composition now resolves
/// width in several places (window class, measure, gutter, page shell), and
/// "content is somewhere off the right edge" is the failure they can combine
/// into without any one of them being wrong.
void main() {
  Future<Rect> measure(
    WidgetTester tester, {
    required double windowWidth,
    required double navWidth,
    required AuraSurfaceType type,
    required bool pageShell,
  }) async {
    await tester.binding.setSurfaceSize(Size(windowWidth, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final contentKey = GlobalKey();

    Widget surface = AuraSurfaceScaffold(
      type: type,
      center: Container(key: contentKey, color: const Color(0xFF2196F3)),
    );

    if (pageShell) {
      // What member home actually does: a page scaffold that declares the
      // child decides its own width, with the surface inside a Stack.
      surface = AuraScaffold(
        showHeader: false,
        maxWidth: AuraScaffold.childDecidesWidth,
        body: Stack(children: [surface]),
      );
    }

    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(size: Size(windowWidth, 900)),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: AuraWindow(
            width: windowWidth,
            height: 900,
            navPosture: AuraNavPosture.compact,
            child: Material(
              child: Row(
                children: [
                  SizedBox(width: navWidth),
                  Expanded(child: surface),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    final box = contentKey.currentContext!.findRenderObject() as RenderBox;
    final origin = box.localToGlobal(Offset.zero);
    return origin & box.size;
  }

  group('the work column fits the window it is in', () {
    for (final width in const [2011.0, 1480.0, 1400.0, 1120.0, 1040.0, 880.0]) {
      testWidgets('feed at ${width.toInt()}', (tester) async {
        const nav = 92.0;
        final r = await measure(
          tester,
          windowWidth: width,
          navWidth: nav,
          type: AuraSurfaceType.discourseFeed,
          pageShell: true,
        );

        expect(r.left, greaterThanOrEqualTo(nav),
            reason: 'content started left of the navigation rail');
        expect(r.right, lessThanOrEqualTo(width),
            reason: 'content ran off the right edge of the window — '
                'left=${r.left} right=${r.right} window=$width');

        // Both margins present, and equal: a column with a gutter on one side
        // only is the exact symptom that started this.
        final leftGap = r.left - nav;
        final rightGap = width - r.right;
        expect(leftGap, greaterThan(0),
            reason: 'no left margin (left gap $leftGap)');
        expect(rightGap, greaterThan(0),
            reason: 'no right margin (right gap $rightGap)');
        expect((leftGap - rightGap).abs(), lessThan(1.0),
            reason: 'margins are lopsided: left=$leftGap right=$rightGap');

        // ignore: avoid_print
        print('W=${width.toInt()} nav=$nav  L=${leftGap.toStringAsFixed(0)}'
            '  content=${r.width.toStringAsFixed(0)}'
            '  R=${rightGap.toStringAsFixed(0)}');
      });
    }

    testWidgets('a workspace surface fits too', (tester) async {
      final r = await measure(
        tester,
        windowWidth: 1400,
        navWidth: 92,
        type: AuraSurfaceType.workspace,
        pageShell: false,
      );
      expect(r.right, lessThanOrEqualTo(1400.0));
      expect(1400 - r.right, greaterThan(0));
    });
  });
}
