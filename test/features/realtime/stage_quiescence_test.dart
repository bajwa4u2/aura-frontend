import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'package:aura/features/realtime/data/realtime_media_service.dart';
import 'package:aura/features/realtime/data/realtime_transport.dart';
import 'package:aura/features/realtime/domain/remote_media_presentation.dart';

/// THE LOOP MUST NOT COME BACK.
///
/// Measured from the operation trace on 2026-08-26: nineteen SUBSCRIBE
/// operations in five seconds, every one succeeding, signalling never leaving
/// Stable. Nothing failed — which is why three separate causal theories missed
/// it entirely. The refresh published a snapshot unconditionally, the
/// controller re-ran media-ready reconciliation on every snapshot, and that
/// called the refresh again. Roughly three network round-trips per second for
/// the length of the call, until the UI starved.
///
/// The invariant that prevents its return:
///
///     unchanged remote media  ->  no new presentation state
///                             ->  nothing for a listener to react to
///                             ->  no recursive refresh
///
/// and, so the fix cannot be "never publish":
///
///     changed remote media    ->  exactly one update  ->  stable
class _ScriptedTransport implements RealtimeTransport {
  Map<String, RemoteParticipantMedia> next = const {};
  int refreshes = 0;

  @override
  String get id => 'scripted';

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
    refreshes++;
    // A NEW MAP OBJECT each time, carrying the same content — exactly what the
    // real transport returns. Identity comparison would call this a change and
    // the loop would restart.
    return Map<String, RemoteParticipantMedia>.from(next);
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
  Future<RealtimeTransportStats> stats() async => const RealtimeTransportStats(
      inboundBytes: 0, outboundBytes: 0, uploadPathCount: 0);
}

class _Track implements MediaStreamTrack {
  _Track(this._id, this._kind);
  final String _id;
  final String _kind;
  @override
  String? get id => _id;
  @override
  String? get kind => _kind;
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  test('unchanged remote media emits nothing, so nothing can re-trigger it',
      () async {
    final service = RealtimeMediaService();
    final transport = _ScriptedTransport()
      ..next = {
        'part-alice': RemoteParticipantMedia(
          participantId: 'part-alice',
          audio: _Track('a-1', 'audio'),
        ),
      };

    final emissions = <int>[];
    final sub = service.snapshots.listen((s) => emissions.add(s.remoteByParticipant.length));

    await service.attachStage(transport, sessionId: 's1');
    await Future<void>.delayed(Duration.zero);
    final afterAttach = emissions.length;

    // The controller re-runs reconciliation on every snapshot; simulate it
    // asking repeatedly, which is legitimate and must stay legitimate.
    for (var i = 0; i < 5; i++) {
      await service.refreshStageRemoteMedia();
    }
    await Future<void>.delayed(Duration.zero);

    expect(transport.refreshes, greaterThan(5),
        reason: 'the product may ask as often as it likes');
    expect(emissions.length, afterAttach,
        reason: 'unchanged media re-emitted presentation state — this is the '
            'loop returning');

    await sub.cancel();
  });

  test('changed remote media emits exactly once and then goes quiet', () async {
    final service = RealtimeMediaService();
    final transport = _ScriptedTransport()
      ..next = {
        'part-alice': RemoteParticipantMedia(
          participantId: 'part-alice',
          audio: _Track('a-1', 'audio'),
        ),
      };

    final emissions = <int>[];
    final sub = service.snapshots.listen((s) => emissions.add(s.remoteByParticipant.length));

    await service.attachStage(transport, sessionId: 's1');
    await Future<void>.delayed(Duration.zero);
    final baseline = emissions.length;

    // Alice turns her camera on: a genuine change.
    transport.next = {
      'part-alice': RemoteParticipantMedia(
        participantId: 'part-alice',
        audio: _Track('a-1', 'audio'),
        video: _Track('v-1', 'video'),
      ),
    };
    await service.refreshStageRemoteMedia();
    await Future<void>.delayed(Duration.zero);

    expect(emissions.length, baseline + 1,
        reason: 'a real change must reach the product exactly once');

    // ...and the system settles again rather than oscillating.
    for (var i = 0; i < 4; i++) {
      await service.refreshStageRemoteMedia();
    }
    await Future<void>.delayed(Duration.zero);
    expect(emissions.length, baseline + 1,
        reason: 'control plane did not go quiet after convergence');

    await sub.cancel();
  });

  test('a participant leaving is a change, and is emitted once', () async {
    final service = RealtimeMediaService();
    final transport = _ScriptedTransport()
      ..next = {
        'part-alice': RemoteParticipantMedia(
          participantId: 'part-alice',
          audio: _Track('a-1', 'audio'),
        ),
      };
    final emissions = <int>[];
    final sub = service.snapshots.listen((s) => emissions.add(s.remoteByParticipant.length));

    await service.attachStage(transport, sessionId: 's1');
    await Future<void>.delayed(Duration.zero);
    final baseline = emissions.length;

    transport.next = const {};
    await service.refreshStageRemoteMedia();
    await service.refreshStageRemoteMedia();
    await Future<void>.delayed(Duration.zero);

    expect(emissions.length, baseline + 1);
    expect(emissions.last, 0);

    await sub.cancel();
  });
}
