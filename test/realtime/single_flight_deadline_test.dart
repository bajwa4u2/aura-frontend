import 'dart:async';

import 'package:aura/features/realtime/application/single_flight.dart';
import 'package:flutter_test/flutter_test.dart';

/// 2026-09-30: a browser's first stage connect stalled, and eight later
/// attempts joined it, so the call could never recover. A deadline releases
/// the gate so the next attempt starts fresh.
void main() {
  test('a stalled operation releases the gate at its deadline', () async {
    final gate = SingleFlight();
    final never = Completer<void>();
    var joins = 0;

    final first = gate.run(() => never.future,
        onJoin: () => joins++, deadline: const Duration(milliseconds: 50));
    await gate.run(() async {}, onJoin: () => joins++); // joins the stalled one
    expect(joins, 1);

    await expectLater(first, throwsA(isA<TimeoutException>()));
    expect(gate.isRunning, isFalse);

    var ranFresh = false;
    await gate.run(() async => ranFresh = true);
    expect(ranFresh, isTrue);
  });

  test('without a deadline, behaviour is unchanged', () async {
    final gate = SingleFlight();
    var runs = 0;
    final a = gate.run(() async {
      runs++;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    });
    final b = gate.run(() async => runs++);
    await Future.wait([a, b]);
    expect(runs, 1);
  });

  test('a fast operation is not affected by its deadline', () async {
    final gate = SingleFlight();
    var done = false;
    await gate.run(() async => done = true, deadline: const Duration(seconds: 20));
    expect(done, isTrue);
  });
}
