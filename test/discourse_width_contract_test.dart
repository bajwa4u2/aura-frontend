// Guards the desktop discourse width contract. AuraScaffold's default
// page width (920) is below the canonical feed/discourse width
// (kFeedWidth). Discourse detail surfaces must opt into the wider
// canonical width explicitly; this test pins both behaviours so a
// future change to AuraScaffold cannot silently re-narrow them.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aura/core/ui/aura_responsive.dart';
import 'package:aura/core/ui/aura_scaffold.dart';

Future<double> _bodyWidth(WidgetTester tester, {double? maxWidth}) async {
  tester.view.physicalSize = const Size(1600, 1000);
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

  testWidgets('AuraScaffold default page width is 920', (t) async {
    // Documents the off-canonical default that discourse surfaces must
    // override. If this default ever moves, the discourse screens that
    // pass kFeedWidth explicitly are unaffected.
    expect(await _bodyWidth(t), 920);
  });
}
