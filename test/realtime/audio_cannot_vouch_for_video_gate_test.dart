import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:aura/features/realtime/data/sfu_realtime_transport.dart';

/// LIVE AUDIO MUST NOT KEEP LIVENESS GREEN WHILE VIDEO IS FROZEN.
///
/// The founder named this as an invariant to machine-enforce, because it is
/// the one that originally failed: the probe summed every `inbound-rtp` report
/// into a single number, a peer's audio kept that number rising while their
/// video was frozen, the stall never armed, and the tile stayed dead for the
/// rest of the call.
///
/// The per-kind probe fixed the behaviour. This guards the SHAPE, because the
/// aggregate did not go away — it still runs alongside, and it still declares
/// a stall of its own. It is harmless only because the per-kind check is
/// consulted first and returns; reverse those two and the original defect is
/// back, with every unit test still green.
void main() {
  final source = File(
    'lib/features/realtime/data/sfu_realtime_transport.dart',
  ).readAsStringSync();

  group('the per-kind check owns the stall decision', () {
    test('it is consulted before any aggregate stall can be declared', () {
      final perKind = source.indexOf('stalledKindAfterTick(');
      // The aggregate's own threshold, further down the same probe.
      final aggregate = source.indexOf('if (_stallTicks >= 6)');

      expect(perKind, greaterThan(-1), reason: 'the per-kind probe is gone');
      expect(aggregate, greaterThan(-1),
          reason: 'this gate is stale — update it if the aggregate was removed');
      expect(perKind, lessThan(aggregate),
          reason: 'an aggregate that decides first can be held up by live '
              'audio while video is frozen — the original defect');
    });

    test('a frozen kind is declared with the kind named', () {
      // A stall that cannot say WHICH kind died cannot have been decided
      // per-kind.
      expect(source, contains('_kind_'));
    });
  });

  group('the invariant itself, behaviourally', () {
    test('climbing audio does not rescue frozen video', () {
      final lastBytes = <String, int>{};
      final stallTicks = <String, int>{};
      stalledKindAfterTick(
        lastBytesByKind: lastBytes,
        stallTicksByKind: stallTicks,
        sample: {'audio': 1000, 'video': 5000},
      );

      String? stalled;
      var aggregatePrevious = 6000;
      var aggregateEverStalled = false;
      for (var i = 1; i <= 6 && stalled == null; i++) {
        final audio = 1000 + i * 5000; // healthy, and rising fast
        const video = 5000; // frozen
        stalled = stalledKindAfterTick(
          lastBytesByKind: lastBytes,
          stallTicksByKind: stallTicks,
          sample: {'audio': audio, 'video': video},
        );
        final total = audio + video;
        if (total <= aggregatePrevious) aggregateEverStalled = true;
        aggregatePrevious = total;
      }

      expect(stalled, 'video');
      expect(aggregateEverStalled, isFalse,
          reason: 'the aggregate saw a perfectly healthy call throughout — '
              'which is precisely why it must not be the decider');
    });
  });
}
