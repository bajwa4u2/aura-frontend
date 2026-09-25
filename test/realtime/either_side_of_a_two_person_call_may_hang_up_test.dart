import 'package:flutter_test/flutter_test.dart';

import 'package:aura/features/realtime/presentation/widgets/floating_call_widget.dart';

/// EITHER SIDE OF A TWO-PERSON CALL MAY HANG UP.
///
/// The minimised card offered a red **End** to anyone whose tab owned the
/// media — `isOwner` — and owning the media is not authority over the call.
/// The server refused every non-host end outright, so a callee could press End
/// and watch nothing happen.
///
/// Founder-observed 2026-09-24: *"mrs bajwa was the caller. i end from my side
/// it reside in top banner not ended then i press join it shows joined but mrs
/// bajwa was in connecting i press leave from her end then it teared down"*.
/// The conversation banner was RIGHT — the host was still in the call, so it
/// had not ended. The card was wrong to have offered the act.
///
/// Then: *"its odd that attendee have no option to end the call, it must be
/// both ways so anyone have authority to end, right?"* — and for two people,
/// yes. A telephone has never worked any other way: whoever hangs up, the call
/// is over.
///
/// NOT "anyone may end anything", which is the part worth holding. A group call
/// or a meeting is not symmetrical: one attendee of five pressing End would
/// hang up on the other four, so there ending is the host's act and everyone
/// else leaves. The same rule is enforced server-side in
/// `RealtimeSessionService.peerMayEndSession`; this one exists so the interface
/// only ever offers an act the server will honour.
void main() {
  group('two people are symmetrical', () {
    test('THE DEFECT: the callee in a 1:1 call may end it', () {
      expect(
        mayEndForEveryone(isHost: false, isMeeting: false, participantCount: 2),
        isTrue,
        reason: 'this is the case the founder was locked out of',
      );
    });

    test('so may the host, obviously', () {
      expect(
        mayEndForEveryone(isHost: true, isMeeting: false, participantCount: 2),
        isTrue,
      );
    });

    test('a call with only me in it can still be hung up', () {
      // A roster that has not populated yet must not produce a card that
      // refuses to end a call with one person in it.
      for (final n in [0, 1]) {
        expect(
          mayEndForEveryone(
            isHost: false,
            isMeeting: false,
            participantCount: n,
          ),
          isTrue,
          reason: 'participantCount=$n',
        );
      }
    });
  });

  group('a group is NOT symmetrical', () {
    test('an attendee of three may not hang up on the other two', () {
      expect(
        mayEndForEveryone(isHost: false, isMeeting: false, participantCount: 3),
        isFalse,
      );
    });

    test('nor of five', () {
      expect(
        mayEndForEveryone(isHost: false, isMeeting: false, participantCount: 5),
        isFalse,
      );
    });

    test('the host of a group still may', () {
      expect(
        mayEndForEveryone(isHost: true, isMeeting: false, participantCount: 5),
        isTrue,
      );
    });
  });

  group('a meeting always has a host, by construction', () {
    test('an attendee may never end a meeting, even a two-person one', () {
      // A meeting is scheduled, named and owned. Two people being in the room
      // at this moment does not make it a phone call.
      for (final n in [1, 2, 3, 9]) {
        expect(
          mayEndForEveryone(
            isHost: false,
            isMeeting: true,
            participantCount: n,
          ),
          isFalse,
          reason: 'participantCount=$n',
        );
      }
    });

    test('the meeting host may', () {
      expect(
        mayEndForEveryone(isHost: true, isMeeting: true, participantCount: 9),
        isTrue,
      );
    });
  });
}
