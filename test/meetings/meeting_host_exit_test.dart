import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aura/core/ui/adaptive_dialog_action.dart';
import 'package:aura/features/meetings/presentation/widgets/meeting_room_controls.dart';
import 'package:aura/features/realtime/domain/realtime_state.dart';

/// HOST EXIT (founder-approved design, 22 Oct 2026): the host's End is a
/// choice between leaving and ending for everyone, never one button that ends
/// the meeting for every guest.
void main() {
  Future<void> pump(
    WidgetTester tester, {
    required VoidCallback onEnd,
    required VoidCallback onLeave,
    bool isHost = true,
  }) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MeetingControlBar(
            state: RealtimeState.initial(),
            isHost: isHost,
            showParticipants: false,
            showNotes: false,
            showChat: false,
            unreadChat: 0,
            endingMeeting: false,
            togglingScreenShare: false,
            onToggleMic: () {},
            onToggleCamera: () {},
            onToggleParticipants: () {},
            onToggleNotes: () {},
            onToggleChat: () {},
            onInvite: () {},
            onFiles: () {},
            recordingSupported: false,
            recording: false,
            savingRecording: false,
            onToggleRecording: () {},
            onShareScreen: () {},
            onFlipCamera: () {},
            onDeviceSettings: () {},
            onEndMeeting: onEnd,
            onLeaveMeeting: onLeave,
            handRaised: false,
            onToggleHand: () {},
            onReact: () {},
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('tapping End opens Leave meeting / End for everyone, not an end',
      (tester) async {
    var ended = 0, left = 0;
    await pump(tester, onEnd: () => ended++, onLeave: () => left++);
    await tester.tap(find.byKey(const ValueKey('meeting-host-exit')));
    await tester.pumpAndSettle();
    expect(find.text('Leave meeting'), findsOneWidget);
    expect(find.text('End for everyone'), findsOneWidget);
    expect(ended, 0, reason: 'opening the menu must not end the meeting');
    expect(left, 0);
  });

  testWidgets('Leave meeting leaves without ending', (tester) async {
    var ended = 0, left = 0;
    await pump(tester, onEnd: () => ended++, onLeave: () => left++);
    await tester.tap(find.byKey(const ValueKey('meeting-host-exit')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leave meeting'));
    await tester.pumpAndSettle();
    expect(left, 1);
    expect(ended, 0);
  });

  testWidgets('End for everyone asks the screen to end (it confirms there)',
      (tester) async {
    var ended = 0;
    await pump(tester, onEnd: () => ended++, onLeave: () {});
    await tester.tap(find.byKey(const ValueKey('meeting-host-exit')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('End for everyone'));
    await tester.pumpAndSettle();
    expect(ended, 1);
  });

  testWidgets('a participant still sees a plain Leave', (tester) async {
    var left = 0;
    await pump(tester, isHost: false, onEnd: () {}, onLeave: () => left++);
    expect(find.byKey(const ValueKey('meeting-host-exit')), findsNothing);
    await tester.tap(find.text('Leave'));
    await tester.pump();
    expect(left, 1);
  });

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('the confirmation uses the platform dialog action ($platform)',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: platform),
          home: Builder(
            builder: (ctx) => adaptiveDialogAction(
              ctx,
              label: 'End for everyone',
              destructive: true,
              onPressed: () {},
            ),
          ),
        ),
      );
      expect(find.text('End for everyone'), findsOneWidget);
      if (platform == TargetPlatform.iOS) {
        expect(find.byType(TextButton), findsNothing);
      } else {
        expect(find.byType(TextButton), findsOneWidget);
      }
    });
  }
}
