import 'package:flutter_test/flutter_test.dart';

import 'package:aura/features/meetings/domain/meeting_entry_resolution.dart';

// Participation Architecture: the frontend renders backend outcomes and
// NEVER invents policy. These tests pin the wire contract — outcome parsing,
// fail-closed defaults, and the state flags each screen state keys off.
void main() {
  group('MeetingEntryOutcome.parse', () {
    test('maps every canonical wire value', () {
      expect(MeetingEntryOutcome.parse('HOST_DIRECT'),
          MeetingEntryOutcome.hostDirect);
      expect(MeetingEntryOutcome.parse('PARTICIPANT_DIRECT'),
          MeetingEntryOutcome.participantDirect);
      expect(MeetingEntryOutcome.parse('BOOKER_DIRECT'),
          MeetingEntryOutcome.bookerDirect);
      expect(MeetingEntryOutcome.parse('INVITED_DIRECT'),
          MeetingEntryOutcome.invitedDirect);
      expect(MeetingEntryOutcome.parse('INSTITUTION_MEMBER_DIRECT'),
          MeetingEntryOutcome.institutionMemberDirect);
      expect(MeetingEntryOutcome.parse('INVITATION_VERIFICATION_REQUIRED'),
          MeetingEntryOutcome.invitationVerificationRequired);
      expect(MeetingEntryOutcome.parse('GUEST_DIRECT'),
          MeetingEntryOutcome.guestDirect);
      expect(MeetingEntryOutcome.parse('WAITING_FOR_ADMISSION'),
          MeetingEntryOutcome.waitingForAdmission);
      expect(MeetingEntryOutcome.parse('LOGIN_REQUIRED'),
          MeetingEntryOutcome.loginRequired);
      expect(MeetingEntryOutcome.parse('IDENTITY_CONFLICT'),
          MeetingEntryOutcome.identityConflict);
      expect(
          MeetingEntryOutcome.parse('FORBIDDEN'), MeetingEntryOutcome.forbidden);
      expect(MeetingEntryOutcome.parse('MEETING_UNAVAILABLE'),
          MeetingEntryOutcome.meetingUnavailable);
    });

    test('fails CLOSED on unknown or missing outcomes', () {
      expect(MeetingEntryOutcome.parse('SOMETHING_NEW'),
          MeetingEntryOutcome.meetingUnavailable);
      expect(MeetingEntryOutcome.parse(null),
          MeetingEntryOutcome.meetingUnavailable);
    });

    test('canJoin covers exactly the direct outcomes', () {
      const joinable = {
        MeetingEntryOutcome.hostDirect,
        MeetingEntryOutcome.participantDirect,
        MeetingEntryOutcome.bookerDirect,
        MeetingEntryOutcome.invitedDirect,
        MeetingEntryOutcome.institutionMemberDirect,
        MeetingEntryOutcome.guestDirect,
      };
      for (final outcome in MeetingEntryOutcome.values) {
        expect(outcome.canJoin, joinable.contains(outcome),
            reason: 'canJoin mismatch for $outcome');
      }
    });

    test('terminal states are exactly forbidden/conflict/unavailable', () {
      const terminal = {
        MeetingEntryOutcome.forbidden,
        MeetingEntryOutcome.identityConflict,
        MeetingEntryOutcome.meetingUnavailable,
      };
      for (final outcome in MeetingEntryOutcome.values) {
        expect(outcome.isTerminal, terminal.contains(outcome),
            reason: 'isTerminal mismatch for $outcome');
      }
    });
  });

  group('MeetingEntryResolution.fromJson', () {
    test('parses a full booker resolution', () {
      final resolution = MeetingEntryResolution.fromJson({
        'outcome': 'BOOKER_DIRECT',
        'action': 'JOIN',
        'reasonCode': 'BOOKING_VALID',
        'identity': {
          'kind': 'ANONYMOUS',
          'displayName': null,
          'email': null,
        },
        'requirements': {
          'loginRequired': false,
          'approvalRequired': false,
        },
        'participation': {'status': 'RESOLVED', 'role': 'GUEST'},
        'admission': {
          'status': 'ADMITTED',
          'meetingLive': true,
          'requiresApproval': false,
        },
        'context': {
          'participantId': 'p-1',
          'bookingId': 'booking-1',
          'invitationId': null,
          'institutionMemberId': null,
          'eligibilitySource': 'BOOKING',
        },
        'prefill': {'name': 'Booker', 'email': 'booker@example.com'},
        'presentation': {
          'meetingId': 'meeting-1',
          'meetingCode': '123456',
          'title': 'Advisory Session',
          'state': 'ACTIVE',
          'durationMinutes': 30,
          'timezone': 'UTC',
          'host': {'displayName': 'Host', 'avatarUrl': null, 'title': null},
          'institution': null,
        },
      });

      expect(resolution.outcome, MeetingEntryOutcome.bookerDirect);
      expect(resolution.action, MeetingEntryAction.join);
      expect(resolution.meetingLive, true);
      expect(resolution.bookingId, 'booking-1');
      expect(resolution.prefillName, 'Booker');
      expect(resolution.presentation?.title, 'Advisory Session');
      expect(resolution.presentation?.host?.displayName, 'Host');
    });

    test('missing sections default to safe values — unknown outcomes fail CLOSED', () {
      final resolution = MeetingEntryResolution.fromJson(const {
        'outcome': 'SOME_FUTURE_OUTCOME',
        'action': 'SOME_FUTURE_ACTION',
      });
      expect(resolution.outcome, MeetingEntryOutcome.meetingUnavailable);
      expect(resolution.action, MeetingEntryAction.none);
      expect(resolution.identityKind, 'ANONYMOUS');
      expect(resolution.approvalRequired, false);
      expect(resolution.meetingLive, false);
      expect(resolution.presentation, isNull);
    });
  });
}
