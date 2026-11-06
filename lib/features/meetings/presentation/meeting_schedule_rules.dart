import '../domain/meeting.dart';

/// Small, shared rules for scheduling and answering a meeting (6 Nov 2026,
/// meetings gaps Phase C). Kept free of widgets so each one is tested on its
/// own and the create screen and the meeting page cannot disagree.

/// The lengths offered when a meeting is created or edited.
const List<int> kStandardMeetingDurations = [15, 30, 45, 60, 90, 120];

/// The lengths to offer when editing a meeting that is [current] minutes long.
///
/// A meeting booked through a booking page can be 20 or 75 minutes. The edit
/// dialog offered only the standard list, so the dropdown had no item for the
/// meeting's real length and Flutter refused to draw it.
List<int> meetingDurationChoices(int current) {
  final choices = {...kStandardMeetingDurations};
  if (current > 0) choices.add(current);
  return choices.toList()..sort();
}

/// True when [when] is already in the past. A meeting cannot be scheduled
/// there: the date picker started at today, but the time picker then let any
/// earlier hour of today through.
bool isPastMeetingTime(DateTime when, {DateTime? now}) =>
    when.isBefore(now ?? DateTime.now());

const String kPastMeetingTimeMessage =
    'That time has already passed. Pick a later time.';

/// May this viewer run the meeting: start it, edit it, reschedule it, invite
/// people, and keep its agenda, materials and record?
///
/// Mirrors the server's `assertHostAccess`: the host, or a holder of
/// MANAGE_MEETINGS on the owning institution ([canGovern]).
bool canManageMeeting({required bool isHost, required bool canGovern}) =>
    isHost || canGovern;

/// The viewer's own participant row, when they are an invited participant who
/// answers the meeting rather than runs it. Hosts and co-hosts are excluded:
/// the server refuses their answer.
MeetingParticipant? answeringParticipant(Meeting meeting, String myUserId) {
  final me = myUserId.trim();
  if (me.isEmpty) return null;
  if ((meeting.host?.id ?? '') == me) return null;
  for (final p in meeting.participants) {
    if ((p.userId ?? p.user?.id ?? '') != me) continue;
    final role = p.role.toUpperCase();
    if (role == 'HOST' || role == 'CO_HOST') return null;
    return p;
  }
  return null;
}
