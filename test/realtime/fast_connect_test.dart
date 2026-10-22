import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'package:aura/features/realtime/application/thread_call_lifecycle_controller.dart';
import 'package:aura/features/realtime/data/realtime_media_service.dart';
import 'package:aura/features/realtime/data/realtime_transport.dart';
import 'package:aura/features/realtime/domain/remote_media_presentation.dart';

/// ANSWER TO CONNECTED (2026-10-22, browser caller and Galaxy S24+ callee):
/// 9 to 12 s. Three causes in the client are pinned here.
class _LateRoomTransport implements RealtimeTransport {
  _LateRoomTransport({required this.emptyLooks});

  final int emptyLooks;
  int looks = 0;

  @override
  String get id => 'late-room';

  @override
  Future<void> report({
    required String phase,
    required String code,
    required String message,
  }) async {}

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
    looks++;
    if (looks <= emptyLooks) return const <String, RemoteParticipantMedia>{};
    return <String, RemoteParticipantMedia>{
      'part-bob': const RemoteParticipantMedia(participantId: 'part-bob'),
    };
  }

  @override
  Future<void> replaceVideoSource(MediaStreamTrack? track) async {}
  @override
  Future<void> replaceAudioSource(MediaStreamTrack? track) async {}
  @override
  Future<void> setMicrophoneEnabled(bool enabled) async {}
  @override
  Future<void> setCameraEnabled(bool enabled) async {}
  @override
  Future<void> close({String reason = 'EXPLICIT_LEAVE'}) async {}
  @override
  Future<List<StatsReport>?> collectStats() async => null;
  @override
  Future<RealtimeTransportStats> stats() async => const RealtimeTransportStats(
      inboundBytes: 0, outboundBytes: 0, uploadPathCount: 0);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('attach does not hold the stage while the other side is not there',
      () {
    test('attach returns after ONE look, not after the retry loop', () async {
      // The other side has not published yet: the next look would find
      // nothing for a while. The attach used to wait out six looks two
      // seconds apart, and the controller's gate was held all that time, so
      // the push that announced the other side's media was dropped.
      final service = RealtimeMediaService();
      final transport = _LateRoomTransport(emptyLooks: 100);
      final watch = Stopwatch()..start();
      await service.attachStage(transport, sessionId: 's1');
      watch.stop();
      expect(transport.looks, 1);
      expect(watch.elapsedMilliseconds, lessThan(900));
      await service.resetSessionMedia();
    });

    test('a look prompted later (a push) finds what was published', () async {
      final service = RealtimeMediaService();
      final transport = _LateRoomTransport(emptyLooks: 1);
      await service.attachStage(transport, sessionId: 's1');
      expect(service.currentSnapshot.remoteByParticipant, isEmpty);
      // What the controller does on `session:media.published`.
      await service.refreshStageRemoteMedia(trigger: 'media.published');
      expect(service.currentSnapshot.remoteByParticipant.keys, ['part-bob']);
      await service.resetSessionMedia();
    });
  });

  group('the ring says which call it is, so capture can start at Answer', () {
    test('video', () {
      expect(
          callIsVideoFromRing({
            'data': {'callKind': 'video'}
          }),
          isTrue);
      expect(callIsVideoFromRing({'mediaMode': 'VIDEO'}), isTrue);
    });
    test('audio and voice', () {
      expect(
          callIsVideoFromRing({
            'data': {'callKind': 'audio'}
          }),
          isFalse);
      expect(
          callIsVideoFromRing({
            'data': {'mode': 'voice'}
          }),
          isFalse);
    });
    test('a ring that does not say leaves capture to the join', () {
      expect(callIsVideoFromRing({'data': <String, dynamic>{}}), isNull);
      expect(callIsVideoFromRing(<String, dynamic>{}), isNull);
    });
  });
}
