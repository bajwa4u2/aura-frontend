import 'package:flutter_test/flutter_test.dart';
import 'package:aura/features/realtime/data/sfu_realtime_transport.dart';

/// A LIVE AUDIO STREAM MUST NOT VOUCH FOR A DEAD VIDEO STREAM.
///
/// The liveness probe summed every `inbound-rtp` report into a single byte
/// count. In a two-party call that total carries the peer's audio AND their
/// video, so when their video froze while their audio kept flowing, the total
/// kept rising, the stall never armed, loss was never declared, and no
/// recovery ran. The tile stayed frozen for the rest of the call.
///
/// That is not a corner case — it is the failure users actually report:
/// "I can't see you, you can see me"; a tile reading "Camera off" while the
/// server holds the track ACTIVE; remotes frozen while the conversation
/// continues. Audio was healthy in every one of them, which is exactly why
/// nothing fired.
///
/// Observed live on 2026-09-08 during a two-endpoint certification meeting.
void main() {
  /// Run n ticks of the same sample and return the kind reported stalled.
  String? runTicks({
    required Map<String, int> lastBytes,
    required Map<String, int> stallTicks,
    required List<Map<String, int>> samples,
  }) {
    String? last;
    for (final sample in samples) {
      last = stalledKindAfterTick(
        lastBytesByKind: lastBytes,
        stallTicksByKind: stallTicks,
        sample: sample,
      );
      if (last != null) return last;
    }
    return last;
  }

  group('frozen video with healthy audio', () {
    test('is detected, and names video as the stalled kind', () {
      final lastBytes = <String, int>{};
      final stallTicks = <String, int>{};

      // Both kinds flow and arm.
      stalledKindAfterTick(
        lastBytesByKind: lastBytes,
        stallTicksByKind: stallTicks,
        sample: {'audio': 1000, 'video': 5000},
      );

      // Video freezes. Audio keeps climbing — which is what used to mask it.
      final stalled = runTicks(
        lastBytes: lastBytes,
        stallTicks: stallTicks,
        samples: [
          for (var i = 1; i <= 6; i++) {'audio': 1000 + i * 500, 'video': 5000},
        ],
      );

      expect(stalled, 'video');
    });

    test('the aggregate it replaced would have seen nothing wrong', () {
      // The old probe's view: one number, still rising every tick.
      var previousTotal = 6000;
      var everStalled = false;
      for (var i = 1; i <= 6; i++) {
        final total = (1000 + i * 500) + 5000; // audio climbing, video frozen
        if (total <= previousTotal) everStalled = true;
        previousTotal = total;
      }
      expect(everStalled, isFalse,
          reason: 'the aggregate never stops rising, which is the defect');
    });

    test('audio is reported when it is audio that dies', () {
      final lastBytes = <String, int>{};
      final stallTicks = <String, int>{};
      stalledKindAfterTick(
        lastBytesByKind: lastBytes,
        stallTicksByKind: stallTicks,
        sample: {'audio': 1000, 'video': 5000},
      );
      final stalled = runTicks(
        lastBytes: lastBytes,
        stallTicks: stallTicks,
        samples: [
          for (var i = 1; i <= 6; i++) {'audio': 1000, 'video': 5000 + i * 900},
        ],
      );
      expect(stalled, 'audio');
    });
  });

  group('a kind that never delivered cannot arm', () {
    test('an audio-only call is never torn down for having no picture', () {
      final lastBytes = <String, int>{};
      final stallTicks = <String, int>{};
      // Video is present in stats but has never carried a byte.
      final stalled = runTicks(
        lastBytes: lastBytes,
        stallTicks: stallTicks,
        samples: [
          for (var i = 1; i <= 40; i++) {'audio': i * 500, 'video': 0},
        ],
      );
      expect(stalled, isNull);
    });

    test('a call where nothing ever arrives never arms at all', () {
      final lastBytes = <String, int>{};
      final stallTicks = <String, int>{};
      final stalled = runTicks(
        lastBytes: lastBytes,
        stallTicks: stallTicks,
        samples: [
          for (var i = 1; i <= 40; i++) {'audio': 0, 'video': 0},
        ],
      );
      expect(stalled, isNull,
          reason: 'a quiet call is not a broken call');
    });
  });

  group('recovery resets the arming state', () {
    test('a kind that resumes before the threshold does not fire', () {
      final lastBytes = <String, int>{};
      final stallTicks = <String, int>{};
      stalledKindAfterTick(
        lastBytesByKind: lastBytes,
        stallTicksByKind: stallTicks,
        sample: {'audio': 100, 'video': 100},
      );
      // Five frozen ticks — one short of the threshold.
      for (var i = 0; i < 5; i++) {
        expect(
          stalledKindAfterTick(
            lastBytesByKind: lastBytes,
            stallTicksByKind: stallTicks,
            sample: {'audio': 100 + i, 'video': 100},
          ),
          isNull,
        );
      }
      // Then video resumes.
      stalledKindAfterTick(
        lastBytesByKind: lastBytes,
        stallTicksByKind: stallTicks,
        sample: {'audio': 200, 'video': 900},
      );
      expect(stallTicks['video'], 0);

      // A brief stutter must not leave the call one tick from teardown.
      final again = runTicks(
        lastBytes: lastBytes,
        stallTicks: stallTicks,
        samples: [
          for (var i = 1; i <= 5; i++) {'audio': 200 + i, 'video': 900},
        ],
      );
      expect(again, isNull);
    });
  });

  group('the threshold is real time, not ticks', () {
    test('six ticks at three seconds is eighteen seconds of dead media', () {
      final lastBytes = <String, int>{};
      final stallTicks = <String, int>{};
      stalledKindAfterTick(
        lastBytesByKind: lastBytes,
        stallTicksByKind: stallTicks,
        sample: {'video': 10},
      );
      String? fired;
      var ticks = 0;
      while (fired == null && ticks < 20) {
        ticks++;
        fired = stalledKindAfterTick(
          lastBytesByKind: lastBytes,
          stallTicksByKind: stallTicks,
          sample: {'video': 10},
        );
      }
      expect(fired, 'video');
      expect(ticks, 6, reason: '6 ticks x 3s = 18s, the documented threshold');
    });
  });
}
