import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:aura/features/realtime/application/single_flight.dart';

/// THE RACE THAT DESTROYED FIVE HEALTHY TRANSPORTS.
///
/// Production, 2026-09-07. `_ensureStageConnected` tested `_stage == null`,
/// then awaited a server round trip and a full SDP negotiation before `_stage`
/// was set. Nine call sites reach that path, several unawaited, so a second
/// trigger passed the same test and opened a second transport. The server then
/// retired the first — closing the provider session the PEER was subscribed to,
/// which is what produced 410 Gone and bytes=0.
///
/// These assert HOW MANY operations ran, not merely that nothing threw.
/// "Nothing threw" was true throughout the outage.
void main() {
  group('single flight', () {
    test('TWO CONCURRENT CALLERS PRODUCE ONE OPERATION', () async {
      final gate = SingleFlight();
      var runs = 0;
      final release = Completer<void>();

      Future<void> op() async {
        runs += 1;
        await release.future;
      }

      final a = gate.run(op);
      final b = gate.run(op); // arrives mid-flight, exactly as the triggers did
      release.complete();
      await Future.wait<void>([a, b]);

      expect(runs, 1);
    });

    test('a joiner waits for the real operation rather than returning early', () async {
      final gate = SingleFlight();
      var finished = false;
      final release = Completer<void>();

      final a = gate.run(() async {
        await release.future;
        finished = true;
      });
      final b = gate.run(() async {});

      var joinerDone = false;
      unawaited(b.then((_) => joinerDone = true));
      await Future<void>.delayed(Duration.zero);
      expect(joinerDone, isFalse, reason: 'the joiner must not finish first');

      release.complete();
      await Future.wait<void>([a, b]);
      expect(finished, isTrue);
      expect(joinerDone, isTrue);
    });

    test('reports the join, so a race is observable rather than silent', () async {
      final gate = SingleFlight();
      var joins = 0;
      final release = Completer<void>();

      final Future<void> a = gate.run(() => release.future);
      final Future<void> b = gate.run(() async {}, onJoin: () => joins += 1);
      final Future<void> c = gate.run(() async {}, onJoin: () => joins += 1);
      release.complete();
      await Future.wait<void>([a, b, c]);

      expect(joins, 2);
    });

    test('RELEASES after success, so the next legitimate attempt can run', () async {
      final gate = SingleFlight();
      var runs = 0;
      await gate.run(() async => runs += 1);
      expect(gate.isRunning, isFalse);
      await gate.run(() async => runs += 1);
      expect(runs, 2);
    });

    test('RELEASES after failure — a failed attempt must not wedge the boundary', () async {
      // A gate that never reopens would turn one bad attempt into a call that
      // can never connect again, which is worse than the churn it replaced.
      final gate = SingleFlight();
      await expectLater(
        gate.run(() async => throw StateError('boom')),
        throwsA(isA<StateError>()),
      );
      expect(gate.isRunning, isFalse);

      var ran = false;
      await gate.run(() async => ran = true);
      expect(ran, isTrue);
    });

    test('a joiner does not inherit the leader failure as its own', () async {
      // The failure is reported once, by the caller that actually attempted it.
      // A joiner reporting the same failure again would double-count churn in
      // exactly the traces we rely on to measure it.
      final gate = SingleFlight();
      final release = Completer<void>();
      final leader = gate.run(() async {
        await release.future;
        throw StateError('boom');
      });
      final joiner = gate.run(() async {});

      release.complete();
      await expectLater(leader, throwsA(isA<StateError>()));
      await expectLater(joiner, completes);
    });

    test('a late caller after completion starts a NEW operation, not a ghost', () async {
      final gate = SingleFlight();
      final order = <String>[];
      await gate.run(() async => order.add('first'));
      await gate.run(() async => order.add('second'));
      expect(order, ['first', 'second']);
    });

    test('many overlapping triggers still produce one operation', () async {
      // The shape of the real defect: hydrate, join, resume, media-ready,
      // participant.joined, media.published, track-change all arriving while
      // the first attempt is still negotiating.
      final gate = SingleFlight();
      var runs = 0;
      final release = Completer<void>();
      final futures = <Future<void>>[];

      futures.add(gate.run(() async {
        runs += 1;
        await release.future;
      }));
      for (var i = 0; i < 8; i++) {
        futures.add(gate.run(() async => runs += 1));
      }
      release.complete();
      await Future.wait(futures);

      expect(runs, 1);
    });
  });
}
