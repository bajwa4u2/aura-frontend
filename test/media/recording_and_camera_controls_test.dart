import 'dart:io';

import 'package:aura/core/media/recording_time.dart';
import 'package:flutter_test/flutter_test.dart';

/// FOUNDER, 2026-09-19 — two controls that were missing or mute.
///
///   "in video call screen camera toggle /front/back is missing"
///   "recording voice message is deadlike not showing recording time"
///
/// The arithmetic behind the recording indicator is pure and tested here. The
/// call-dock rules are asserted at source level, the precedent this repo
/// already uses for `realtime_room_screen.dart`: the widget tree needs the
/// whole realtime graph, a camera and a microphone, so a widget test would
/// prove the harness rather than the product.
void main() {
  group('recording elapsed time', () {
    test('reads like every other clock a person already knows', () {
      expect(formatRecordingElapsed(Duration.zero), '0:00');
      expect(formatRecordingElapsed(const Duration(seconds: 7)), '0:07');
      expect(formatRecordingElapsed(const Duration(seconds: 65)), '1:05');
      expect(formatRecordingElapsed(const Duration(minutes: 10)), '10:00');
    });

    test('an hour-long note grows an hours field rather than 60+ minutes', () {
      expect(formatRecordingElapsed(const Duration(minutes: 59, seconds: 59)), '59:59');
      expect(formatRecordingElapsed(const Duration(hours: 1, seconds: 5)), '1:00:05');
      expect(formatRecordingElapsed(const Duration(hours: 2, minutes: 3, seconds: 4)), '2:03:04');
    });

    test('a length never runs backwards', () {
      // Clock skew, or a stop that lands a millisecond early.
      expect(formatRecordingElapsed(const Duration(seconds: -3)), '0:00');
    });
  });

  group('microphone level', () {
    test('is a measurement of dBFS, clamped rather than exaggerated', () {
      expect(normalizeRecordingLevel(0), 1.0);
      expect(normalizeRecordingLevel(kRecordingFloorDbfs), 0.0);
      expect(normalizeRecordingLevel(kRecordingFloorDbfs / 2), closeTo(0.5, 0.001));
      // Louder than full scale and quieter than the floor are both clamped:
      // the bar states what was measured, never more.
      expect(normalizeRecordingLevel(12), 1.0);
      expect(normalizeRecordingLevel(-120), 0.0);
    });

    test('an unreadable reading rests at zero instead of drawing noise', () {
      expect(normalizeRecordingLevel(double.nan), 0.0);
      expect(normalizeRecordingLevel(double.negativeInfinity), 0.0);
    });
  });

  group('the call dock offers a camera flip', () {
    final src = File('lib/features/realtime/presentation/realtime_room_screen.dart')
        .readAsStringSync();

    test('it exists at all — the 1:1 call screen had none', () {
      expect(src.contains('Icons.flip_camera_ios_rounded'), isTrue);
      expect(src.contains('MediaControlLabels.cameraFlipAction'), isTrue);
    });

    test('it appears only in video calls, and only where flipping is real', () {
      expect(
        src.contains('if (showPublishControls && isVideoMode && onFlipCamera != null)'),
        isTrue,
      );
      // `supportsCameraCapture` is the platform authority for front/back
      // hardware. A desktop with one webcam has nothing to flip between.
      expect(src.contains('onFlipCamera: supportsCameraCapture'), isTrue);
    });

    test('with the camera off it is disabled, not hidden', () {
      expect(src.contains('onPressed: cameraOn ? onFlipCamera : null'), isTrue);
      // The dock button therefore has to be able to be unavailable.
      expect(src.contains('final VoidCallback? onPressed;'), isTrue);
    });

    test('the self-view stops mirroring once the rear camera is in use', () {
      expect(src.contains('mirror: localIsFrontCamera'), isTrue);
      expect(src.contains('localIsFrontCamera: state.cameraIsFront'), isTrue);
    });
  });

  group('the recording bar', () {
    final src = File('lib/features/conversation/presentation/conversation_screen.dart')
        .readAsStringSync();

    test('shows the elapsed time the founder could not see', () {
      expect(src.contains('formatRecordingElapsed(elapsed)'), isTrue);
      expect(src.contains('if (_recording)'), isTrue);
    });

    test('offers a way out, because stopping is sending', () {
      expect(src.contains('Future<void> _cancelVoiceNote()'), isTrue);
      expect(src.contains('VoiceNoteCapture.discardCaptured(handle)'), isTrue);
    });

    test('stops its clock and its meter when recording ends', () {
      expect(src.contains('_endRecordingIndicators()'), isTrue);
      expect(src.contains('_recordingTicker?.cancel()'), isTrue);
      expect(src.contains('_recordingAmplitude?.cancel()'), isTrue);
    });
  });
}
