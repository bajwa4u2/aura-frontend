import 'package:flutter_test/flutter_test.dart';

import 'package:aura/features/realtime/domain/call_mode.dart';

/// The defect these pin, in the words of the symptom: an attendee sitting in
/// an "audio meeting" while the caller was in a video call.
///
/// Two places derived call mode and disagreed. The older one, from
/// 2026-03-30, mapped anything not literally "video" to audio — which sent
/// MIXED, the kind meetings are created with, to audio. The guest then
/// captured an audio-only stream, published no video track, and had nothing
/// for "Show camera" to enable.
void main() {
  group('session kind is the sole authority for call mode', () {
    test('VIDEO is video', () {
      expect(callModeForSessionKind('VIDEO'), 'video');
    });

    test('MIXED is VIDEO-CAPABLE, not audio', () {
      // The assertion that fails under the old behaviour. Meetings are created
      // with kind MIXED, so this single mapping decides whether a meeting
      // attendee can use their camera at all.
      expect(callModeForSessionKind('MIXED'), 'video');
    });

    test('AUDIO is audio', () {
      expect(callModeForSessionKind('AUDIO'), 'audio');
    });

    test('case and padding do not change the answer', () {
      expect(callModeForSessionKind(' mixed '), 'video');
      expect(callModeForSessionKind('video'), 'video');
      expect(callModeForSessionKind('Audio'), 'audio');
    });

    test('an unknown kind falls back rather than silently downgrading', () {
      // Downgrading an unrecognised kind to audio is precisely the mistake
      // this function exists to prevent, so absence must be distinguishable.
      expect(callModeForSessionKind(null, fallback: 'video'), 'video');
      expect(callModeForSessionKind('', fallback: 'video'), 'video');
      expect(callModeForSessionKind('SOMETHING_NEW', fallback: 'video'), 'video');
      expect(callModeForSessionKind('SOMETHING_NEW'), isNull);
    });

    test('MIXED never resolves to audio under any casing', () {
      for (final kind in ['MIXED', 'mixed', 'Mixed', ' MIXED']) {
        expect(callModeForSessionKind(kind, fallback: 'audio'), 'video',
            reason: '$kind must remain video-capable');
      }
    });
  });
}
