import 'package:flutter_test/flutter_test.dart';
import 'package:aura/features/realtime/domain/call_occurrence.dart';
import 'package:aura/features/realtime/domain/call_state.dart';
import 'package:aura/features/realtime/domain/realtime_models.dart';

/// A CALL HISTORY ITEM IS A CALL, NOT A CONVERSATION.
///
/// Call History opened the Conversation, which answers "what have we said to
/// each other" when the person asked "what happened on that call". This is the
/// occurrence itself; the conversation is reachable from it as secondary
/// context.
///
/// Everything here READS canonical call truth. No outcome is invented, no
/// duration is fabricated, and the seven backend outcomes stay seven.
void main() {
  CallState call({
    required String outcome,
    String initiator = 'me',
    String kind = 'VIDEO',
    DateTime? ringPresentedAt,
    DateTime? connectedAt,
    DateTime? endedAt,
  }) =>
      CallState.fromJson({
        'id': 'call-1',
        'phase': 'ENDED',
        'kind': kind,
        'outcome': outcome,
        'initiatorUserId': initiator,
        'initiatedAt': '2026-09-09T00:55:41.000Z',
        'ringPresentedAt': ringPresentedAt?.toIso8601String(),
        'connectedAt': connectedAt?.toIso8601String(),
        'endedAt': endedAt?.toIso8601String(),
        'participants': const <dynamic>[],
      })!;

  RealtimeParticipant person(String userId, String name) =>
      RealtimeParticipant.fromJson({
        'id': 'p-$userId',
        'userId': userId,
        'displayName': name,
        'role': 'PARTICIPANT',
        'joinState': 'LEFT',
      });

  CallOccurrence occurrence(CallState c, {String viewer = 'me'}) =>
      CallOccurrence(
        sessionId: 'sess-1',
        call: c,
        viewerUserId: viewer,
        participants: [person('me', 'Me'), person('them', 'Mrs Bajwa')],
        conversationId: 'conv-1',
      );

  group('duration is never fabricated', () {
    test('a call that never connected has no duration', () {
      // Not zero, and NOT the time the room was open. "0:47" against a call
      // nobody answered is a lie about the person's own call.
      final o = occurrence(call(
        outcome: 'MISSED',
        endedAt: DateTime.utc(2026, 9, 9, 0, 56, 30),
      ));
      expect(o.duration, isNull);
      expect(o.everConnected, isFalse);
    });

    test('a connected call is measured from connectedAt, not from initiation', () {
      final o = occurrence(call(
        outcome: 'CONNECTED_ENDED',
        connectedAt: DateTime.utc(2026, 9, 9, 0, 56, 0),
        endedAt: DateTime.utc(2026, 9, 9, 0, 58, 30),
      ));
      expect(o.duration, const Duration(minutes: 2, seconds: 30));
    });
  });

  group('whether it ever rang is its own fact', () {
    test('a cancelled call that never rang says so', () {
      // The real 2026-09-09 call: cancelled by the caller at 20.6s with
      // ringPresentedAt never written. "They did not answer" would be false —
      // nothing had asked them to.
      final o = occurrence(call(outcome: 'CANCELED_BEFORE_ANSWER'));
      expect(o.everRang, isFalse);
    });

    test('a missed call did ring', () {
      final o = occurrence(call(
        outcome: 'MISSED',
        ringPresentedAt: DateTime.utc(2026, 9, 9, 0, 55, 44),
      ));
      expect(o.everRang, isTrue);
    });
  });

  group('the counterpart', () {
    test('is the other person in a two-party call', () {
      expect(occurrence(call(outcome: 'MISSED')).counterpart?.displayName,
          'Mrs Bajwa');
    });

    test('is nobody when more than two were involved', () {
      // Better to list a group than to pick one name and call it "the call
      // with X".
      final o = CallOccurrence(
        sessionId: 's',
        call: call(outcome: 'CONNECTED_ENDED'),
        viewerUserId: 'me',
        participants: [person('me', 'Me'), person('a', 'A'), person('b', 'B')],
      );
      expect(o.counterpart, isNull);
    });
  });

  group('the seven outcomes stay seven', () {
    test('no answer is not failed', () {
      final noAnswer = callOutcomeHeadline(
          outcome: CallOutcome.missed, viewerIsCaller: true, isVideo: true);
      final failed = callOutcomeHeadline(
          outcome: CallOutcome.failed, viewerIsCaller: true, isVideo: true);
      expect(noAnswer, isNot(failed));
      expect(noAnswer, contains('no answer'));
    });

    test('missed is not cancelled', () {
      expect(
        callOutcomeHeadline(
            outcome: CallOutcome.missed, viewerIsCaller: false, isVideo: false),
        isNot(callOutcomeHeadline(
            outcome: CallOutcome.canceledBeforeAnswer,
            viewerIsCaller: false,
            isVideo: false)),
      );
    });

    test('ended is not could-not-connect', () {
      expect(
        callOutcomeHeadline(
            outcome: CallOutcome.connectedEnded,
            viewerIsCaller: true,
            isVideo: true),
        isNot(callOutcomeHeadline(
            outcome: CallOutcome.acceptedNotConnected,
            viewerIsCaller: true,
            isVideo: true)),
      );
    });

    test('never-rang is never described as missed', () {
      final headline = callOutcomeHeadline(
          outcome: CallOutcome.notPresented,
          viewerIsCaller: false,
          isVideo: false);
      expect(headline.toLowerCase(), isNot(contains('missed')));
    });

    test('every canonical outcome produces a distinct sentence per side', () {
      // Guards the collapse that started this: four of seven outcomes reading
      // as one sentence.
      for (final caller in [true, false]) {
        final seen = <String>{};
        for (final o in CallOutcome.values) {
          if (o == CallOutcome.unknownLegacy) continue;
          seen.add(callOutcomeHeadline(
              outcome: o, viewerIsCaller: caller, isVideo: true));
        }
        expect(seen.length, CallOutcome.values.length - 1,
            reason: 'two outcomes share a sentence for caller=$caller');
      }
    });
  });

  test('direction is read from the initiator, not the viewer', () {
    expect(occurrence(call(outcome: 'MISSED', initiator: 'me')).viewerIsCaller,
        isTrue);
    expect(occurrence(call(outcome: 'MISSED', initiator: 'them')).viewerIsCaller,
        isFalse);
  });
}
