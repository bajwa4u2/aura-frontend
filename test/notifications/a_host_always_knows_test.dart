import 'package:flutter_test/flutter_test.dart';

import 'package:aura/core/notifications/notification_presentation.dart';

/// 6 Nov 2026: the founder missed two booked meetings — no notice at all.
/// The server now tells the HOST of a booking, reminds them, and says when a
/// guest is waiting. Those notices are written about the OTHER person; the
/// actor is still the meeting's owner (an institution), so without the host
/// branch the list would read "Your meeting with Aura Platform LLC is
/// scheduled" — to the person who runs it.
void main() {
  Map<String, dynamic> hostNotice(String type) => {
        'type': type,
        'actor': {'displayName': 'Aura Platform LLC'},
        'data': {
          'meetingId': 'm-1',
          'meetingTitle': 'Intro',
          'audience': 'host',
          'counterpartName': 'John',
        },
      };

  test('a booking names the booker', () {
    expect(resolveNotificationTitle(hostNotice('MEETING_BOOKED')),
        'John booked a meeting with you');
  });

  test('a reminder names who the host meets', () {
    expect(resolveNotificationTitle(hostNotice('MEETING_REMINDER')),
        'Upcoming: your meeting with John');
  });

  test('a waiting guest is named, not the institution', () {
    expect(resolveNotificationTitle(hostNotice('MEETING_WAITING_ROOM_ARRIVAL')),
        'John is waiting for you in your meeting');
  });

  test("the attendee's own notice is unchanged", () {
    final attendee = {
      'type': 'MEETING_BOOKED',
      'actor': {'displayName': 'Aura Platform LLC'},
      'data': {'meetingId': 'm-1'},
    };
    expect(resolveNotificationTitle(attendee),
        'Your meeting with Aura Platform LLC is scheduled');
  });
}
