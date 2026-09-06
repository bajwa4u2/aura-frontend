// Guards the desktop page width contract.
//
// WHAT CHANGED, AND WHY THIS TEST DID. AuraScaffold's default was a flat
// 920 px at every window size. On a 2000 px Windows window that made every
// screen which did not name its own width a ~920 px column with 500 px of
// empty page either side -- a browser column inside a native frame, which is
// the presentation the desktop composition pass exists to end.
//
// The default is now a MEASURE that only ever widens: never below the old
// 920, growing with the room, and stopping at the feed cap so a page never
// becomes an unreadable line. So the contract this file pins is no longer a
// number; it is the SHAPE of the rule, which is the part that matters.
//
// Narrow behaviour is deliberately part of the contract too. An earlier
// attempt at this subtracted a gutter and quietly made small surfaces
// thinner, overflowing a Row on the auth screen by 99 px. A desktop
// correction must not take width from a phone.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aura/core/ui/aura_responsive.dart';
import 'package:aura/core/ui/aura_scaffold.dart';

Future<double> _bodyWidth(
  WidgetTester tester, {
  double? maxWidth,
  double viewWidth = 1600,
}) async {
  tester.view.physicalSize = Size(viewWidth, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final key = GlobalKey();
  await tester.pumpWidget(
    MaterialApp(
      home: AuraScaffold(
        maxWidth: maxWidth,
        body: KeyedSubtree(key: key, child: const SizedBox.expand()),
      ),
    ),
  );
  return tester.getSize(find.byKey(key)).width;
}

void main() {
  testWidgets('AuraScaffold honors an explicit canonical maxWidth', (t) async {
    expect(await _bodyWidth(t, maxWidth: kFeedWidth), kFeedWidth);
  });

  testWidgets('the default grows with the window, never past the feed cap',
      (t) async {
    // 1600 of room: wider than the old flat default, still under the cap.
    expect(await _bodyWidth(t), 1320);
  });

  testWidgets('the default never goes below the historical 920', (t) async {
    // A window with less room than the old default gets the whole of it --
    // exactly as before. The measure is a ceiling, not a target.
    expect(await _bodyWidth(t, viewWidth: 1000), 1000);
    expect(await _bodyWidth(t, viewWidth: 700), 700);
  });

  testWidgets('a narrow surface is not made narrower to decorate a wide one',
      (t) async {
    // The regression this file now guards: content must fill a small surface,
    // with no gutter carved out of it.
    expect(await _bodyWidth(t, viewWidth: 420), 420);
  });
}
