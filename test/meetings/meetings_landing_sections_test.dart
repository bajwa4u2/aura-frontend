import 'package:flutter_test/flutter_test.dart';

import 'package:aura/features/meetings/domain/meeting.dart';
import 'package:aura/features/meetings/presentation/meetings_home_screen.dart';

/// ONE MEETING, ONE PLACE ON THE PAGE.
///
/// Found in production on 2026-08-25, immediately after the founder-authorized
/// certification meeting was created: the new meeting rendered TWICE on the
/// Meetings landing — once under "Up next" and again under "Needs attention".
///
/// Both placements were defensible on their own terms. A meeting starting
/// within three hours does need attention, and it was also the most imminent
/// one. But the same card twice on one screen reads as two meetings, and the
/// count beside "Needs attention" then counts it again.
void main() {
  Meeting meeting({
    required String id,
    required DateTime at,
    String state = 'SCHEDULED',
  }) =>
      Meeting(
        id: id,
        title: 'Meeting $id',
        type: 'SCHEDULED',
        state: state,
        meetingCode: id,
        joinUrl: '',
        durationMinutes: 60,
        timezone: 'UTC',
        visibility: 'PRIVATE',
        waitingRoomEnabled: true,
        recordingEnabled: false,
        screenShareEnabled: true,
        chatEnabled: true,
        allowGuests: false,
        guestApprovalRequired: true,
        scheduledAt: at,
        participants: const [],
        createdAt: DateTime(2026, 8, 25),
        updatedAt: DateTime(2026, 8, 25),
      );

  final now = DateTime.now();

  test('the up-next meeting is not repeated under Needs attention', () {
    // THE PRODUCTION CASE: created at 6:18 PM, scheduled for 6:18 PM — so it
    // was both the most imminent meeting and inside the attention window.
    final imminent = meeting(id: 'a', at: now.add(const Duration(minutes: 1)));
    final upcoming = [imminent];

    expect(
      meetingsNeedingAttention(upcoming, imminent, 'me').map((m) => m.id),
      isEmpty,
      reason: 'the meeting rendered twice on one screen',
    );
  });

  test('another imminent meeting still gets attention', () {
    // The fix must not empty the section — only stop it repeating ONE card.
    final first = meeting(id: 'a', at: now.add(const Duration(minutes: 1)));
    final second = meeting(id: 'b', at: now.add(const Duration(minutes: 30)));

    final attention = meetingsNeedingAttention([first, second], first, 'me');
    expect(attention.map((m) => m.id), ['b']);
  });

  test('with nothing led with, every imminent meeting is listed', () {
    final first = meeting(id: 'a', at: now.add(const Duration(minutes: 1)));
    final second = meeting(id: 'b', at: now.add(const Duration(minutes: 30)));

    expect(
      meetingsNeedingAttention([first, second], null, 'me').map((m) => m.id),
      ['a', 'b'],
    );
  });

  test('a meeting days away is not an attention item at all', () {
    final far = meeting(id: 'c', at: now.add(const Duration(days: 3)));
    expect(meetingsNeedingAttention([far], null, 'me'), isEmpty);
  });

  test('an ended meeting never needs attention', () {
    final ended = meeting(
      id: 'd',
      at: now.add(const Duration(minutes: 5)),
      state: 'ENDED',
    );
    expect(meetingsNeedingAttention([ended], null, 'me'), isEmpty);
  });
}
