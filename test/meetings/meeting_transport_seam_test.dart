// THE MEETING TRANSPORT SEAM — a rule that is now enforced, not just written.
//
// `meeting_live_room_screen.dart` has always carried this comment:
//
//   E1 — MeetingTransportBridge: sole interface between meeting UI and WebRTC
//   layer. All mic/camera/screen operations from meeting widgets MUST go
//   through this bridge. Direct calls to RealtimeController or
//   RealtimeMediaService from meeting widgets are forbidden.
//
// The file broke that rule in three places, and for an understandable reason:
// the bridge exposed only toggles, so a saved "join muted" preference and the
// device picker could not be expressed through it. When a seam cannot say what
// a caller needs, the caller goes around it.
//
// So the fix was to complete the seam, not to police the callers. This test
// keeps both halves true.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _liveRoom =
    'lib/features/meetings/presentation/meeting_live_room_screen.dart';

void main() {
  late final String src;
  setUpAll(() => src = File(_liveRoom).readAsStringSync());

  group('THE BRIDGE IS THE SOLE INTERFACE', () {
    test('the media service is read ONLY to construct the bridge', () {
      // Every legitimate read passes it straight into a MeetingTransportBridge.
      // Any other read is a widget holding the transport directly.
      final reads = RegExp(r'ref\.read\(realtimeMediaServiceProvider\)')
          .allMatches(src)
          .length;
      final asBridgeArg = RegExp(r'mediaService: ref\.read\(realtimeMediaServiceProvider\)')
          .allMatches(src)
          .length;
      expect(
        reads,
        asBridgeArg,
        reason: 'a meeting widget is reading the media service for something '
            'other than building the bridge — $reads reads, $asBridgeArg of '
            'them constructing',
      );
    });

    test('no widget calls a media-service operation directly', () {
      // The three that used to: setMicrophoneEnabled, setCameraEnabled and the
      // device-switching trio.
      for (final forbidden in [
        'media.setMicrophoneEnabled(',
        'media.setCameraEnabled(',
        'media.switchVideoInput(',
        'media.switchAudioInput(',
        'media.setAudioOutput(',
      ]) {
        expect(src, isNot(contains(forbidden)),
            reason: '$forbidden bypasses the bridge');
      }
    });
  });

  group('ABSOLUTE OPERATIONS ARE ABSOLUTE', () {
    test('mute and unmute are not the same call', () {
      // All four were `toggle`, so `unmuteLocalMic()` muted an unmuted mic and
      // `enableLocalCamera()` turned a running camera off. The consequence was
      // not cosmetic: a host mute-request calls `muteLocalMic()`, so muting an
      // already-muted participant UNMUTED them.
      expect(src, contains('Future<void> muteLocalMic() => setLocalMic(false);'));
      expect(src, contains('Future<void> unmuteLocalMic() => setLocalMic(true);'));
      expect(src,
          contains('Future<void> disableLocalCamera() => setLocalCamera(false);'));
      expect(src,
          contains('Future<void> enableLocalCamera() => setLocalCamera(true);'));
    });

    test('the absolute operations rest on the service\'s own set API', () {
      // `setMicrophoneEnabled` / `setCameraEnabled` existed the whole time.
      expect(src, contains('_mediaService.setMicrophoneEnabled(enabled)'));
      expect(src, contains('_mediaService.setCameraEnabled(enabled)'));
    });

    test('no absolute-sounding bridge method is backed by a toggle', () {
      final bridge = src.substring(
        src.indexOf('class MeetingTransportBridge'),
        src.indexOf('// E2 — MeetingLiveRoomScreen'),
      );
      for (final absolute in [
        'muteLocalMic',
        'unmuteLocalMic',
        'disableLocalCamera',
        'enableLocalCamera',
      ]) {
        final line = bridge
            .split('\n')
            .where((l) => !l.trimLeft().startsWith('//'))
            .firstWhere((l) => l.contains('$absolute()'), orElse: () => '');
        expect(line, isNot(contains('toggle')),
            reason: '$absolute is named absolutely and toggles');
      }
    });
  });

  group('THE SEAM CAN SAY WHAT CALLERS NEED', () {
    test('it exposes set, readiness, and device routing', () {
      // The reason the rule was broken was that it could not. Each of these
      // corresponds to a bypass that existed before it.
      for (final member in [
        'Future<void> setLocalMic(bool enabled)',
        'Future<void> setLocalCamera(bool enabled)',
        'bool get mediaReady',
        'String? get preferredCameraId',
        'String? get preferredMicId',
        'String? get preferredSpeakerId',
        'Future<void> switchCamera(String deviceId)',
        'Future<void> switchMic(String deviceId)',
        'Future<void> routeAudioOutput(String deviceId)',
      ]) {
        expect(src, contains(member), reason: 'the bridge lost $member');
      }
    });
  });
}
