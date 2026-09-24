import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:aura/features/realtime/data/sfu_realtime_transport.dart';

/// C-10 — A CAMERA GOING OFF IS NOT A DEAD TRANSPORT.
///
/// The liveness probe detects a per-kind stall, and it must: that is the
/// 2026-09-08 repair for frozen video under healthy audio, the failure people
/// actually report as *"I can't see you, you can see me"*. Detection is kept
/// exactly as it was.
///
/// The RESPONSE was the defect. Any single stalled kind called `_declareLost`,
/// which latches `_lostReported`, makes `isMediaHealthy` false for the rest of
/// the transport's life, cancels the liveness probe, and gets the transport
/// detached as `MEDIA_UNHEALTHY` on a later rejoin.
///
/// So a participant turning their camera off — an ordinary, deliberate act
/// that stops video bytes — permanently condemned a call whose audio was
/// flowing perfectly. Eighteen seconds after somebody pressed a button, the
/// call was marked unrecoverable.
///
/// The distinction now drawn: **one kind stopping is a publisher's decision;
/// every kind stopping is a transport failure.** Only the second is loss. A
/// single stalled kind is repaired where it broke, by the same rebuild that
/// restores a lost audio receiver.
void main() {
  group('the loss rule', () {
    test('THE DEFECT: video stalls, audio flows — NOT lost', () {
      expect(
        transportLostFromStalls(
          lastBytesByKind: {'audio': 500000, 'video': 2000000},
          stallTicksByKind: {'audio': 0, 'video': 9},
        ),
        isFalse,
        reason: 'this is a camera being turned off, and it condemned the call',
      );
    });

    test('audio stalls while video flows — also not lost', () {
      // Symmetry matters: a muted-then-stopped microphone is a decision too.
      expect(
        transportLostFromStalls(
          lastBytesByKind: {'audio': 500000, 'video': 2000000},
          stallTicksByKind: {'audio': 9, 'video': 0},
        ),
        isFalse,
      );
    });

    test('EVERYTHING that was flowing has stopped — lost', () {
      expect(
        transportLostFromStalls(
          lastBytesByKind: {'audio': 500000, 'video': 2000000},
          stallTicksByKind: {'audio': 6, 'video': 6},
        ),
        isTrue,
      );
    });

    test('an audio-only call is lost when its only kind stops', () {
      expect(
        transportLostFromStalls(
          lastBytesByKind: {'audio': 500000},
          stallTicksByKind: {'audio': 6},
        ),
        isTrue,
      );
    });

    test('a video-only call is lost when its only kind stops', () {
      expect(
        transportLostFromStalls(
          lastBytesByKind: {'video': 2000000},
          stallTicksByKind: {'video': 6},
        ),
        isTrue,
      );
    });

    test('a kind that NEVER delivered cannot hold the verdict open', () {
      // A call that never carried video must not be waiting forever on video
      // to stall before it can admit the transport is gone.
      expect(
        transportLostFromStalls(
          lastBytesByKind: {'audio': 500000, 'video': 0},
          stallTicksByKind: {'audio': 6, 'video': 0},
        ),
        isTrue,
      );
    });

    test('nothing ever arrived — nothing has stopped', () {
      expect(
        transportLostFromStalls(lastBytesByKind: {}, stallTicksByKind: {}),
        isFalse,
      );
      expect(
        transportLostFromStalls(
          lastBytesByKind: {'audio': 0, 'video': 0},
          stallTicksByKind: {'audio': 9, 'video': 9},
        ),
        isFalse,
        reason: 'arming is the probe\'s job, not this rule\'s',
      );
    });

    test('just short of the threshold is not yet lost', () {
      expect(
        transportLostFromStalls(
          lastBytesByKind: {'audio': 1, 'video': 1},
          stallTicksByKind: {'audio': 6, 'video': 5},
        ),
        isFalse,
      );
    });
  });

  group('detection is unchanged — the 09-08 repair survives', () {
    test('a frozen video under healthy audio is still named', () {
      final lastBytes = <String, int>{};
      final stallTicks = <String, int>{};
      String? stalled;
      // Audio keeps rising; video is frozen at the same byte count.
      //
      // Seven ticks, not six: the FIRST tick arms the baseline (video rises
      // from the -1 sentinel to 5000), so six stall ticks only begin on the
      // second. Off by one here would assert the detector is broken when it
      // is merely still counting.
      for (var i = 1; i <= 7; i++) {
        stalled = stalledKindAfterTick(
          lastBytesByKind: lastBytes,
          stallTicksByKind: stallTicks,
          sample: {'audio': 1000 * i, 'video': 5000},
        );
      }
      expect(stalled, 'video',
          reason: 'the per-kind stall detector must keep working; only the '
              'response to it changed');
    });
  });

  group('the wiring', () {
    final src = File(
      'lib/features/realtime/data/sfu_realtime_transport.dart',
    ).readAsStringSync();

    final probe = src.substring(
      src.indexOf('final stalled = stalledKindAfterTick('),
      src.indexOf('_ticks += 1;'),
    );

    test('a single stalled kind no longer declares the transport lost', () {
      expect(probe, isNot(contains("_declareLost('media_stalled_'")),
          reason: 'the unconditional teardown is the defect');
      expect(probe, contains('transportLostFromStalls('));
    });

    test('loss is still declared when everything has stopped', () {
      expect(probe, contains("_declareLost('media_stalled_\${seconds}s_all_kinds')"));
    });

    test('a single stalled kind is repaired instead', () {
      expect(probe, contains('_rebuildReceiversForKind('));
      expect(probe, contains("reason: 'stalled_\${seconds}s'"));
    });
  });
}
