import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aura/features/meetings/presentation/widgets/meeting_room_controls.dart';

/// The meeting bar comes back for every way a person reaches for it, and
/// never fades for screen-reader users (founder-approved correction, 22 Oct
/// 2026). Before, only a touch tap or drag brought it back.
void main() {
  Future<int Function()> pump(WidgetTester tester) async {
    var hits = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MeetingRevealZone(
            onInteract: () => hits++,
            child: Center(
              child: TextButton(onPressed: () {}, child: const Text('Mic')),
            ),
          ),
        ),
      ),
    );
    return () => hits;
  }

  testWidgets('mouse hover reveals the controls', (tester) async {
    final hits = await pump(tester);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(5, 5));
    addTearDown(mouse.removePointer);
    await mouse.moveTo(const Offset(40, 40));
    await tester.pump();
    expect(hits(), greaterThan(0));
  });

  testWidgets('the keyboard reveals the controls', (tester) async {
    final hits = await pump(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(hits(), greaterThan(0));
  });

  testWidgets('a tap still reveals the controls', (tester) async {
    final hits = await pump(tester);
    await tester.tapAt(const Offset(20, 20));
    await tester.pump();
    expect(hits(), greaterThan(0));
  });

  testWidgets('the bar never auto-hides for screen-reader navigation',
      (tester) async {
    late bool mayHide, mayHideA11y;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (ctx) {
        mayHide = meetingControlsMayAutoHide(ctx);
        return const SizedBox();
      }),
    ));
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(accessibleNavigation: true),
        child: Builder(builder: (ctx) {
          mayHideA11y = meetingControlsMayAutoHide(ctx);
          return const SizedBox();
        }),
      ),
    ));
    expect(mayHide, isTrue);
    expect(mayHideA11y, isFalse);
  });
}
