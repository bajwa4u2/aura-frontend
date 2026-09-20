import 'dart:io';

import 'package:aura/features/realtime/data/realtime_media_service.dart';
import 'package:aura/features/realtime/domain/quality_sample_payload.dart';
import 'package:flutter_test/flutter_test.dart';

/// WHY DID THIS CALL FAIL, not merely THAT one did.
///
/// `RealtimeSessionQualitySample` holds 4,115 rows and the last was written on
/// 2026-08-28 — none in the twenty-two days that followed, which covers the
/// whole 1.4.3 period the founder's complaints are about. Nothing was broken:
/// the sampler walked the MESH peer map, calls moved to the stage, the stage
/// was not in that map, so every field came back null, the heartbeat attached
/// nothing, and no error was ever raised.
///
/// These tests pin the two things that failure turned on: the measurement must
/// be read wherever the media actually is, and it must be reported on an event
/// of its own that can be SEEN to be missing.
void main() {
  const sessionId = 'sess_1';

  Map<String, dynamic> payloadFor(RealtimeQualitySample sample) =>
      buildQualitySamplePayload(
        sessionId: sessionId,
        sample: sample,
        appLifecycleState: 'foreground',
        reconnectState: 'stable',
        clientPlatform: 'windows',
        clientVersion: '1.4.4+39',
      );

  group('zero is a measurement, absent is not', () {
    test('a measured zero is SENT as zero, not dropped as falsy', () {
      // The one-way-audio shape: an audio track was negotiated and not one
      // packet arrived on it. Dropping this because it is zero is what made
      // the defect undiagnosable three times over.
      final payload = payloadFor(const RealtimeQualitySample(
        audioBytesReceived: 0,
        videoBytesReceived: 614911,
      ));

      expect(payload.containsKey('audioBytesReceived'), isTrue);
      expect(payload['audioBytesReceived'], 0);
      expect(payload['videoBytesReceived'], 614911);
    });

    test('an unmeasured field is OMITTED, so the server stores null', () {
      // No receiving audio track exists at all — a different fact from one
      // receiving nothing, and the server must be able to tell them apart.
      final payload = payloadFor(const RealtimeQualitySample(
        videoBytesReceived: 267879,
      ));

      expect(payload.containsKey('audioBytesReceived'), isFalse);
      expect(payload['videoBytesReceived'], 267879);
    });

    test('bytes arriving with zero frames decoded is reportable, and is the '
        'black-tile signature', () {
      // 2026-09-16: 614,911 bytes of video and a black tile. Bytes prove the
      // network; frames and a real frame size prove a picture.
      final payload = payloadFor(const RealtimeQualitySample(
        videoBytesReceived: 614911,
        videoFramesDecoded: 0,
        videoFrameWidth: 0,
        videoFrameHeight: 0,
      ));

      expect(payload['videoBytesReceived'], 614911);
      expect(payload['videoFramesDecoded'], 0);
      expect(payload['videoFrameWidth'], 0);
      expect(payload['videoFrameHeight'], 0);
    });

    test('an entirely unmeasured sample still names the session and the '
        'client, and claims no measurement', () {
      final payload = payloadFor(const RealtimeQualitySample());

      expect(payload['sessionId'], sessionId);
      expect(payload['clientPlatform'], 'windows');
      for (final measured in const [
        'rtt',
        'jitter',
        'packetLoss',
        'bitrateKbps',
        'audioBytesReceived',
        'videoBytesReceived',
        'videoFramesDecoded',
        'videoFrameWidth',
        'videoFrameHeight',
        'selectedCandidateType',
        'transportProtocol',
        'networkType',
        'transportState',
      ]) {
        expect(payload.containsKey(measured), isFalse,
            reason: '$measured was not measured and must not be invented');
      }
    });

    test('a platform that withholds the path reports no path, not UNKNOWN', () {
      // Some browsers refuse network type for fingerprinting reasons. A
      // withheld fact is absent; UNKNOWN-the-measurement would be a claim.
      final payload = payloadFor(const RealtimeQualitySample(rttMs: 343));

      expect(payload['rtt'], 343);
      expect(payload.containsKey('networkType'), isFalse);
      expect(payload.containsKey('selectedCandidateType'), isFalse);
    });

    test('a version is omitted until the package answers, never guessed', () {
      final payload = buildQualitySamplePayload(
        sessionId: sessionId,
        sample: const RealtimeQualitySample(rttMs: 12),
        appLifecycleState: 'background',
        reconnectState: 'reconnecting',
        clientPlatform: 'android',
        clientVersion: null,
      );

      expect(payload.containsKey('clientVersion'), isFalse);
      // The states the device WAS in are always known and always sent.
      expect(payload['appLifecycleState'], 'background');
      expect(payload['reconnectState'], 'reconnecting');
    });

    test('nothing that could carry content is ever in the payload', () {
      final payload = payloadFor(const RealtimeQualitySample(
        rttMs: 1,
        audioBytesReceived: 2,
        transportState: 'connected',
      ));

      // Counters, states and ids only — no transcript, no message, no
      // contact detail, no track label.
      const forbidden = ['body', 'text', 'transcript', 'email', 'phone',
          'name', 'label', 'message', 'content'];
      for (final key in payload.keys) {
        final lower = key.toLowerCase();
        for (final bad in forbidden) {
          expect(lower.contains(bad), isFalse,
              reason: 'payload key "$key" could carry content');
        }
      }
    });
  });

  group('hasAny answers for the whole sample', () {
    test('a sample carrying only the new dimensions still counts as evidence',
        () {
      // Before the stage fix `hasAny` only knew the four heartbeat fields. A
      // sample that measured bytes-by-kind and nothing else would have been
      // discarded as empty.
      expect(const RealtimeQualitySample(audioBytesReceived: 0).hasAny, isTrue);
      expect(const RealtimeQualitySample(videoFramesDecoded: 0).hasAny, isTrue);
      expect(
          const RealtimeQualitySample(transportState: 'connected').hasAny,
          isTrue);
      expect(const RealtimeQualitySample().hasAny, isFalse);
    });
  });

  /// Source-level, matching this screen's precedent (`call_media_truth_test`):
  /// the sampling loop needs a live WebRTC stack, so what is asserted here is
  /// the WIRING that failed — where the measurement is read from, and which
  /// beat reports it.
  group('the measurement is taken where the media is', () {
    final media =
        File('lib/features/realtime/data/realtime_media_service.dart')
            .readAsStringSync();
    final controller =
        File('lib/features/realtime/application/realtime_controller.dart')
            .readAsStringSync();
    final transport =
        File('lib/features/realtime/data/sfu_realtime_transport.dart')
            .readAsStringSync();

    test('the sampler asks the STAGE, not only the mesh peer map', () {
      final collect = media.substring(
          media.indexOf('Future<RealtimeQualitySample> collectQualitySample'));
      final body = collect.substring(0, collect.indexOf('\n  }\n'));

      expect(body.contains('stage.collectStats()'), isTrue,
          reason: 'the stage holds the connection for every call today');
      // ASKING IS NOT READING. An earlier version of this test passed while
      // the stage's answer was collected and then dropped on the floor, which
      // is the same all-nulls sample the original defect produced.
      expect(body.contains("sources['stage:"), isTrue,
          reason: "the stage's reports must reach the stats loop, not just "
              'be requested');
      expect(body.contains('_peers'), isTrue,
          reason: 'mesh must keep working — this is additive');
    });

    test('the stage transport can be asked for its raw stats', () {
      expect(transport.contains('Future<List<StatsReport>?> collectStats()'),
          isTrue);
      // Unreadable is not a measurement of zero.
      expect(transport.contains('return null;'), isTrue);
    });

    test('quality reports on its OWN event, not folded into the heartbeat',
        () {
      expect(controller.contains("emitAck('session:quality'"), isTrue);

      final heartbeat =
          controller.substring(controller.indexOf('void _sendHeartbeat('));
      final heartbeatBody =
          heartbeat.substring(0, heartbeat.indexOf('\n  void _stopHeartbeat'));
      expect(heartbeatBody.contains('session:quality'), isFalse,
          reason: 'riding the heartbeat is exactly how this went unnoticed '
              'for three weeks');
      expect(heartbeatBody.contains("emitAck('session:heartbeat'"), isTrue,
          reason: 'the older ingest path stays exactly as it was');
    });

    test('it rides the stats cadence, and a failed report cannot hurt a call',
        () {
      final startStats =
          controller.substring(controller.indexOf('void _startStatsTimer()'));
      final body =
          startStats.substring(0, startStats.indexOf('\n  /// `session:quality`'));
      expect(body.contains('_statsInterval'), isTrue);
      expect(body.contains('_sendQualitySample(sample)'), isTrue);

      final send =
          controller.substring(controller.indexOf('void _sendQualitySample('));
      final sendBody = send.substring(0, send.indexOf('\n  /// foreground'));
      expect(sendBody.contains('unawaited('), isTrue);
      expect(sendBody.contains('catchError'), isTrue,
          reason: 'an older server has no handler for this event');
    });
  });
}
