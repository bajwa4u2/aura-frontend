import 'package:flutter_test/flutter_test.dart';

import 'package:aura/core/notifications/notification_arrival_gate.dart';

// THE COLD-START REPLAY.
//
// Founder-observed, live, 2026-08-22: entering Aura or refreshing showed the
// global bottom overlay announcing a message that had arrived days earlier.
//
// The mechanism was a baseline that could never be established. The bridge
// seeded its seen-set from whatever the controller already held — but at cold
// start the controller holds nothing, so the baseline was EMPTY and the first
// successful fetch looked like every notification arriving at once.
//
// This was untestable while it lived as private widget state, which is why it
// survived. These are the assertions that now hold it.

void main() {
  group('the first successful load is history, not arrival', () {
    test('a cold start presents nothing, however much it loads', () {
      final gate = NotificationArrivalGate();

      final admitted = gate.admit(
        previousIds: const <String>[],
        nextIds: const ['n1', 'n2', 'n3'],
      );

      expect(admitted, isEmpty,
          reason: 'notifications that predate the app opening are not arrivals');
      expect(gate.baselineEstablished, isTrue);
    });

    test('the baseline is recorded, so a later poll does not re-present it', () {
      final gate = NotificationArrivalGate()
        ..admit(previousIds: const [], nextIds: const ['n1', 'n2']);

      final again = gate.admit(
        previousIds: const ['n1', 'n2'],
        nextIds: const ['n1', 'n2'],
      );

      expect(again, isEmpty);
    });

    test('an empty first load does not consume the baseline', () {
      // The controller starts empty and the fetch has not landed yet. If that
      // counted as the baseline, the real first load would be treated as
      // arrivals — which is the original defect, one step later.
      final gate = NotificationArrivalGate();

      expect(gate.admit(previousIds: const [], nextIds: const []), isEmpty);
      expect(gate.baselineEstablished, isFalse);

      expect(
        gate.admit(previousIds: const [], nextIds: const ['n1']),
        isEmpty,
        reason: 'this is still the first real load',
      );
    });
  });

  group('genuine arrivals must survive', () {
    test('a notification first seen after the baseline IS presented', () {
      final gate = NotificationArrivalGate()
        ..admit(previousIds: const [], nextIds: const ['old1', 'old2']);

      final admitted = gate.admit(
        previousIds: const ['old1', 'old2'],
        nextIds: const ['new1', 'old1', 'old2'],
      );

      expect(admitted, ['new1']);
    });

    test('several arrivals in one poll are all presented, in order', () {
      final gate = NotificationArrivalGate()
        ..admit(previousIds: const [], nextIds: const ['old1']);

      final admitted = gate.admit(
        previousIds: const ['old1'],
        nextIds: const ['newA', 'newB', 'old1'],
      );

      expect(admitted, ['newA', 'newB']);
    });

    test('an id already in the previous snapshot is a re-render, not an arrival',
        () {
      final gate = NotificationArrivalGate()
        ..admit(previousIds: const [], nextIds: const ['old1']);

      final admitted = gate.admit(
        previousIds: const ['old1', 'carried'],
        nextIds: const ['carried', 'old1'],
      );

      expect(admitted, isEmpty);
    });
  });

  group('a session boundary resets the baseline', () {
    test('after sign-out the next load is history again, not a replay', () {
      final gate = NotificationArrivalGate()
        ..admit(previousIds: const [], nextIds: const ['a', 'b']);

      gate.reset();
      expect(gate.baselineEstablished, isFalse);

      expect(
        gate.admit(previousIds: const [], nextIds: const ['c', 'd']),
        isEmpty,
        reason: 'the new account establishes its own baseline',
      );
    });

    test('establishBaseline covers mounting over a populated controller', () {
      final gate = NotificationArrivalGate()..establishBaseline(const ['x', 'y']);

      expect(gate.baselineEstablished, isTrue);
      expect(
        gate.admit(previousIds: const ['x', 'y'], nextIds: const ['x', 'y']),
        isEmpty,
      );
      expect(
        gate.admit(previousIds: const ['x', 'y'], nextIds: const ['z', 'x']),
        ['z'],
        reason: 'a real arrival after that baseline still shows',
      );
    });

    test('establishBaseline never overwrites a baseline already taken', () {
      final gate = NotificationArrivalGate()
        ..admit(previousIds: const [], nextIds: const ['a']);

      gate.establishBaseline(const ['b']);

      expect(
        gate.admit(previousIds: const ['a'], nextIds: const ['b', 'a']),
        ['b'],
        reason: 'b arrived after the baseline and must not be silently absorbed',
      );
    });
  });
}
