import 'dart:io';

import 'package:aura/core/navigation/return_path_frame.dart';
import 'package:aura/core/ui/guest_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// THE GUEST PAGES ON A PHONE, 2026-10-24 (Galaxy S24, Chrome).
///
/// Two back arrows, one under the other; in landscape the chrome took the
/// whole height and the invitation had 0px; with the keyboard up the footer
/// covered "Verify and join"; the keyboard followed the guest into the room.
void main() {
  Widget page({
    required Size size,
    double keyboard = 0,
    bool underReturnBar = false,
  }) {
    final shell = GuestShell(
      showBackButton: true,
      body: ListView(
        children: const [SizedBox(height: 40, child: Text('Invited as Guest'))],
      ),
    );
    // As in production: the public shell's Scaffold sits above the guest
    // shell, absorbs the keyboard and hands down zero insets.
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          viewInsets: EdgeInsets.only(bottom: keyboard),
        ),
        child: Scaffold(
          body: underReturnBar ? ReturnBarPresence(child: shell) : shell,
        ),
      ),
    );
  }

  Future<void> sized(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('under the governed return bar there is one way back',
      (tester) async {
    await sized(tester, const Size(412, 900));
    await tester.pumpWidget(page(size: const Size(412, 900), underReturnBar: true));
    expect(find.byIcon(Icons.arrow_back_rounded), findsNothing);
  });

  testWidgets('without the governed bar the shell still offers a way back',
      (tester) async {
    await sized(tester, const Size(412, 900));
    await tester.pumpWidget(page(size: const Size(412, 900)));
    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
  });

  testWidgets('portrait keeps the footer', (tester) async {
    await sized(tester, const Size(412, 900));
    await tester.pumpWidget(page(size: const Size(412, 900)));
    expect(find.text('Powered by '), findsOneWidget);
  });

  testWidgets('landscape gives the height to the content', (tester) async {
    await sized(tester, const Size(900, 412));
    await tester.pumpWidget(page(size: const Size(900, 412)));
    expect(find.text('Powered by '), findsNothing);
    expect(find.text('Invited as Guest'), findsOneWidget);
  });

  testWidgets('an open keyboard does not leave the footer over the button',
      (tester) async {
    await sized(tester, const Size(412, 900));
    await tester.pumpWidget(page(size: const Size(412, 900), keyboard: 340));
    expect(find.text('Powered by '), findsNothing);
  });

  test('the app offer steps aside on a short viewport', () {
    final shell = File('lib/app/shell/public_shell.dart').readAsStringSync();
    expect(shell, contains('constraints.maxHeight >= 520 &&'));
  });

  test('the keyboard does not follow the guest into the room', () {
    final src = File('lib/features/meetings/presentation/pre_join_screen.dart')
        .readAsStringSync();
    final admit = src.substring(
      src.indexOf('Future<void> _completeAdmission('),
    );
    expect(admit.indexOf('FocusManager.instance.primaryFocus?.unfocus();'),
        lessThan(admit.indexOf('context.push(')));
  });
  test('the room clears any focus it inherits', () {
    final src =
        File('lib/features/meetings/presentation/meeting_live_room_screen.dart')
            .readAsStringSync();
    final init = src.substring(src.indexOf('_visibleRoom = this;') - 400,
        src.indexOf('_visibleRoom = this;'));
    expect(init, contains('FocusManager.instance.primaryFocus?.unfocus();'));
  });
}
