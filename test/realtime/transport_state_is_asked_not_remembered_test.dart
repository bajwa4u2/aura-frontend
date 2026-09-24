import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'package:aura/features/realtime/data/sfu_realtime_transport.dart';

/// ASK THE CONNECTION, DO NOT REMEMBER WHAT IT ONCE SAID.
///
/// `onIceConnectionState` is a SINGLE-SLOT callback, and `_waitForIce` borrows
/// that slot for the whole of the connect. ICE normally reaches `connected`
/// while it is borrowed, so by the time the long-lived watcher is re-armed
/// there is nothing left to change — no further event ever arrives, and
/// `_lastIceState` keeps its initial `new` for the rest of the call.
///
/// Measured against production on 2026-09-24, over 45 days:
///
///   * **web reported `transportState = new` in 3,069 quality samples**, while
///     those same participants accumulated up to 84 MB of received video and
///     17,942 decoded frames;
///   * native platforms reported `completed` only because ICE moves from
///     `connected` to `completed` a moment later, AFTER the re-arm. Luck, not
///     design.
///
/// Two costs, and the second is the serious one:
///
///   1. `transportState` was unusable, so C-2 — "reconnect never observed
///      working" — could not have been observed either way. The instrument was
///      the defect.
///   2. `isMediaHealthy` reads the same value and answers true ONLY for
///      `connected` or `completed`. Frozen at `new`, it returned **false for
///      the whole of every web call**, and an unhealthy verdict is what makes
///      a rejoin detach a transport as `MEDIA_UNHEALTHY`.
///
/// The peer connection knows its own state. These hold the rule that it is
/// asked, because the cache still exists for the moments when there is no
/// connection to ask and is one careless edit away from being read again.
void main() {
  final src = File(
    'lib/features/realtime/data/sfu_realtime_transport.dart',
  ).readAsStringSync();

  /// The body of a getter, from its name to the end of its expression.
  String getter(String signature) {
    final start = src.indexOf(signature);
    expect(start, greaterThan(-1), reason: '$signature is gone');
    final end = src.indexOf(';', start);
    return src.substring(start, end);
  }

  group('the live connection is the authority', () {
    test('there is a single place that resolves ICE state', () {
      expect(src, contains('RTCIceConnectionState get _iceState =>'));
      expect(src, contains('_pc?.iceConnectionState ?? _lastIceState'),
          reason: 'the connection must be asked first, the cache only as a '
              'fallback for when there is no connection');
    });

    test('telemetry reads it', () {
      expect(getter('String get mediaPlaneState'), contains('_iceState'));
    });

    test('the health verdict reads it — this is the one that mattered', () {
      final health = getter('bool get isMediaHealthy');
      expect(health, contains('ice: _iceState'));
      expect(health, isNot(contains('ice: _lastIceState')),
          reason: 'a web call that is working perfectly is unhealthy again');
    });

    test('the cache is still written, for when there is nothing to ask', () {
      // Removing the cache entirely would be the opposite mistake: a transport
      // whose peer connection has been torn down still has a last known state
      // worth reporting.
      expect(src, contains('_lastIceState = state'));
    });

    test('the reason is kept where it happened', () {
      expect(src, contains('ASK THE CONNECTION, DO NOT REMEMBER'));
    });
  });

  group('the rule the verdict applies is unchanged', () {
    // `mediaHealthFrom` is pure and public precisely so this can be asserted
    // without a peer connection. The repair changed WHICH value is passed in,
    // never what the function concludes from it.
    test('only connected and completed are healthy', () {
      for (final state in RTCIceConnectionState.values) {
        final healthy = mediaHealthFrom(
          closing: false,
          lostReported: false,
          ice: state,
        );
        final shouldBeHealthy =
            state == RTCIceConnectionState.RTCIceConnectionStateConnected ||
                state == RTCIceConnectionState.RTCIceConnectionStateCompleted;
        expect(healthy, shouldBeHealthy, reason: '$state');
      }
    });

    test('a NEW connection is not healthy — which is why the freeze bit', () {
      expect(
        mediaHealthFrom(
          closing: false,
          lostReported: false,
          ice: RTCIceConnectionState.RTCIceConnectionStateNew,
        ),
        isFalse,
      );
    });

    test('closing and a reported loss still override a good ICE state', () {
      expect(
        mediaHealthFrom(
          closing: true,
          lostReported: false,
          ice: RTCIceConnectionState.RTCIceConnectionStateConnected,
        ),
        isFalse,
      );
      expect(
        mediaHealthFrom(
          closing: false,
          lostReported: true,
          ice: RTCIceConnectionState.RTCIceConnectionStateConnected,
        ),
        isFalse,
      );
    });
  });
}
