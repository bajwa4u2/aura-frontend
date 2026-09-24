import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// M-1 — A MEETING'S MIC AND CAMERA MUST TELL THE SESSION, NOT JUST THE DEVICE.
///
/// Measured on a real meeting, 2026-09-24 (founder ↔ Mrs Bajwa, both on web):
/// twelve minutes of pressing camera off and on produced **not one**
/// `VIDEO_STATE_CHANGED publishState=OFF` event on the server, and nothing
/// changed for the other participant. The meeting room's bridge called
/// `RealtimeMediaService.setMicrophoneEnabled` / `setCameraEnabled` directly:
///
///     Future<void> setLocalCamera(bool e) => _mediaService.setCameraEnabled(e);
///
/// That flips the local track and stops there — no `session:video.set`, so the
/// server's publish state never moved and the far side was never told. The
/// only thing that ever changed the other person's view was a page reload, and
/// each reload orphaned THEIR media (see M-2). Seven reloads in one meeting.
///
/// The bridge is still the seam between meeting UI and the transport — that
/// design is unchanged. It simply has to name the authority that owns the
/// whole act. This guards the wiring, because the behaviour it protects is
/// invisible to any single-client test: everything looks right locally, and
/// only the ABSENCE of a signal on the other side is the defect.
void main() {
  final bridge = File(
    'lib/features/meetings/presentation/meeting_live_room_screen.dart',
  ).readAsStringSync();
  final controller = File(
    'lib/features/realtime/application/realtime_controller.dart',
  ).readAsStringSync();

  group('the meeting bridge routes mic and camera through the controller', () {
    test('setLocalMic and setLocalCamera call the controller', () {
      expect(bridge, contains('_controller.setMicrophone(enabled)'));
      expect(bridge, contains('_controller.setCamera(enabled)'));
    });

    test('they no longer reach past it to the media service', () {
      expect(bridge, isNot(contains('_mediaService.setMicrophoneEnabled(')),
          reason: 'this is M-1: the hardware changes and nobody is told');
      expect(bridge, isNot(contains('_mediaService.setCameraEnabled(')),
          reason: 'this is M-1: the hardware changes and nobody is told');
    });

    test('the four intent methods stay intent-shaped, never toggles', () {
      // A previous repair fixed `unmuteLocalMic()` muting an unmuted mic by
      // giving each intention its own method. Routing through the controller
      // must not reintroduce a toggle behind an intention's name.
      expect(bridge, contains('Future<void> muteLocalMic() => setLocalMic(false)'));
      expect(bridge, contains('Future<void> unmuteLocalMic() => setLocalMic(true)'));
      expect(bridge,
          contains('Future<void> disableLocalCamera() => setLocalCamera(false)'));
      expect(bridge,
          contains('Future<void> enableLocalCamera() => setLocalCamera(true)'));
    });
  });

  group('the controller owns the whole act', () {
    test('setMicrophone signals the session', () {
      final start = controller.indexOf('Future<void> setMicrophone(bool enabled) async {');
      expect(start, greaterThan(-1), reason: 'setMicrophone is gone');
      final body = controller.substring(start, start + 2000);
      expect(body, contains("emitAck('session:audio.set'"));
      expect(body, contains('_mediaService.setMicrophoneEnabled(enabled)'));
      expect(body, contains('_patchMyTrack(audioOn: enabled)'));
    });

    test('setCamera signals the session and publishes what happened', () {
      final start = controller.indexOf('Future<void> setCamera(bool desired) async {');
      expect(start, greaterThan(-1), reason: 'setCamera is gone');
      final body = controller.substring(start, start + 3000);
      expect(body, contains("emitAck('session:video.set'"));
      // The publish carries the RESULT of acquisition, never the request —
      // the 2026-08-28 repair that must survive this refactor.
      expect(body, contains('final enabled = result.enabled;'));
      expect(body, contains("'enabled': enabled,"));
      expect(body, contains('_patchMyTrack(videoOn: enabled)'));
    });

    test('the toggles are thin wrappers, so Calls behave exactly as before', () {
      expect(controller,
          contains('Future<void> toggleMicrophone() => setMicrophone(!state.microphoneEnabled);'));
      expect(controller,
          contains('Future<void> toggleCamera() => setCamera(!state.cameraEnabled);'));
    });
  });
}
