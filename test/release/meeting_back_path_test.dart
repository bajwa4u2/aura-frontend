import 'dart:convert';
import 'dart:io';

import 'package:aura/features/meetings/presentation/widgets/meeting_live_ribbon.dart';
import 'package:aura/features/realtime/presentation/widgets/floating_call_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// THE WAY OUT OF A MEETING, AND BACK IN (founder-approved design, 23 Oct 2026).
///
/// The browser's Back was the only way out of a meeting room, and native apps
/// had none. The member-shell return pill reached members only, and an
/// institution room was never recognised as a room, so its host had no way
/// back at all.
void main() {
  String code(String path) => const LineSplitter()
      .convert(File(path).readAsStringSync())
      .map((l) {
        final i = l.indexOf('//');
        return i < 0 ? l : l.substring(0, i);
      })
      .join('\n');

  final room =
      code('lib/features/meetings/presentation/meeting_live_room_screen.dart');

  test('each platform keeps its own place for the ribbon', () {
    MeetingRibbonPlacement at(TargetPlatform p, {bool web = false, double w = 400}) =>
        meetingRibbonPlacement(platform: p, isWeb: web, width: w);
    expect(at(TargetPlatform.iOS), MeetingRibbonPlacement.top);
    expect(at(TargetPlatform.android), MeetingRibbonPlacement.bottom);
    expect(at(TargetPlatform.windows), MeetingRibbonPlacement.corner);
    expect(at(TargetPlatform.macOS), MeetingRibbonPlacement.corner);
    expect(at(TargetPlatform.android, web: true, w: 390),
        MeetingRibbonPlacement.top);
    expect(at(TargetPlatform.windows, web: true, w: 1440),
        MeetingRibbonPlacement.corner);
  });

  test('an institution meeting room is a call surface too', () {
    expect(
      callSurfaceOwnsTheScreen(
          Uri.parse('/institution/i1/meetings/m1/live?sessionId=s1')),
      isTrue,
    );
    expect(
      callSurfaceOwnsTheScreen(Uri.parse('/institution/i1/meetings/m1')),
      isFalse,
    );
  });

  test('the room offers Back to Aura, and guests are not offered it', () {
    expect(room, contains("tooltip: 'Back to Aura'"));
    final header = room.substring(room.indexOf('_MeetingLiveHeader('));
    expect(
      header.substring(0, header.indexOf(');')),
      contains('? null\n                  : _stepOut'),
    );
  });

  test('stepping out does not leave the meeting', () {
    final stepOut = room.substring(
      room.indexOf('void _stepOut()'),
      room.indexOf('void _clearReturnEntry()'),
    );
    expect(stepOut, isNot(contains('leave()')));
    expect(stepOut, isNot(contains('_intentToLeave = true')));
    // Only an intended leave tears the call down when the room goes away.
    final dispose = room.substring(room.indexOf('  void dispose() {'));
    expect(
      dispose.substring(0, dispose.indexOf('super.dispose();')),
      contains('if (_intentToLeave) {'),
    );
  });

  test('a browser recording is stopped before stepping out', () {
    final stepOut = room.substring(
      room.indexOf('void _stepOut()'),
      room.indexOf('void _clearReturnEntry()'),
    );
    expect(stepOut.indexOf('if (_recording'), lessThan(stepOut.indexOf('pop()')));
  });

  test('leaving or ending from the ribbon lands on the meeting record', () {
    final pip = code(
        'lib/features/realtime/presentation/widgets/floating_call_widget.dart');
    final exit = pip.substring(
      pip.indexOf('Future<void> _endOrLeaveMeeting('),
      pip.indexOf('Future<void> _endCallFromPip('),
    );
    expect(exit, contains("label: 'End for everyone'"));
    expect(exit, contains('.endMeeting(meetingId)'));
    expect(exit, contains('controller.leave()'));
    expect(exit, contains('router.go(recordPath)'));
  });

  testWidgets('the Android bar offers Return and Leave for a participant',
      (tester) async {
    var returned = 0;
    var left = 0;
    await tester.pumpWidget(MaterialApp(
      home: Stack(children: [
        MeetingLiveRibbon(
          placement: MeetingRibbonPlacement.bottom,
          startedAt: DateTime.now().subtract(const Duration(minutes: 2)),
          inRoom: 2,
          mayEndForEveryone: false,
          isEnding: false,
          onReturn: () => returned++,
          onEnd: () => left++,
        ),
      ]),
    ));
    expect(find.textContaining('In meeting'), findsOneWidget);
    await tester.tap(find.text('Return'));
    await tester.tap(find.text('Leave'));
    expect(returned, 1);
    expect(left, 1);
  });

  testWidgets('the top ribbon says how many are in the room', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Stack(children: [
        MeetingLiveRibbon(
          placement: MeetingRibbonPlacement.top,
          startedAt: null,
          inRoom: 3,
          mayEndForEveryone: true,
          isEnding: false,
          onReturn: () {},
          onEnd: () {},
        ),
      ]),
    ));
    expect(find.textContaining('3 in room'), findsOneWidget);
    expect(find.text('End'), findsNothing);
  });
}
