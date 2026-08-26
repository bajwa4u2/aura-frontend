import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'package:aura/features/realtime/data/realtime_media_service.dart';
import 'package:aura/features/realtime/data/realtime_transport.dart';
import 'package:aura/features/realtime/domain/remote_media_presentation.dart';

/// SUBSCRIBING RACES THE PUBLISHER, AND LOSING ONCE MUST NOT BE FATAL.
///
/// Measured against production 2026-08-26: Aura records a track the moment its
/// publisher reports it, but the provider cannot forward that track until the
/// publisher's transport is actually carrying media. Asking too early is
/// refused — `cloudflare_empty_track_error` — and it is intermittent: the same
/// code failed one run and passed the next.
///
/// The consequence in the product was not intermittent at all. A single early
/// refusal propagated out of the convergence loop, so the receiver never tried
/// again and sat in a connected call with no remote media, in both directions,
/// in two live browser calls.
class _FlakyTransport implements RealtimeTransport {
  _FlakyTransport({required this.failuresBeforeSuccess});

  final int failuresBeforeSuccess;
  int attempts = 0;

  @override
  String get id => 'fake';

  @override
  Future<void> open({
    required String sessionId,
    MediaStream? local,
    String trigger = 'TEST',
  }) async {}

  @override
  Future<void> publishLocal({String trigger = 'TEST'}) async {}

  @override
  Future<Map<String, RemoteParticipantMedia>> refreshRemoteMedia({
    String trigger = 'TEST',
  }) async {
    attempts++;
    if (attempts <= failuresBeforeSuccess) {
      throw StateError('stage subscribe failed: cloudflare_empty_track_error');
    }
    return <String, RemoteParticipantMedia>{
      'part-alice': const RemoteParticipantMedia(participantId: 'part-alice'),
    };
  }

  @override
  Future<void> replaceVideoSource(MediaStreamTrack track) async {}
  @override
  Future<void> setMicrophoneEnabled(bool enabled) async {}
  @override
  Future<void> setCameraEnabled(bool enabled) async {}
  @override
  Future<void> close() async {}
  @override
  Future<RealtimeTransportStats> stats() async =>
      const RealtimeTransportStats(
          inboundBytes: 0, outboundBytes: 0, uploadPathCount: 0);
}

void main() {
  // Building a participant renderer touches platform channels. These tests
  // assert on media STATE, not on renderers, so the binding is initialised and
  // the plugin's absence is swallowed by the service's own guard.
  TestWidgetsFlutterBinding.ensureInitialized();

  test('an early refusal is retried, not fatal', () async {
    final service = RealtimeMediaService();
    final transport = _FlakyTransport(failuresBeforeSuccess: 2);

    await service.attachStage(transport, sessionId: 's1');
    await service.ensureStageRemoteMedia(
      attempts: 5,
      interval: const Duration(milliseconds: 1),
    );

    expect(transport.attempts, greaterThan(2),
        reason: 'convergence gave up on the first refusal');
    expect(service.currentSnapshot.remoteByParticipant, isNotEmpty,
        reason: 'the receiver never bound media after a transient refusal');
  });

  test('a room that never resolves surfaces rather than going quiet', () async {
    // An empty room and an unreachable one must not look the same.
    final service = RealtimeMediaService();
    final transport = _FlakyTransport(failuresBeforeSuccess: 999);

    // attachStage runs convergence itself, so an unreachable room surfaces
    // there — publication succeeded, remote media never did, and the caller
    // is told rather than left to infer it from an empty tile grid.
    await expectLater(
      service.attachStage(transport, sessionId: 's1'),
      throwsA(isA<StateError>()),
    );
    expect(service.usesStageTransport, isTrue,
        reason: 'publication succeeded, so the transport must survive — only '
            'remote resolution failed');
  });
}
