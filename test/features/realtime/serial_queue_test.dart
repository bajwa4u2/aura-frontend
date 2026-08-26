import 'package:flutter_test/flutter_test.dart';

import 'package:aura/features/realtime/data/serial_queue.dart';

/// The two properties the stage transport depends on.
void main() {
  test('operations never overlap and keep submission order', () async {
    final queue = SerialQueue();
    final events = <String>[];
    var active = 0;

    Future<void> op(String name, int ms) => queue.run(() async {
          active++;
          expect(active, 1, reason: '$name overlapped another operation');
          events.add('start:$name');
          await Future<void>.delayed(Duration(milliseconds: ms));
          events.add('end:$name');
          active--;
        });

    // Submitted together, exactly as the product's four triggers can fire.
    await Future.wait([op('a', 30), op('b', 5), op('c', 1)]);

    expect(events, [
      'start:a', 'end:a',
      'start:b', 'end:b',
      'start:c', 'end:c',
    ]);
  });

  test('a failure surfaces to its caller and does NOT wedge the queue', () async {
    // The property that matters. Chaining naively onto the previous future
    // poisons every continuation after a rejection, which would silently
    // disable the transport for the rest of the call after one refusal.
    final queue = SerialQueue();

    final failed = queue.run<int>(() async => throw StateError('boom'));
    final after = queue.run<int>(() async => 42);

    await expectLater(failed, throwsA(isA<StateError>()));
    expect(await after, 42, reason: 'the queue wedged after one failure');

    // ...and it keeps working indefinitely afterwards.
    expect(await queue.run<int>(() async => 7), 7);
  });

  test('closing drops queued work rather than mutating a dead session', () async {
    final queue = SerialQueue();
    var ran = false;

    final blocker = queue.run(() async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    // Let the blocker actually START. Without this it is still only QUEUED
    // when close() lands, so it is correctly dropped too — which is right
    // behaviour and a wrong test.
    await Future<void>.delayed(Duration.zero);
    // The property under test is that the work does not run. The rejection
    // itself is swallowed at submission — a future that rejects with nothing
    // listening is reported by Dart as an unhandled async error, which would
    // fail the test for the wrong reason.
    var refused = false;
    // ignore: unawaited_futures
    queue.run(() async {
      ran = true;
    }).catchError((Object _) {
      refused = true;
    });

    queue.close();
    await blocker;
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(refused, isTrue, reason: 'queued work should have been refused');
    expect(ran, isFalse, reason: 'work ran after teardown');
    expect(queue.isClosed, isTrue);
  });
}
