import 'package:flutter_test/flutter_test.dart';

import 'package:aura/features/meetings/domain/meeting_lifecycle.dart';
import 'package:aura/features/meetings/domain/meeting_room.dart';

/// ONE LIFECYCLE AUTHORITY — founder ruling 2026-08-25 §XIII.
///
/// Before this, three things answered "what is happening with this meeting":
/// the record column, the room projection, and a set of getters that mixed
/// them differently from each other. These tests pin the rule that replaced
/// them, and each one names the disagreement it prevents.
void main() {
  MeetingPhase phase(String? record, [MeetingRoomStatus? room]) =>
      resolveMeetingPhase(recordState: record, roomStatus: room);

  group('the record alone', () {
    test('reads every state it can hold', () {
      expect(phase('DRAFT'), MeetingPhase.draft);
      expect(phase('SCHEDULED'), MeetingPhase.scheduled);
      expect(phase('ACTIVE'), MeetingPhase.active);
      expect(phase('ENDED'), MeetingPhase.ended);
      expect(phase('CANCELLED'), MeetingPhase.cancelled);
    });

    test('is honest when it says nothing recognisable', () {
      // Not "scheduled" as a hopeful default: a surface that cannot know
      // should say so rather than assert the most convenient answer.
      expect(phase(null), MeetingPhase.unknown);
      expect(phase(''), MeetingPhase.unknown);
      expect(phase('SOMETHING_NEW'), MeetingPhase.unknown);
    });
  });

  group('the room refines the record', () {
    test('a scheduled meeting whose room is live IS live', () {
      // The fresher computation wins going forward. A record cached before
      // the host pressed start must not tell a person the meeting has not
      // begun while everyone else is in it.
      expect(phase('SCHEDULED', MeetingRoomStatus.live), MeetingPhase.active);
      expect(
          phase('SCHEDULED', MeetingRoomStatus.inProgress), MeetingPhase.active);
    });

    test('every flavour of waiting means the same thing: you can go in', () {
      for (final status in [
        MeetingRoomStatus.startingSoon,
        MeetingRoomStatus.waiting,
        MeetingRoomStatus.hostWaiting,
        MeetingRoomStatus.guestWaiting,
      ]) {
        expect(phase('SCHEDULED', status), MeetingPhase.ready, reason: '$status');
      }
    });

    test('a connection problem is NOT a lifecycle event', () {
      // The meeting is still happening; the A/V layer owns saying that the
      // pipe is struggling. Treating it as a lifecycle change would end a
      // meeting because somebody's wifi dropped.
      expect(
        phase('ACTIVE', MeetingRoomStatus.connectionIssue),
        MeetingPhase.active,
      );
    });
  });

  group('forward only', () {
    test('a stale room cannot un-start a live meeting', () {
      // THE REGRESSION THIS PREVENTS: a reconnecting room projection arriving
      // with `scheduled` would otherwise send an active meeting backwards, and
      // the room controls would vanish from under the people using them.
      expect(phase('ACTIVE', MeetingRoomStatus.scheduled), MeetingPhase.active);
      expect(phase('ENDED', MeetingRoomStatus.live), MeetingPhase.ended);
    });

    test('a room may still report the end first', () {
      expect(phase('ACTIVE', MeetingRoomStatus.ended), MeetingPhase.ended);
      expect(phase('SCHEDULED', MeetingRoomStatus.missed), MeetingPhase.missed);
    });
  });

  group('two absolute record decisions', () {
    test('cancelled is cancelled, whatever the room says', () {
      for (final status in MeetingRoomStatus.values) {
        expect(phase('CANCELLED', status), MeetingPhase.cancelled,
            reason: '$status un-cancelled a cancelled meeting');
      }
    });

    test('a draft has no room worth listening to', () {
      expect(phase('DRAFT', MeetingRoomStatus.live), MeetingPhase.draft);
    });
  });

  group('the old getters disagreed; these do not', () {
    test('every phase is exactly one of upcoming, ready, active, concluded',
        () {
      // The concrete defect: `isEnded` was true when the room said `missed`
      // while `state` was still SCHEDULED, and `isScheduled` was true for only
      // five of twelve room statuses — so a meeting could be neither
      // scheduled, nor active, nor ended, all at once.
      for (final record in ['DRAFT', 'SCHEDULED', 'ACTIVE', 'ENDED', 'CANCELLED']) {
        for (final room in [null, ...MeetingRoomStatus.values]) {
          final p = resolveMeetingPhase(recordState: record, roomStatus: room);
          final life = MeetingLifecycle(
            phase: p,
            capability: MeetingCapability.none,
          );
          final flags = [
            life.isDraft,
            life.isUpcoming,
            life.isReady,
            life.isActive,
            life.isConcluded,
          ].where((f) => f).length;
          expect(flags, 1,
              reason: 'record=$record room=$room resolved to $p and set '
                  '$flags flags — a meeting must be in exactly one place');
        }
      }
    });

    test('only a meeting that HAPPENED has an aftermath', () {
      // A cancelled meeting has no record of what occurred, because nothing
      // did — offering a summary for one would be offering a blank page.
      expect(
        MeetingLifecycle(
          phase: MeetingPhase.ended,
          capability: MeetingCapability.none,
        ).hasAftermath,
        isTrue,
      );
      for (final p in [MeetingPhase.cancelled, MeetingPhase.missed]) {
        expect(
          MeetingLifecycle(phase: p, capability: MeetingCapability.none)
              .hasAftermath,
          isFalse,
          reason: '$p offered an aftermath it does not have',
        );
      }
    });
  });

  group('capability is the backend\'s answer, not the client\'s', () {
    MeetingRoom room({
      bool canEnter = false,
      bool canStart = false,
      bool canEnd = false,
    }) =>
        MeetingRoom(
          status: MeetingRoomStatus.live,
          guestWaitingCount: 0,
          hostCount: 1,
          guestCount: 0,
          activeParticipantCount: 1,
          canEnter: canEnter,
          canStart: canStart,
          canEnd: canEnd,
          canRetryTransport: false,
          isPastScheduledEnd: false,
        );

    test('the projection is taken at its word', () {
      final c = MeetingCapability.resolve(
        phase: MeetingPhase.active,
        room: room(canEnter: true, canEnd: true),
      );
      expect(c.canJoin, isTrue);
      expect(c.canEnd, isTrue);
      expect(c.canStart, isFalse);
      expect(c.isAuthoritative, isTrue);
    });

    test('without a projection the client never invents HOST authority', () {
      // Starting and ending a meeting are acts with consequences for other
      // people. A client that guessed would offer somebody a control the
      // server is about to refuse.
      final c = MeetingCapability.resolve(phase: MeetingPhase.active);
      expect(c.canStart, isFalse);
      expect(c.canEnd, isFalse);
      expect(c.isAuthoritative, isFalse);
    });

    test('and it says when it is only guessing', () {
      final c = MeetingCapability.resolve(phase: MeetingPhase.ready);
      expect(c.canJoin, isTrue);
      expect(c.isAuthoritative, isFalse,
          reason: 'a surface must be able to tell a derived answer from a '
              'governed one, or it cannot choose to stay quiet');
    });
  });
}
