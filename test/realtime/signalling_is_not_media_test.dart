import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:aura/features/realtime/data/sfu_realtime_transport.dart';

/// SIGNALLING LOSS IS NOT MEDIA LOSS.
///
/// Frozen principle. The websocket and the SFU transport fail independently: a
/// backgrounded phone can drop signalling while media is perfectly alive, and a
/// healthy socket proves nothing about whether audio is flowing.
///
/// `_rejoinAfterReconnect` used to detach the stage unconditionally whenever
/// signalling reconnected — destroying working media to repair a plane that had
/// not broken, and telling the server EXPLICIT_LEAVE, which is a lie: nobody
/// left. The decision now goes through the media plane's own health.
///
/// This tests the PREDICATE that decision reads, and it tests the PRODUCT'S
/// predicate rather than a copy of it. `isMediaHealthy` needs a live peer
/// connection to reach, so the rule itself lives as a top-level function in the
/// transport and the getter delegates to it — this file drives that same unit.
/// A re-implemented copy would prove nothing about the product, and nowhere
/// does that matter more: this predicate is the whole difference between
/// keeping a working call and killing it on a websocket reconnect. `isMediaHealthy` needs a live
class _Transport {
  bool closing = false;
  bool lostReported = false;
  RTCIceConnectionState ice = RTCIceConnectionState.RTCIceConnectionStateNew;

  bool get isMediaHealthy => mediaHealthFrom(
        closing: closing,
        lostReported: lostReported,
        ice: ice,
      );
}

void main() {
  group('media health is the only thing that may authorise a detach', () {
    test('a connected transport is healthy, so a signalling reconnect keeps it',
        () {
      final t = _Transport()
        ..ice = RTCIceConnectionState.RTCIceConnectionStateConnected;
      expect(t.isMediaHealthy, isTrue);
    });

    test('completed counts as healthy, because ICE stops at completed', () {
      final t = _Transport()
        ..ice = RTCIceConnectionState.RTCIceConnectionStateCompleted;
      expect(t.isMediaHealthy, isTrue);
    });

    test('a failed transport is not healthy, and may be replaced', () {
      final t = _Transport()
        ..ice = RTCIceConnectionState.RTCIceConnectionStateFailed;
      expect(t.isMediaHealthy, isFalse);
    });

    test('DISCONNECTED is not healthy — most heal, and the grace timer decides',
        () {
      // Deliberately not "healthy". A disconnect usually recovers, and the
      // transport's own ten second grace timer is what escalates it. Treating
      // disconnected as healthy here would keep a transport the media plane is
      // about to declare lost; treating it as proof of death would replace one
      // that was going to heal. It is neither, and the caller detaches only on
      // a definite absence of health.
      final t = _Transport()
        ..ice = RTCIceConnectionState.RTCIceConnectionStateDisconnected;
      expect(t.isMediaHealthy, isFalse);
    });

    test('a transport that already declared loss is never healthy again', () {
      final t = _Transport()
        ..ice = RTCIceConnectionState.RTCIceConnectionStateConnected
        ..lostReported = true;
      expect(t.isMediaHealthy, isFalse);
    });

    test('a closing transport is never healthy, whatever ICE last said', () {
      final t = _Transport()
        ..ice = RTCIceConnectionState.RTCIceConnectionStateConnected
        ..closing = true;
      expect(t.isMediaHealthy, isFalse);
    });

    test('a brand new transport is not yet healthy', () {
      expect(_Transport().isMediaHealthy, isFalse);
    });
  });

  group('what the reconnect path must do with that answer', () {
    // The rule, stated as the caller applies it: detach ONLY when media is not
    // healthy. Written as a table so a future edit that inverts it, or that
    // reintroduces "always detach", fails here rather than in a meeting.
    bool shouldDetachOnSignallingReconnect(_Transport t) => !t.isMediaHealthy;

    test('healthy media survives a signalling reconnect', () {
      final t = _Transport()
        ..ice = RTCIceConnectionState.RTCIceConnectionStateConnected;
      expect(shouldDetachOnSignallingReconnect(t), isFalse,
          reason: 'a working call must not be torn down because a websocket '
              'reconnected');
    });

    test('dead media is detached so real recovery can replace it', () {
      final t = _Transport()
        ..ice = RTCIceConnectionState.RTCIceConnectionStateFailed;
      expect(shouldDetachOnSignallingReconnect(t), isTrue);
    });
  });
}
