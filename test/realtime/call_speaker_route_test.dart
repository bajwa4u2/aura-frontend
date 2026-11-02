import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// THE SPEAKER MUST ACTUALLY TURN ON.
///
/// 2026-11-02, S24: every video call played through the earpiece, and the
/// speaker button did nothing on an audio call. Two causes: the default route
/// ran only when the call itself opened the devices, and while Android's
/// Telecom holds a call it owns the route and overrides AudioManager.
void main() {
  final kotlin = File(
    'android/app/src/main/kotlin/org/auraplatform/app/AuraTelecom.kt',
  ).readAsStringSync();
  final telecom =
      File('lib/core/notifications/android_telecom.dart').readAsStringSync();
  final media = File('lib/features/realtime/data/realtime_media_service.dart')
      .readAsStringSync();
  final controller =
      File('lib/features/realtime/application/realtime_controller.dart')
          .readAsStringSync();

  test('Android asks Telecom for the speaker while it holds the call', () {
    expect(kotlin, contains('"setSpeaker" ->'));
    expect(kotlin, contains('control.requestEndpointChange(endpoint)'));
    expect(kotlin, contains('CallEndpointCompat.TYPE_SPEAKER'));
    expect(telecom, contains("invokeMethod<bool>('setSpeaker'"));
  });

  test("the speaker toggle tells Telecom, then WebRTC's own switch", () {
    final start = media.indexOf('Future<void> setSpeakerphoneEnabled(');
    final body = media.substring(start, media.indexOf('removePeer(', start));
    final telecomAt = body.indexOf('AndroidTelecom.instance.setSpeaker(enabled)');
    final webrtcAt = body.indexOf('await Helper.setSpeakerphoneOn(enabled)');
    expect(telecomAt, greaterThan(-1));
    expect(webrtcAt, greaterThan(telecomAt),
        reason: "WebRTC's own switch picks the speaker by itself; told only "
            'Telecom, sound and button disagreed on the S24');
  });

  test('a headset is never pulled off when the speaker goes off', () {
    expect(kotlin,
        contains('if (!speaker && current.type != CallEndpointCompat.TYPE_SPEAKER) return'));
  });

  test('the default output is applied once per call, devices open or not', () {
    expect(controller, contains('if (_routeDefaultSessionId != sessionId && !receiveOnly)'));
    final capture = controller.indexOf('if (capture != null) {');
    final ready = controller.indexOf("debugPrint('[media-seq] capture ready", capture);
    final captureBlockEnd = controller.indexOf('reportStageDiagnostic', ready);
    expect(
      controller.substring(capture, captureBlockEnd),
      isNot(contains('_speakerDefaultFor')),
      reason: 'inside the capture block it is skipped whenever the devices '
          'were already open',
    );
  });
}
