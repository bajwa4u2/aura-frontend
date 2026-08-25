import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aura/core/ui/aura_scaffold.dart';

/// THE SHARED HEADER MUST NOT COST THE PAGE ITS SCROLL.
///
/// `AuraScaffold` grew a header on 2026-08-25 (navigation chapter). A header
/// added above `Expanded(child: body)` is exactly the shape that silently
/// turns a scrollable page into a clipped one, and 104 routed screens compose
/// this widget. Inspecting the live product on 2026-08-25 it LOOKED like that
/// had happened — so this pins the answer rather than leaving it to eyesight.
void main() {
  Widget page({required bool header}) => MaterialApp(
        home: AuraScaffold(
          title: header ? 'Meeting' : '',
          showHeader: header,
          body: ListView(
            children: [
              for (var i = 0; i < 12; i++)
                SizedBox(height: 200, child: Card(child: Text('block $i'))),
            ],
          ),
        ),
      );

  testWidgets('WITHOUT a header it scrolls', (tester) async {
    tester.view.physicalSize = const Size(1512, 613);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(page(header: false));
    await tester.pump();
    await tester.scrollUntilVisible(find.text('block 11'), 400,
        scrollable: find.byType(Scrollable).last);
    await tester.pumpAndSettle();
    expect(find.text('block 11'), findsOneWidget,
        reason: 'even without a header the page will not scroll');
  });

  testWidgets('a page taller than the viewport can be scrolled', (tester) async {
    tester.view.physicalSize = const Size(1512, 613);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: AuraScaffold(
        title: 'Meeting',
        body: ListView(
          children: [
            for (var i = 0; i < 12; i++)
              SizedBox(height: 200, child: Card(child: Text('block $i'))),
          ],
        ),
      ),
    ));
    await tester.pump();

    expect(find.text('block 0'), findsOneWidget);
    // Below the fold before scrolling.
    expect(find.text('block 11'), findsNothing);

    await tester.scrollUntilVisible(find.text('block 11'), 400,
        scrollable: find.byType(Scrollable).last);
    await tester.pumpAndSettle();

    expect(find.text('block 11'), findsOneWidget,
        reason: 'content below the fold is unreachable with a header present');
  });
}
