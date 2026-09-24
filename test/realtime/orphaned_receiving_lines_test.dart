import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:aura/features/realtime/data/sfu_realtime_transport.dart';

/// M-2 — A PEER'S RELOAD MUST NOT LEAVE DEAD RECEIVING LINES BEHIND.
///
/// Measured live, 2026-09-24, two people on web refreshing in turn:
///
///     you refresh   → you  bind_complete (receiving=2 bound=2)
///                     her  BIND_PARTIAL  (receiving=4 bound=2)
///     she refreshes → her  bind_complete
///                     you  BIND_PARTIAL
///
/// Seven refreshes, a perfect see-saw: after the first one the two of them
/// were never both whole again. When somebody reloads, their old stage
/// transport dies and a new one publishes new track ids; the other side's
/// subscription to the dead ids is retired at the provider, but the `recvonly`
/// m-line stays on the peer connection carrying nothing. WebRTC cannot delete
/// an m-line — only `stop()` it, which frees the slot for recycling. Nothing
/// stopped them, so they accumulated: 2026-08-28 saw `receiving=12 bound=2`.
///
/// The rule below decides which lines a retirement frees. It is pure because
/// the cost of getting it wrong is somebody's own camera leaving the call.
void main() {
  group('which m-lines a retirement frees', () {
    test('a retired track frees the line it was bound to', () {
      final mids = retiredReceiverMids(
        retiredTrackIds: ['track-a', 'track-b'],
        midByTrackId: {'track-a': '2', 'track-b': '3', 'track-live': '4'},
      );
      expect(mids, {'2', '3'});
    });

    test('a track we never bound frees nothing', () {
      // No binding was recorded, so we cannot know which line was its own —
      // and guessing here is how a sender gets stopped.
      final mids = retiredReceiverMids(
        retiredTrackIds: ['never-seen'],
        midByTrackId: {'track-a': '2'},
      );
      expect(mids, isEmpty);
    });

    test('a still-live track keeps its line', () {
      final mids = retiredReceiverMids(
        retiredTrackIds: ['track-a'],
        midByTrackId: {'track-a': '2', 'track-live': '3'},
      );
      expect(mids, isNot(contains('3')));
    });

    test('an empty mid is not a line', () {
      final mids = retiredReceiverMids(
        retiredTrackIds: ['track-a'],
        midByTrackId: {'track-a': ''},
      );
      expect(mids, isEmpty);
    });

    test('the see-saw, as it actually happened', () {
      // Her connection after your reload: two live lines from your new
      // generation, two dead ones from the generation that went away.
      final midByTrackId = <String, String>{
        'your-old-audio': '0',
        'your-old-video': '1',
        'your-new-audio': '2',
        'your-new-video': '3',
      };
      final freed = retiredReceiverMids(
        retiredTrackIds: ['your-old-audio', 'your-old-video'],
        midByTrackId: midByTrackId,
      );
      expect(freed, {'0', '1'},
          reason: 'these are the two lines that made her bind read PARTIAL');
      expect(freed, isNot(contains('2')));
      expect(freed, isNot(contains('3')));
    });
  });

  group('the transport applies the rule safely', () {
    final source = File(
      'lib/features/realtime/data/sfu_realtime_transport.dart',
    ).readAsStringSync();

    test('a line carrying a local sender is never stopped', () {
      expect(source, contains('if (t.sender.track != null) continue;'),
          reason: 'stopping a sender would take our own mic or camera '
              'off the wire — the one mistake this must not make');
    });

    test('retirement stops the freed lines and says how many', () {
      expect(source, contains('_stopReceiversFor(pc, stale)'));
      expect(source, contains('stoppedLines=\$stopped'));
    });

    test('stopping is attempted, and a platform without it still runs', () {
      final start = source.indexOf('Future<int> _stopReceiversFor(');
      expect(start, greaterThan(-1));
      final body = source.substring(start, source.indexOf('return stopped;', start));
      expect(body, contains('await t.stop()'));
      expect(body, contains('catch (_)'),
          reason: 'a missing transceiver.stop() is a missed improvement, '
              'never a failed call');
    });

    test('a binding records the mid it landed on', () {
      expect(source, contains('_midByTrackId[trackId] = mid;'),
          reason: 'without this there is no way to know which line belonged '
              'to the track that went away');
    });
  });
}
