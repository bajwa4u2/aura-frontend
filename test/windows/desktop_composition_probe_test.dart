import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aura/core/ui/aura_responsive.dart';
import 'package:aura/core/ui/surface/surface_composition.dart';

/// MEASUREMENT, NOT ASSERTION.
///
/// A Windows screenshot shows that the signed-in member surface leaves a wide
/// empty band between the navigation rail and the content. Reading the widget
/// tree can explain how such a band COULD arise; only measuring says how wide
/// it actually is and which region owns it. This prints the geometry of every
/// persistent region at real Windows window widths so the composition can be
/// judged from numbers rather than from pixels counted by eye.
///
/// Deliberately builds the layout primitive with stub content: the subject is
/// the composition, not any screen's data.
void main() {
  Future<void> probe(
    WidgetTester tester,
    double width, {
    required bool withContextRail,
    required bool withSurfaceLeftRail,
    double shellNavWidth = 92,
    AuraSurfaceType type = AuraSurfaceType.discourseFeed,
  }) async {
    await tester.binding.setSurfaceSize(Size(width, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final centerKey = GlobalKey();
    final shellNavKey = GlobalKey();
    final surfaceRailKey = GlobalKey();
    final contextRailKey = GlobalKey();

    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(size: Size(width, 1000)),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Material(
            child: Row(
              children: [
                // The member shell's own persistent navigation rail.
                Container(key: shellNavKey, width: shellNavWidth),
                Expanded(
                  child: AuraSurfaceScaffold(
                    type: type,
                    leftRail: withSurfaceLeftRail
                        ? Container(key: surfaceRailKey, width: 320)
                        : null,
                    contextRail: withContextRail
                        // Empty module list on purpose: this is the quiet-day
                        // case, which is the ordinary case.
                        ? AuraContextRail(key: contextRailKey, modules: const [])
                        : null,
                    center: Container(key: centerKey, color: Colors.blue),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    double w(GlobalKey k) {
      final ctx = k.currentContext;
      if (ctx == null) return -1;
      return (ctx.findRenderObject() as RenderBox).size.width;
    }

    double left(GlobalKey k) {
      final ctx = k.currentContext;
      if (ctx == null) return -1;
      return (ctx.findRenderObject() as RenderBox)
          .localToGlobal(Offset.zero)
          .dx;
    }

    final centerW = w(centerKey);
    final centerL = left(centerKey);
    final railW = withContextRail ? w(contextRailKey) : 0;
    final surfaceRailW = withSurfaceLeftRail ? w(surfaceRailKey) : 0;
    final gapLeft = centerL - shellNavWidth - surfaceRailW;
    final used = shellNavWidth + surfaceRailW + centerW;
    final gapRight = width - used - gapLeft - railW;

    // ignore: avoid_print
    print(
      'W=${width.toInt()}  nav=${shellNavWidth.toInt()}'
      '  surfaceRail=${surfaceRailW.toInt()}'
      '  gapL=${gapLeft.toStringAsFixed(0)}'
      '  content=${centerW.toStringAsFixed(0)} @${centerL.toStringAsFixed(0)}'
      '  gapR=${gapRight.toStringAsFixed(0)}'
      '  emptyRail=${railW.toStringAsFixed(0)}'
      '  => work=${(centerW / width * 100).toStringAsFixed(0)}% of window',
    );
  }

  group('what the desktop window is actually spent on', () {
    for (final width in const [2011.0, 1600.0, 1400.0, 1200.0, 1024.0]) {
      testWidgets('feed at ${width.toInt()} with an EMPTY context rail',
          (tester) async {
        await probe(tester, width,
            withContextRail: true, withSurfaceLeftRail: false);
      });
    }

    testWidgets('feed at 2011 with NO context rail at all', (tester) async {
      await probe(tester, 2011,
          withContextRail: false, withSurfaceLeftRail: false);
    });

    testWidgets('workspace at 2011 with an empty rail', (tester) async {
      await probe(tester, 2011,
          withContextRail: true,
          withSurfaceLeftRail: false,
          type: AuraSurfaceType.workspace);
    });

    testWidgets('an empty rail is not a collapsed rail', (tester) async {
      // The specific finding: AuraContextRail returns SizedBox(width: …) when
      // it has no modules, so a rail whose modules all self-collapse still
      // spends its full width. On a quiet platform that is every one of them.
      await tester.binding.setSurfaceSize(const Size(2011, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final k = GlobalKey();
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(2011, 1000)),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Material(
              child: Row(children: [AuraContextRail(key: k, modules: const [])]),
            ),
          ),
        ),
      );
      final railWidth =
          (k.currentContext!.findRenderObject() as RenderBox).size.width;
      // ignore: avoid_print
      print('empty context rail width at 2011 = $railWidth');
      // WAS `greaterThan(0)` -- recorded as the measured defect. It is now
      // the fix: a contextual inspector with nothing in it spends no width.
      // Kept as an assertion rather than deleted, because 360 px of reserved
      // emptiness was the single largest piece of the wasted desktop estate
      // and nothing else would notice it coming back.
      expect(railWidth, 0.0,
          reason: 'an inspector with no modules must occupy no width');
    });
  });
}
