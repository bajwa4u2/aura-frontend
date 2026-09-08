import 'package:flutter_test/flutter_test.dart';
import 'package:aura/features/meetings/domain/meeting.dart';
import 'package:aura/features/meetings/domain/meeting_lifecycle.dart';
import 'package:aura/features/meetings/domain/meeting_room.dart';
import 'package:aura/features/meetings/presentation/meeting_lifecycle_presenter.dart';

/// SCHEDULE IS INTENT. SESSION IS OCCURRENCE.
///
/// The backend had the defect and so did this presenter, independently and in
/// two places: the moment `scheduledAt + durationMinutes` elapsed it declared
/// the meeting **Missed** and terminal, which took the Start control away from
/// the host of a meeting that was merely running late.
///
/// A clock reading is not evidence that anyone failed to attend. NO_SHOW needs
/// positive admitted terminal evidence, and an active session must never lose
/// to a planned timestamp.
void main() {
  DateTime minutesAgo(int n) =>
      DateTime.now().subtract(Duration(minutes: n));

  Meeting meetingWith({
    required DateTime? scheduledAt,
    int durationMinutes = 30,
    String state = 'SCHEDULED',
  }) =>
      Meeting.fromJson({
        'id': 'm-1',
        'title': 'Certification',
        'meetingCode': 'keen-glen-711',
        'state': state,
        'type': 'VIDEO',
        'scheduledAt': scheduledAt?.toIso8601String(),
        'durationMinutes': durationMinutes,
        'timezone': 'UTC',
        'participants': const <dynamic>[],
      });

  MeetingRoom roomWith(String status, {int active = 0}) =>
      MeetingRoom.fromJson({
        'status': status,
        'activeParticipantCount': active,
        'canEnter': true,
        'canStart': true,
      });

  group('an overrunning meeting is in progress, not ended', () {
    test('the booked window elapsing does not change what it is', () {
      final vm = MeetingLifecyclePresenter.present(
        meetingWith(scheduledAt: minutesAgo(48), state: 'ACTIVE'),
        room: roomWith('IN_PROGRESS', active: 2),
      );

      expect(vm.status, MeetingLifecycleStatus.inProgress);
      expect(vm.label, 'In progress');
      expect(vm.isTerminal, isFalse);
      expect(vm.canEnter, isTrue);
    });

    test('the overrun is said once, and does not demote the state', () {
      final vm = MeetingLifecyclePresenter.present(
        meetingWith(scheduledAt: minutesAgo(48), state: 'ACTIVE'),
        room: roomWith('IN_PROGRESS', active: 2),
      );

      // 48 minutes past a 30 minute booking is 18 minutes over.
      expect(vm.subtitle, contains('past the scheduled end'));
      expect(vm.label, 'In progress');
    });

    test('a participant who dropped can still get back in', () {
      final vm = MeetingLifecyclePresenter.present(
        meetingWith(scheduledAt: minutesAgo(90), state: 'ACTIVE'),
        room: roomWith('IN_PROGRESS', active: 1),
      );
      expect(vm.canEnter, isTrue);
    });
  });

  group('a late meeting is not a missed meeting', () {
    test('the passed window is derived presentation, never terminal', () {
      final vm = MeetingLifecyclePresenter.present(
        meetingWith(scheduledAt: minutesAgo(120)),
        room: roomWith('SCHEDULED_TIME_PASSED'),
        isHost: true,
      );

      expect(vm.status, MeetingLifecycleStatus.scheduledTimePassed);
      expect(vm.status, isNot(MeetingLifecycleStatus.missed));
      expect(vm.isTerminal, isFalse);
    });

    test('the host keeps the ability to hold it', () {
      final vm = MeetingLifecyclePresenter.present(
        meetingWith(scheduledAt: minutesAgo(120)),
        room: roomWith('SCHEDULED_TIME_PASSED'),
        isHost: true,
      );

      expect(vm.canStart, isTrue);
      expect(vm.primaryAction, 'Start meeting');
    });

    test('and so does the presenter when the backend says nothing at all', () {
      // The fallback path re-derived the same verdict from the clock. This is
      // the branch that produced "Missed" with no room payload to justify it.
      final vm = MeetingLifecyclePresenter.present(
        meetingWith(scheduledAt: minutesAgo(120)),
        isHost: true,
      );

      expect(vm.status, isNot(MeetingLifecycleStatus.missed));
      expect(vm.isTerminal, isFalse);
      expect(vm.canStart, isTrue);
    });
  });

  group('a genuinely ended meeting is still terminal', () {
    test('admitted terminal truth is respected', () {
      final vm = MeetingLifecyclePresenter.present(
        meetingWith(scheduledAt: minutesAgo(48), state: 'ENDED'),
        room: roomWith('ENDED'),
      );

      expect(vm.status, MeetingLifecycleStatus.ended);
      expect(vm.isTerminal, isTrue);
      expect(vm.canEnter, isFalse);
    });
  });

  group('phase projection does not smuggle terminality back in', () {
    test('a passed window still projects as a scheduled meeting', () {
      expect(
        phaseFromRoomStatus(MeetingRoomStatus.scheduledTimePassed),
        MeetingPhase.scheduled,
      );
    });

    test('and MISSED stays reserved for real no-show evidence', () {
      expect(phaseFromRoomStatus(MeetingRoomStatus.missed), MeetingPhase.missed);
    });
  });
}
