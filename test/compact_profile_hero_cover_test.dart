import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aura/core/ui/compact_profile_hero.dart';

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
    await _pumpHero(tester, width: 840);

    final cover = tester.widget<SizedBox>(
      find.byWidgetPredicate(
        (widget) => widget is SizedBox && widget.height == 280,
      ),
    );

    expect(cover.width, double.infinity);
    expect(cover.height, 280);
  });

  testWidgets('member profile cover scales proportionally on mobile', (
    tester,
  ) async {
    await _pumpHero(tester, width: 360);

    final cover = tester.widget<SizedBox>(
      find.byWidgetPredicate(
        (widget) => widget is SizedBox && widget.height == 120,
      ),
    );

    expect(cover.width, double.infinity);
    expect(cover.height, 120);
  });
}
