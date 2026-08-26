import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'package:aura/features/realtime/data/stage_remote_binding.dart';

/// The rule that keeps a tile from lying about whose face is in it.
class _FakeTrack implements MediaStreamTrack {
  _FakeTrack(this._id, this._kind);
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
  final aliceAudio = _FakeTrack('alice-a', 'audio');
  final aliceVideo = _FakeTrack('alice-v', 'video');
  final myOwnAudio = _FakeTrack('mine-a', 'audio');

  group('remote binding is decided by DIRECTION, not by having a track', () {
    test('binds receiving m-lines to the right participant', () {
      final out = resolveRemoteBindings(
        lines: [
          StageReceivingLine(
            mid: '2',
            direction: TransceiverDirection.RecvOnly,
            receiverTrack: aliceAudio,
          ),
          StageReceivingLine(
            mid: '3',
            direction: TransceiverDirection.RecvOnly,
            receiverTrack: aliceVideo,
          ),
        ],
        serverBindings: [
          {'trackId': 't1', 'participantId': 'alice', 'trackType': 'AUDIO', 'mid': '2'},
          {'trackId': 't2', 'participantId': 'alice', 'trackType': 'VIDEO', 'mid': '3'},
        ],
      );

      expect(out, hasLength(2));
      expect(out.first.participantId, 'alice');
      expect(out.first.track.id, 'alice-a');
      expect(out.last.track.id, 'alice-v');
    });

    test('NEVER binds a send-only line, even though it has a receiver track',
        () {
      // THE MEASURED TRAP. On Windows and Android the send-only m-lines
      // carrying this participant's OWN microphone and camera still reported
      // a non-null receiver track (mid 0 recvKind=audio, mid 1 recvKind=video).
      // Selecting on "has a receiver track" would bind the local speaker into
      // a remote tile, and every participant would appear to be themselves.
      final out = resolveRemoteBindings(
        lines: [
          StageReceivingLine(
            mid: '0',
            direction: TransceiverDirection.SendOnly,
            receiverTrack: myOwnAudio,
          ),
        ],
        serverBindings: [
          {'trackId': 't1', 'participantId': 'alice', 'trackType': 'AUDIO', 'mid': '0'},
        ],
      );

      expect(out, isEmpty);
    });

    test('an unreadable direction is not treated as receiving', () {
      // getCurrentDirection throws on some platforms. Unknown must fail
      // closed, or the trap above reopens through the error path.
      final out = resolveRemoteBindings(
        lines: [
          StageReceivingLine(mid: '2', direction: null, receiverTrack: aliceAudio),
        ],
        serverBindings: [
          {'trackId': 't1', 'participantId': 'alice', 'trackType': 'AUDIO', 'mid': '2'},
        ],
      );
      expect(out, isEmpty);
    });

    test('a binding with no m-line is skipped rather than guessed', () {
      final out = resolveRemoteBindings(
        lines: [
          StageReceivingLine(
            mid: '2',
            direction: TransceiverDirection.RecvOnly,
            receiverTrack: aliceAudio,
          ),
        ],
        serverBindings: [
          {'trackId': 't1', 'participantId': 'alice', 'trackType': 'AUDIO', 'mid': null},
        ],
      );
      expect(out, isEmpty);
    });

    test('binds nothing for an m-line that is negotiated but not yet receiving',
        () {
      final out = resolveRemoteBindings(
        lines: [
          StageReceivingLine(
            mid: '2',
            direction: TransceiverDirection.RecvOnly,
            receiverTrack: null,
          ),
        ],
        serverBindings: [
          {'trackId': 't1', 'participantId': 'alice', 'trackType': 'AUDIO', 'mid': '2'},
        ],
      );
      expect(out, isEmpty);
    });
  });
}
