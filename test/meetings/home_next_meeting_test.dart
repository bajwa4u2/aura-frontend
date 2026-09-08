import 'package:flutter_test/flutter_test.dart';
import 'package:aura/features/home/presentation/member_home_screen.dart';
import 'package:aura/features/meetings/domain/meeting.dart';

/// AN OVERDUE MEETING IS NOT THE NEXT MEETING.
///
/// A meeting whose scheduled time passes without starting is no longer
/// terminal in Aura — it stays actionable, deliberately, because a late
/// meeting is still a meeting. Moving it out of the "past" bucket was right.
///
/// But it put those meetings into "upcoming", and Home answers a different
/// question with that list: it sorts by `scheduledAt` ascending and shows the
/// first. The oldest overdue booking therefore won the up-next slot, and a
/// July meeting appeared on Home in September as what was coming up.
///
/// Observed by the founder, 2026-09-08, as a regression from that change.
void main() {
  final now = DateTime.utc(2026, 9, 8, 12, 0);

  Meeting meeting({
    required String id,
    DateTime? scheduledAt,
    int durationMinutes = 30,
    String state = 'SCHEDULED',
  }) =>
      Meeting.fromJson({
        'id': id,
        'title': id,
        'meetingCode': id,
        'state': state,
        'type': 'VIDEO',
        'scheduledAt': scheduledAt?.toIso8601String(),
        'durationMinutes': durationMinutes,
        'timezone': 'UTC',
        'participants': const <dynamic>[],
      });

  test('a two-month-old booking never becomes the next meeting', () {
    final stale = meeting(id: 'july', scheduledAt: DateTime.utc(2026, 7, 8, 14));
    final real = meeting(id: 'later', scheduledAt: now.add(const Duration(hours: 3)));

    // Ascending order puts the stale one first — which is exactly the trap.
    expect(nextMeetingForHome([stale, real], now)?.id, 'later');
  });

  test('nothing is offered when every candidate is overdue', () {
    final a = meeting(id: 'a', scheduledAt: DateTime.utc(2026, 7, 8, 14));
    final b = meeting(id: 'b', scheduledAt: DateTime.utc(2026, 7, 10, 15));
    expect(nextMeetingForHome([a, b], now), isNull,
        reason: 'Home shows nothing rather than something stale');
  });

  test('a meeting still inside its own window is next', () {
    // Began ten minutes ago, thirty minute booking: this is what a person is
    // about to walk into, not something that has gone by.
    final starting = meeting(
      id: 'starting',
      scheduledAt: now.subtract(const Duration(minutes: 10)),
      durationMinutes: 30,
    );
    expect(nextMeetingForHome([starting], now)?.id, 'starting');
  });

  test('a meeting one minute past its window is not', () {
    final justOver = meeting(
      id: 'over',
      scheduledAt: now.subtract(const Duration(minutes: 31)),
      durationMinutes: 30,
    );
    expect(nextMeetingForHome([justOver], now), isNull);
  });

  test('a live meeting wins even when a sooner one is scheduled', () {
    final soon = meeting(id: 'soon', scheduledAt: now.add(const Duration(minutes: 5)));
    final live = meeting(
      id: 'live',
      scheduledAt: now.add(const Duration(hours: 2)),
      state: 'ACTIVE',
    );
    expect(nextMeetingForHome([soon, live], now)?.id, 'live');
  });

  test('a live meeting wins even when it has overrun its window', () {
    // The overrun work said an active session outranks the calendar. Home must
    // not contradict that by hiding a meeting the person is currently in.
    final overrunning = meeting(
      id: 'overrun',
      scheduledAt: now.subtract(const Duration(hours: 2)),
      durationMinutes: 15,
      state: 'ACTIVE',
    );
    expect(nextMeetingForHome([overrunning], now)?.id, 'overrun');
  });

  test('an ended meeting is never next', () {
    final ended = meeting(
      id: 'ended',
      scheduledAt: now.add(const Duration(minutes: 5)),
      state: 'ENDED',
    );
    expect(nextMeetingForHome([ended], now), isNull);
  });

  test('a meeting with no booked time cannot be overdue', () {
    final instant = meeting(id: 'instant', scheduledAt: null);
    expect(nextMeetingForHome([instant], now)?.id, 'instant');
  });
}
