import 'package:flutter_test/flutter_test.dart';

import 'package:aura/features/realtime/data/realtime_media_service.dart';

/// The one-way-media defect, found live on 2026-08-21.
///
/// A meeting ran for eleven minutes with the host tile showing "Camera off"
/// while the other side saw the host perfectly. The transport was healthy —
/// ICE reached Connected — and the roster was correct on both sides. What was
/// missing was any track at all: `onTrack` never fired once, and the receiving
/// page held exactly two media elements, both its own muted local preview.
///
/// Cause: `handleRemoteOffer` attaches local tracks AFTER setRemoteDescription
/// and does it exactly once, guarded by `isNewPeer`. When the offer arrived
/// while getUserMedia was still in flight, `_localStream` was null, nothing was
/// attached, and `createAnswer` produced recvonly m-lines. The connection then
/// sat Connected and permanently silent — and nothing could recover it, because
/// `setCameraEnabled` only flips `enabled` on tracks that already exist and
/// `replaceTrack` needs a sender to replace. Toggling the camera did nothing,
/// which is exactly what the founder observed.
///
/// Rejoining fixed it, which confirmed the race: the rebuilt peer was created
/// when media already existed.
///
/// SCOPE OF THIS FILE, stated plainly: it pins the SELECTION RULE that decides
/// which kinds a silent peer must be given. It does not exercise
/// RTCPeerConnection, SDP, or renegotiation — those need a live WebRTC stack
/// and are covered by the in-product verification, not here.
void main() {
  group('which kinds a silent peer must be given', () {
    test('a peer that answered with nothing gets everything', () {
      // The exact production case: zero senders, local stream has both kinds.
      expect(
        missingSenderKinds(
          presentKinds: const <String>{},
          localKinds: const ['audio', 'video'],
        ),
        {'audio', 'video'},
      );
    });

    test('a peer that already sends both is left alone', () {
      // Guards the other direction: re-adding creates a duplicate m-line and a
      // pointless renegotiation on every join.
      expect(
        missingSenderKinds(
          presentKinds: const {'audio', 'video'},
          localKinds: const ['audio', 'video'],
        ),
        isEmpty,
      );
    });

    test('an audio-only peer is given just the missing video', () {
      // Camera busy in another browser at join, released later — audio was
      // published, video was not.
      expect(
        missingSenderKinds(
          presentKinds: const {'audio'},
          localKinds: const ['audio', 'video'],
        ),
        {'video'},
      );
    });

    test('a kind already present counts even if it is a DIFFERENT track', () {
      // Compared by kind, never by identity. A screen share standing in for the
      // camera, or a switched device, still satisfies "video".
      expect(
        missingSenderKinds(
          presentKinds: const {'video'},
          localKinds: const ['video'],
        ),
        isEmpty,
      );
    });

    test('empty kinds are never added', () {
      // `track.kind` is nullable and coerced to ''. Adding a transceiver for an
      // unnamed kind would renegotiate for nothing.
      expect(
        missingSenderKinds(
          presentKinds: const <String>{},
          localKinds: const ['', 'audio', ''],
        ),
        {'audio'},
      );
    });

    test('duplicate local kinds collapse to one addition', () {
      // Two video tracks on the local stream must not produce two senders.
      expect(
        missingSenderKinds(
          presentKinds: const <String>{},
          localKinds: const ['video', 'video'],
        ),
        {'video'},
      );
    });

    test('no local media means nothing to add', () {
      expect(
        missingSenderKinds(
          presentKinds: const {'audio'},
          localKinds: const <String>[],
        ),
        isEmpty,
      );
    });
  });
}
