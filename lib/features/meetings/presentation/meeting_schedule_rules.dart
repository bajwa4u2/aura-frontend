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
///
/// A co-host ([isCoHost]) runs it too (6 Nov 2026), but may not cancel it or
/// appoint co-hosts: see [canAppointCoHosts].
bool canManageMeeting({
  required bool isHost,
  required bool canGovern,
  bool isCoHost = false,
}) =>
    isHost || canGovern || isCoHost;

/// Cancel the meeting (or the rest of its series) and appoint or remove
/// co-hosts: the host or an institution meeting manager, never a co-host.
/// Mirrors the server's assertCancelAccess / assertAppointAccess.
bool canAppointCoHosts({required bool isHost, required bool canGovern}) =>
    isHost || canGovern;

/// True when [myUserId] is a co-host of [meeting].
bool viewerIsCoHost(Meeting meeting, String myUserId) {
  final me = myUserId.trim();
  if (me.isEmpty) return false;
  return meeting.participants
      .any((p) => p.isCoHost && (p.userId ?? p.user?.id ?? '') == me);
}

/// What a participant answered, for the people who run the meeting.
String rsvpLabel(String rsvpStatus) => switch (rsvpStatus.toUpperCase()) {
      'ACCEPTED' => 'Accepted',
      'DECLINED' => 'Declined',
      _ => 'No answer yet',
    };

/// "Repeats weekly · 8 meetings in the series", from the occurrence's rule
/// (`FREQ=WEEKLY;INTERVAL=2;COUNT=8`). Null when the meeting is not in a
/// series. The server does not say WHICH occurrence this is, so no "3 of 8".
String? meetingSeriesLabel(Meeting meeting) {
  if ((meeting.seriesId ?? '').isEmpty) return null;
  final parts = <String, String>{};
  for (final part in (meeting.recurringRule ?? '').split(';')) {
    final i = part.indexOf('=');
    if (i > 0) parts[part.substring(0, i).toUpperCase()] = part.substring(i + 1);
  }
  final interval = int.tryParse(parts['INTERVAL'] ?? '') ?? 1;
  final count = int.tryParse(parts['COUNT'] ?? '');
  final kind = switch ((parts['FREQ'] ?? '').toUpperCase()) {
    'DAILY' => 'daily',
    'WEEKLY' => interval == 2 ? 'every 2 weeks' : 'weekly',
    'MONTHLY' => 'monthly',
    _ => null,
  };
  if (kind == null || count == null) return 'Part of a series';
  return 'Repeats $kind · $count meetings in the series';
}

/// The "Repeat" choices on the create form: label and server frequency.
const List<(String, String?)> kRepeatChoices = [
  ('Does not repeat', null),
  ('Daily', 'DAILY'),
  ('Weekly', 'WEEKLY'),
  ('Every 2 weeks', 'BIWEEKLY'),
  ('Monthly', 'MONTHLY'),
];

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
