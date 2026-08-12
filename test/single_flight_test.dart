import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:aura/core/concurrency/single_flight.dart';

void main() {
  group('SingleFlight — realtime transport ownership repair', () {
    // 2026-08-14 — this is the exact concurrency property whose absence
    // caused the proven Thread-call transport defect: two independent
    // "is something already happening?" guards using different signals
    // let two callers each start a competing socket connect/disconnect
    // cycle, each tearing down the other's in-progress connection. A
    // SingleFlight closes this by construction — there is exactly one
    // Completer per in-flight operation, and every caller shares it.
    test('two concurrent callers share one in-flight operation, not two', () async {
      final flight = SingleFlight<int>();
      var startedCount = 0;
      final release = Completer<void>();

      Future<int> operation() async {
        startedCount++;
        await release.future;
        return 42;
      }

      final first = flight.run(operation);
      final second = flight.run(operation);

      // Give both calls a chance to synchronously reach `run` before
      // either operation is allowed to complete.
      await Future<void>.delayed(Duration.zero);
      expect(startedCount, 1, reason: 'operation must start exactly once for two concurrent callers');
      expect(flight.isInFlight, isTrue);

      release.complete();
      final results = await Future.wait([first, second]);

      expect(results, [42, 42]);
      expect(flight.isInFlight, isFalse);
    });

    test('a caller arriving after completion starts a genuinely new operation', () async {
      final flight = SingleFlight<int>();
      var startedCount = 0;

      Future<int> operation() async {
        startedCount++;
        return startedCount;
      }

      final firstResult = await flight.run(operation);
      final secondResult = await flight.run(operation);

      expect(firstResult, 1);
      expect(secondResult, 2);
      expect(startedCount, 2);
    });

    test('a failing operation propagates its error to every waiter, then frees the slot', () async {
      final flight = SingleFlight<int>();
      var attempt = 0;

      Future<int> operation() async {
        attempt++;
        if (attempt == 1) {
          throw StateError('transient failure');
        }
        return 7;
      }

      final first = flight.run(operation);
      final second = flight.run(operation);

      await expectLater(first, throwsA(isA<StateError>()));
      await expectLater(second, throwsA(isA<StateError>()));
      expect(flight.isInFlight, isFalse);

      // The slot is free again — a subsequent call is a fresh attempt.
      final result = await flight.run(operation);
      expect(result, 7);
    });

    test('abort() releases waiters with an error without waiting for the operation to settle', () async {
      final flight = SingleFlight<int>();
      final neverCompletes = Completer<int>();

      final waiter = flight.run(() => neverCompletes.future);

      flight.abort(StateError('torn down'));

      await expectLater(waiter, throwsA(isA<StateError>()));
      expect(flight.isInFlight, isFalse);

      // A new run() after abort() starts a genuinely fresh operation,
      // proving the abandoned (never-settling) operation from before does
      // not keep controlling the slot.
      var freshStarted = false;
      final fresh = flight.run(() async {
        freshStarted = true;
        return 99;
      });
      expect(await fresh, 99);
      expect(freshStarted, isTrue);
    });

    test('three back-to-back concurrent callers never start three operations', () async {
      // Mirrors the proven defect shape: multiple logical retry attempts
      // each independently trying to (re)establish transport. With a
      // SingleFlight, no matter how many callers pile on before the first
      // operation settles, only one operation instance actually runs.
      final flight = SingleFlight<String>();
      var starts = 0;
      final release = Completer<void>();

      Future<String> operation() async {
        starts++;
        await release.future;
        return 'connected';
      }

      final futures = [
        flight.run(operation),
        flight.run(operation),
        flight.run(operation),
      ];

      await Future<void>.delayed(Duration.zero);
      expect(starts, 1);

      release.complete();
      final results = await Future.wait(futures);
      expect(results, ['connected', 'connected', 'connected']);
    });
  });
}
