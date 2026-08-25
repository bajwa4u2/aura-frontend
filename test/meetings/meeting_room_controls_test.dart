import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aura/features/meetings/presentation/widgets/meeting_room_controls.dart';
import 'package:aura/features/realtime/domain/realtime_state.dart';

/// THE MEETING ROOM'S CONTROLS, ACTUALLY INSTANTIATED.
///
/// Founder ruling 2026-08-25 §VIII and §XXXIV. The audit's finding was not
/// that these widgets were untested — it was that **no test instantiated the
/// live room at all**, because reaching its private widgets meant building a
/// 3,934-line screen that opens a socket and a camera.
///
/// Extracting them made this file possible. That is the whole argument for the
/// extraction, and this is the evidence for it.
void main() {
  Future<void> pump(
    WidgetTester tester, {
    required RealtimeState state,
    bool isHost = false,
    bool handRaised = false,
    int unreadChat = 0,
    VoidCallback? onToggleMic,
    VoidCallback? onLeave,
  }) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MeetingControlBar(
            state: state,
            isHost: isHost,
            showParticipants: false,
            showNotes: false,
            showChat: false,
            unreadChat: unreadChat,
            endingMeeting: false,
            togglingScreenShare: false,
            onToggleMic: onToggleMic ?? () {},
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
            onEndMeeting: () {},
            onLeaveMeeting: onLeave ?? () {},
            handRaised: handRaised,
            onToggleHand: () {},
            onReact: () {},
          ),
        ),
      ),
    );
    await tester.pump();
  }

  RealtimeState state({bool mic = true, bool camera = false, bool screen = false}) =>
      RealtimeState.initial().copyWith(
        microphoneEnabled: mic,
        cameraEnabled: camera,
        isScreenSharing: screen,
      );

  group('the bar renders and works', () {
    testWidgets('it builds without a socket, a camera or a provider',
        (tester) async {
      await pump(tester, state: state());
      expect(find.byType(MeetingControlBar), findsOneWidget);
    });

    testWidgets('the microphone control actually fires', (tester) async {
      var toggled = 0;
      await pump(tester, state: state(), onToggleMic: () => toggled++);
      await tester.tap(find.text('Mute'));
      await tester.pump();
      expect(toggled, 1);
    });
  });

  group('§VII — every control says what it is and what state it is in', () {
    testWidgets('the microphone announces its state, not its icon',
        (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester, state: state(mic: true));
      expect(find.bySemanticsLabel(RegExp('Microphone on')), findsOneWidget);

      await pump(tester, state: state(mic: false));
      expect(find.bySemanticsLabel(RegExp('Microphone off')), findsOneWidget);
      handle.dispose();
    });

    testWidgets('the camera control no longer reads the same in both states',
        (tester) async {
      // THE DEFECT: the visible label was 'Camera' whether the camera was on
      // or off — the one control in the bar whose word never changed, so it
      // never said what pressing it would do.
      await pump(tester, state: state(camera: false));
      expect(find.text('Start video'), findsOneWidget);

      await pump(tester, state: state(camera: true));
      expect(find.text('Stop video'), findsOneWidget);
    });

    testWidgets('a raised hand is audible, not just drawn', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester, state: state(), handRaised: true);
      expect(find.bySemanticsLabel(RegExp('Hand raised')), findsOneWidget);
      handle.dispose();
    });

    testWidgets('the unread count is spoken, not only coloured',
        (tester) async {
      // The badge is a small coloured bubble. Nobody can hear a bubble.
      final handle = tester.ensureSemantics();
      await pump(tester, state: state(), unreadChat: 3);
      expect(find.bySemanticsLabel(RegExp('3 unread')), findsOneWidget);
      handle.dispose();
    });

    testWidgets('screen sharing announces whether it is happening',
        (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester, state: state(screen: true));
      expect(
          find.bySemanticsLabel(RegExp('Screen sharing on')), findsOneWidget);
      handle.dispose();
    });
  });

  group('§VII — touch targets', () {
    testWidgets('every control is big enough to hit with a finger',
        (tester) async {
      await pump(tester, state: state());
      final buttons = find.byType(ControlButton);
      expect(buttons, findsWidgets);
      for (var i = 0; i < tester.widgetList(buttons).length; i++) {
        final size = tester.getSize(buttons.at(i));
        expect(size.width, greaterThanOrEqualTo(44),
            reason: 'control $i is narrower than a fingertip');
        expect(size.height, greaterThanOrEqualTo(44),
            reason: 'control $i is shorter than a fingertip');
      }
    });
  });

  group('host controls', () {
    testWidgets('a participant is not offered the meeting-wide end',
        (tester) async {
      await pump(tester, state: state(), isHost: false);
      expect(find.text('End'), findsNothing);
    });

    testWidgets('a host is', (tester) async {
      await pump(tester, state: state(), isHost: true);
      expect(find.text('End'), findsOneWidget);
    });
  });
}
