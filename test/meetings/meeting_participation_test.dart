import 'package:flutter_test/flutter_test.dart';

import 'package:aura/features/meetings/domain/meeting.dart';
import 'package:aura/features/meetings/domain/meeting_lifecycle.dart';
import 'package:aura/features/meetings/domain/meeting_participation.dart';

/// PARTICIPATION — R-2 and §XVI, founder ruling 2026-08-25.
void main() {
  MeetingParticipant row({
    String role = 'PARTICIPANT',
    String rsvp = 'PENDING',
    bool attended = false,
    DateTime? joinedAt,
    DateTime? leftAt,
    String? userId,
    String? guestName,
    String? guestEmail,
    MeetingHost? user,
  }) =>
      MeetingParticipant(
        id: 'p',
        meetingId: 'm',
        role: role,
        rsvpStatus: rsvp,
        attended: attended,
        joinedAt: joinedAt,
        leftAt: leftAt,
        userId: userId,
        guestName: guestName,
        guestEmail: guestEmail,
        user: user,
      );

  group('R-2 — one canonical name for "invited, has not answered"', () {
    test('PENDING and NO_RESPONSE converge', () {
      // The schema carries both. `NO_RESPONSE` is never WRITTEN by any code
      // path in the product — it exists in the enum and in one filter — so it
      // cannot mean anything different from PENDING in practice. The ruling
      // makes PENDING canonical; this is where the second spelling stops
      // being a second concept.
      expect(meetingInvitationFromString('PENDING'), MeetingInvitation.awaiting);
      expect(
          meetingInvitationFromString('NO_RESPONSE'), MeetingInvitation.awaiting);
    });

    test('the real answers stay distinct', () {
      expect(
          meetingInvitationFromString('ACCEPTED'), MeetingInvitation.accepted);
      expect(
          meetingInvitationFromString('DECLINED'), MeetingInvitation.declined);
    });

    test('somebody who arrived without an invitation is not "awaiting" one',
        () {
      expect(meetingInvitationFromString(null), MeetingInvitation.notInvited);
      expect(meetingInvitationFromString(''), MeetingInvitation.notInvited);
    });
  });

  group('a no-show is DERIVED, and only once the meeting is over', () {
    final expected = MeetingAttendance.of(row(rsvp: 'ACCEPTED'));

    test('it is not a no-show while the meeting could still happen', () {
      for (final p in [
        MeetingPhase.scheduled,
        MeetingPhase.ready,
        MeetingPhase.active,
      ]) {
        expect(expected.wasNoShow(p), isFalse,
            reason: 'called somebody absent from a meeting still running');
      }
    });

    test('somebody who accepted and never came is a no-show', () {
      expect(expected.wasNoShow(MeetingPhase.ended), isTrue);
    });

    test('somebody who never replied and never came is a no-show', () {
      expect(
        MeetingAttendance.of(row(rsvp: 'PENDING')).wasNoShow(MeetingPhase.ended),
        isTrue,
      );
    });

    test('somebody who DECLINED is not a no-show — they said so', () {
      expect(
        MeetingAttendance.of(row(rsvp: 'DECLINED'))
            .wasNoShow(MeetingPhase.ended),
        isFalse,
      );
    });

    test('somebody who came is never a no-show, however they replied', () {
      expect(
        MeetingAttendance.of(row(rsvp: 'PENDING', attended: true))
            .wasNoShow(MeetingPhase.ended),
        isFalse,
      );
      expect(
        MeetingAttendance.of(
          row(rsvp: 'PENDING', joinedAt: DateTime(2026, 8, 25)),
        ).wasNoShow(MeetingPhase.ended),
        isFalse,
      );
    });

    test('a cancelled meeting has no absentees — nobody was expected', () {
      expect(expected.wasNoShow(MeetingPhase.cancelled), isFalse);
    });
  });

  group('presence is where somebody is, not what they intended', () {
    test('accepted and absent are not the same fact', () {
      final a = MeetingAttendance.of(row(rsvp: 'ACCEPTED'));
      expect(a.invitation, MeetingInvitation.accepted);
      expect(a.presence, MeetingPresence.away);
    });

    test('present, then departed', () {
      final joined = MeetingAttendance.of(
        row(joinedAt: DateTime(2026, 8, 25, 10)),
      );
      expect(joined.presence, MeetingPresence.present);

      final left = MeetingAttendance.of(
        row(joinedAt: DateTime(2026, 8, 25, 10), leftAt: DateTime(2026, 8, 25, 11)),
      );
      expect(left.presence, MeetingPresence.departed);
      expect(left.timeInMeeting, const Duration(hours: 1));
    });

    test('knocking is distinct from away — one of them needs a host', () {
      final waiting =
          MeetingAttendance.of(row(), admissionState: 'PENDING');
      expect(waiting.presence, MeetingPresence.knocking);
    });

    test('removed is not "left"', () {
      final removed = MeetingAttendance.of(row(), admissionState: 'REMOVED');
      expect(removed.presence, MeetingPresence.removed);
    });

    test('a negative interval is refused rather than reported', () {
      final impossible = MeetingAttendance.of(
        row(joinedAt: DateTime(2026, 8, 25, 11), leftAt: DateTime(2026, 8, 25, 10)),
      );
      expect(impossible.timeInMeeting, isNull);
    });
  });

  group('roles', () {
    test('a co-host is a host for the purpose of responsibility', () {
      expect(MeetingAttendance.of(row(role: 'HOST')).isHost, isTrue);
      expect(MeetingAttendance.of(row(role: 'CO_HOST')).isHost, isTrue);
      expect(MeetingAttendance.of(row(role: 'PARTICIPANT')).isHost, isFalse);
      expect(MeetingAttendance.of(row(role: 'GUEST')).isHost, isFalse);
    });

    test('an unknown role is a participant, never a host', () {
      // Failing open on authority would hand somebody host controls because a
      // string did not parse.
      expect(MeetingAttendance.of(row(role: 'SOMETHING')).isHost, isFalse);
    });
  });

  group('§XI — naming a participant', () {
    test('an Aura member with no expanded person is NOT called Guest', () {
      // THE DEFECT: `displayName` ended `?? guestEmail ?? 'Guest'`, so a
      // member whose row was fetched without the user join was rendered as an
      // external participant type they do not hold.
      final member = row(userId: 'u-1');
      expect(member.displayName, isNot('Guest'));
      expect(member.isAuraPerson, isTrue);
    });

    test('a genuinely external participant keeps the accurate word', () {
      expect(row().displayName, 'Guest');
    });

    test('and is named by whatever they supplied, first', () {
      expect(row(guestName: 'Dana').displayName, 'Dana');
      expect(row(guestEmail: 'd@example.com').displayName, 'd@example.com');
    });

    test('a resolved person is named by the canonical authority', () {
      final named = MeetingHost.fromJson(<String, dynamic>{
        'userId': 'u-1',
        'displayName': 'Amara Okafor',
        'handle': 'amara',
      });
      expect(row(userId: 'u-1', user: named).displayName, 'Amara Okafor');
    });
  });

  group('the roster answers the questions surfaces keep asking', () {
    Meeting meeting(List<MeetingParticipant> people) => Meeting(
          id: 'm',
          title: 'Review',
          type: 'SCHEDULED',
          state: 'ENDED',
          meetingCode: 'C',
          joinUrl: '',
          durationMinutes: 30,
          timezone: 'UTC',
          visibility: 'PRIVATE',
          waitingRoomEnabled: true,
          recordingEnabled: false,
          screenShareEnabled: true,
          chatEnabled: true,
          allowGuests: false,
          guestApprovalRequired: true,
          participants: people,
          createdAt: DateTime(2026, 8, 25),
          updatedAt: DateTime(2026, 8, 25),
        );

    test('counts each population once', () {
      final roster = MeetingRoster.of(meeting([
        row(rsvp: 'ACCEPTED', attended: true, joinedAt: DateTime(2026, 8, 25)),
        row(rsvp: 'ACCEPTED'),
        row(rsvp: 'DECLINED'),
        row(rsvp: 'PENDING'),
      ]));

      expect(roster.invited, 4);
      expect(roster.accepted, 2);
      expect(roster.declined, 1);
      expect(roster.awaiting, 1);
      expect(roster.attended, 1);
      // The two who said yes-or-nothing and did not come. The one who
      // declined is not among them.
      expect(roster.noShows(MeetingPhase.ended), 2);
    });

    test('an empty roster counts nothing rather than failing', () {
      final roster = MeetingRoster.of(meeting([]));
      expect(roster.all, isEmpty);
      expect(roster.noShows(MeetingPhase.ended), 0);
    });
  });
}
