import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'package:aura/features/realtime/domain/remote_media_presentation.dart';

/// "Audio one way only, no video" on a call where nothing had failed.
///
/// Founder-observed 2026-08-28. Cloudflare returned valid bindings for both
/// remote tracks, the client bound both to real receiving transceivers
/// (`bound=2 noMid=0 noLine=0 dirUnreadable=0 noTrack=0`), the roster read
/// "Media on" — and the conversation call stage drew a single tile.
///
/// The stage was iterating the DEVICE-keyed renderer map. That map is written
/// only by the mesh per-peer callbacks, so under SFU it is empty for the whole
/// call and the surface was structurally blind to the transport that was
/// actually carrying the media.
///
/// These tests pin the ordering rule, not the incident.
void main() {
  final canonical = RTCVideoRenderer();
  final mesh = RTCVideoRenderer();

  group('rendererForParticipant asks identity before device', () {
    test('finds STAGE media, which has no device key at all', () {
      // The SFU case. `byDevice` is empty and always will be.
      expect(
        rendererForParticipant(
          participant: const ParticipantRef(
            id: 'p1',
            userId: 'zakria',
            runtimeDeviceId: null,
          ),
          byParticipant: {'p1': canonical},
          byDevice: const {},
        ),
        same(canonical),
        reason: 'a device-shaped lookup cannot find stage media',
      );
    });

    test('finds MESH media through the participant device key', () {
      expect(
        rendererForParticipant(
          participant: const ParticipantRef(
            id: 'p1',
            userId: 'zakria',
            runtimeDeviceId: 'socket:abc',
          ),
          byParticipant: const {},
          byDevice: {'socket:abc': mesh},
        ),
        same(mesh),
      );
    });

    test('canonical wins when both exist', () {
      // Not a preference — an ordering. During a mesh→stage transition both
      // maps can be briefly populated for the same person, and the device
      // entry is the one being retired.
      expect(
        rendererForParticipant(
          participant: const ParticipantRef(
            id: 'p1',
            userId: 'zakria',
            runtimeDeviceId: 'socket:abc',
          ),
          byParticipant: {'p1': canonical},
          byDevice: {'socket:abc': mesh},
        ),
        same(canonical),
      );
    });

    test('no media is null, never another participant\'s renderer', () {
      expect(
        rendererForParticipant(
          participant: const ParticipantRef(
            id: 'p2',
            userId: 'bajwa',
            runtimeDeviceId: '   ',
          ),
          byParticipant: {'p1': canonical},
          byDevice: {'socket:abc': mesh},
        ),
        isNull,
      );
    });
  });
}
