import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'package:aura/features/realtime/data/stage_remote_binding.dart';
import 'package:aura/features/realtime/domain/remote_media_presentation.dart';

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

class _Stream implements MediaStream {
  _Stream(this._audio, this._video);
  final List<MediaStreamTrack> _audio;
  final List<MediaStreamTrack> _video;
  @override
  List<MediaStreamTrack> getAudioTracks() => _audio;
  @override
  List<MediaStreamTrack> getVideoTracks() => _video;
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  final aliceAudio = _Track('a-a', 'audio');
  final aliceVideo = _Track('a-v', 'video');

  group('one canonical model, two transports feeding it', () {
    test('mesh resolves a device-keyed stream to the participant', () {
      final out = meshRemoteMedia(
        streamsByDeviceId: {'device-alice': _Stream([aliceAudio], [aliceVideo])},
        roster: const [
          ParticipantRef(id: 'part-alice', userId: 'alice', runtimeDeviceId: 'device-alice'),
          ParticipantRef(id: 'part-me', userId: 'me', runtimeDeviceId: 'device-me'),
        ],
        selfUserId: 'me',
      );

      expect(out.keys, ['part-alice']);
      expect(out['part-alice']!.hasVideo, isTrue);
      expect(out['part-alice']!.audio!.id, 'a-a');
    });

    test('mesh never presents the local participant as remote', () {
      final out = meshRemoteMedia(
        streamsByDeviceId: {'device-me': _Stream([aliceAudio], const [])},
        roster: const [
          ParticipantRef(id: 'part-me', userId: 'me', runtimeDeviceId: 'device-me'),
        ],
        selfUserId: 'me',
      );
      expect(out, isEmpty);
    });

    test('mesh drops a stream whose device is not in the roster', () {
      // The old UI invented an unnamed "Participant" tile for these. Guessing
      // an identity in the MAPPING would put an unattributed face on screen;
      // whether to show an unidentified tile is presentation policy.
      final out = meshRemoteMedia(
        streamsByDeviceId: {'unknown-device': _Stream([aliceAudio], const [])},
        roster: const [
          ParticipantRef(id: 'part-me', userId: 'me', runtimeDeviceId: 'device-me'),
        ],
        selfUserId: 'me',
      );
      expect(out, isEmpty);
    });

    test('SFU groups server-resolved bindings under one participant', () {
      final out = sfuRemoteMedia(bindings: [
        StageRemoteBinding(
          participantId: 'part-alice',
          trackId: 't1',
          trackType: 'AUDIO',
          mid: '2',
          track: aliceAudio,
        ),
        StageRemoteBinding(
          participantId: 'part-alice',
          trackId: 't2',
          trackType: 'VIDEO',
          mid: '3',
          track: aliceVideo,
        ),
      ]);

      expect(out.keys, ['part-alice']);
      expect(out['part-alice']!.hasAudio, isTrue);
      expect(out['part-alice']!.hasVideo, isTrue);
    });

    test('both transports produce the SAME shape for the same call', () {
      // The point of §3: the UI cannot tell which transport fed it, so the
      // presentation layer does not need two implementations.
      final viaMesh = meshRemoteMedia(
        streamsByDeviceId: {'device-alice': _Stream([aliceAudio], [aliceVideo])},
        roster: const [
          ParticipantRef(id: 'part-alice', userId: 'alice', runtimeDeviceId: 'device-alice'),
        ],
        selfUserId: 'me',
      );
      final viaSfu = sfuRemoteMedia(bindings: [
        StageRemoteBinding(
          participantId: 'part-alice',
          trackId: 't1',
          trackType: 'AUDIO',
          mid: '2',
          track: aliceAudio,
        ),
        StageRemoteBinding(
          participantId: 'part-alice',
          trackId: 't2',
          trackType: 'VIDEO',
          mid: '3',
          track: aliceVideo,
        ),
      ]);

      expect(viaSfu.keys, viaMesh.keys);
      expect(viaSfu['part-alice']!.hasVideo, viaMesh['part-alice']!.hasVideo);
      expect(viaSfu['part-alice']!.audio!.id, viaMesh['part-alice']!.audio!.id);
    });

    test('video presence follows the TRACK, not a roster hint', () {
      final noVideo = sfuRemoteMedia(bindings: [
        StageRemoteBinding(
          participantId: 'part-alice',
          trackId: 't1',
          trackType: 'AUDIO',
          mid: '2',
          track: aliceAudio,
        ),
      ]);
      expect(noVideo['part-alice']!.hasVideo, isFalse);
      expect(noVideo['part-alice']!.hasAudio, isTrue);
    });
  });
}
