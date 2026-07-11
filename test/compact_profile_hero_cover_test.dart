import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aura/core/ui/compact_profile_hero.dart';

// The hero's outer Container carries a 1px border (BorderSide default width),
// which insets LayoutBuilder's constraints.maxWidth by 2px before the cover
// height is computed from it — so the rendered cover height is always
// (frameWidth - 2) / 3, not frameWidth / 3 exactly.
const double _borderInset = 2;

Future<void> _pumpHero(WidgetTester tester, {required double width}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            child: const CompactProfileHero(
              displayName: 'Member',
              handle: 'member',
              coverUrl: '',
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('member profile cover frame uses the canonical 3:1 ratio', (
    tester,
  ) async {
    // Desktop width exceeds the default 800x600 logical test viewport —
    // widen it so the hero actually measures the full 840px frame.
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpHero(tester, width: 840);

    final expectedHeight = (840 - _borderInset) / 3;
    final cover = tester.widget<SizedBox>(
      find.byWidgetPredicate(
        (widget) => widget is SizedBox && widget.height == expectedHeight,
      ),
    );

    expect(cover.width, double.infinity);
    expect(cover.height, expectedHeight);
  });

  testWidgets('member profile cover scales proportionally on mobile', (
    tester,
  ) async {
    await _pumpHero(tester, width: 360);

    final expectedHeight = (360 - _borderInset) / 3;
    final cover = tester.widget<SizedBox>(
      find.byWidgetPredicate(
        (widget) => widget is SizedBox && widget.height == expectedHeight,
      ),
    );

    expect(cover.width, double.infinity);
    expect(cover.height, expectedHeight);
  });
}
