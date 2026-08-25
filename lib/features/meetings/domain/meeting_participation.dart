import 'meeting.dart';
import 'meeting_lifecycle.dart';

/// PARTICIPATION — ONE COHERENT MODEL.
///
/// Founder ruling 2026-08-25 §XVI: make invitation and participation states
/// explicit and understandable; do not encode presentation phrases as domain
/// states.
///
/// Two questions are genuinely separate and were previously answered by one
/// tangle of strings and booleans:
///
///   * **Has this person answered the invitation?** — an intention, decided
///     before the meeting, durable.
///   * **Where are they right now?** — a fact about this instant.
///
/// Somebody can have accepted and not turned up; somebody can have never
/// answered and be standing in the room. Collapsing the two loses real
/// information, so they stay apart.

/// Did they answer, and what did they say.
enum MeetingInvitation {
  /// Invited, has not answered yet.
  ///
  /// R-2 (founder ruling 2026-08-25): `PENDING` is the one canonical name for
  /// this. The schema also carries `NO_RESPONSE`, which **no code has ever
  /// written** — see [MeetingAttendance.wasNoShow] for what it was reaching
  /// for and how that is answered properly.
  awaiting,

  accepted,
  declined,

  /// Nobody invited them; they arrived through a public or guest door.
  notInvited,
}

/// Where they are, right now.
enum MeetingPresence {
  /// Not here, and not trying to be.
  away,

  /// At the door, waiting to be let in.
  knocking,

  /// Let in, not yet connected.
  admitted,

  /// Here.
  present,

  /// Was here; the connection dropped. Distinct from having left, because
  /// the product should hold their place.
  disconnected,

  /// Was here, and went.
  departed,

  /// Removed by a host.
  removed,
}

/// What this person is responsible for.
enum MeetingRole { host, coHost, participant, guest }

MeetingRole meetingRoleFromString(String? raw) =>
    switch ((raw ?? '').trim().toUpperCase()) {
      'HOST' => MeetingRole.host,
      'CO_HOST' || 'COHOST' => MeetingRole.coHost,
      'GUEST' => MeetingRole.guest,
      _ => MeetingRole.participant,
    };

MeetingInvitation meetingInvitationFromString(String? raw) =>
    switch ((raw ?? '').trim().toUpperCase()) {
      'ACCEPTED' => MeetingInvitation.accepted,
      'DECLINED' => MeetingInvitation.declined,
      // R-2: the legacy value converges here rather than surviving as a second
      // canonical name for the same thing.
      'PENDING' || 'NO_RESPONSE' => MeetingInvitation.awaiting,
      _ => MeetingInvitation.notInvited,
    };

/// What actually happened, as opposed to what was intended.
class MeetingAttendance {
  const MeetingAttendance({
    required this.invitation,
    required this.presence,
    required this.role,
    this.joinedAt,
    this.leftAt,
    this.attended = false,
  });

  final MeetingInvitation invitation;
  final MeetingPresence presence;
  final MeetingRole role;
  final DateTime? joinedAt;
  final DateTime? leftAt;
  final bool attended;

  bool get isHost => role == MeetingRole.host || role == MeetingRole.coHost;

  /// Time in the room, when both ends are known.
  Duration? get timeInMeeting {
    final start = joinedAt;
    final end = leftAt;
    if (start == null || end == null) return null;
    final span = end.difference(start);
    return span.isNegative ? null : span;
  }

  /// DID NOT SHOW UP — and this is the R-2 repair.
  ///
  /// The backend counted no-shows by filtering `rsvpStatus === "NO_RESPONSE"`,
  /// a value nothing in the codebase has ever written. That count was
  /// therefore always zero, in every attendance snapshot ever generated. It
  /// looked like a feature and was a constant.
  ///
  /// A no-show is not a stored state at all — it is a fact that becomes true
  /// only once the meeting is over: they were expected, they did not decline,
  /// and they never came. So it is derived, from the meeting's own phase.
  bool wasNoShow(MeetingPhase phase) {
    if (phase != MeetingPhase.ended && phase != MeetingPhase.missed) {
      return false;
    }
    if (attended || joinedAt != null) return false;
    return invitation == MeetingInvitation.accepted ||
        invitation == MeetingInvitation.awaiting;
  }

  /// Read a participant row into the canonical model.
  ///
  /// Presence is derived rather than stored: the row carries `joinedAt`,
  /// `leftAt` and `attended`, and those three answer the question between
  /// them. `admissionState` refines it when the backend supplied one.
  factory MeetingAttendance.of(
    MeetingParticipant participant, {
    String? admissionState,
  }) {
    final invitation = meetingInvitationFromString(participant.rsvpStatus);
    final role = meetingRoleFromString(participant.role);
    final admission = (admissionState ?? '').trim().toUpperCase();

    final MeetingPresence presence;
    if (admission == 'REMOVED' || admission == 'DENIED') {
      presence = MeetingPresence.removed;
    } else if (participant.leftAt != null) {
      presence = MeetingPresence.departed;
    } else if (participant.joinedAt != null) {
      presence = MeetingPresence.present;
    } else if (admission == 'PENDING') {
      presence = MeetingPresence.knocking;
    } else if (admission == 'ADMITTED' || admission == 'APPROVED') {
      presence = MeetingPresence.admitted;
    } else {
      presence = MeetingPresence.away;
    }

    return MeetingAttendance(
      invitation: invitation,
      presence: presence,
      role: role,
      joinedAt: participant.joinedAt,
      leftAt: participant.leftAt,
      attended: participant.attended,
    );
  }
}

/// A roster question surfaces ask constantly, answered once.
class MeetingRoster {
  const MeetingRoster(this._entries);

  final List<MeetingAttendance> _entries;

  factory MeetingRoster.of(Meeting meeting) => MeetingRoster(
        meeting.participants.map(MeetingAttendance.of).toList(growable: false),
      );

  List<MeetingAttendance> get all => List.unmodifiable(_entries);

  int get invited => _entries
      .where((e) => e.invitation != MeetingInvitation.notInvited)
      .length;

  int get accepted =>
      _entries.where((e) => e.invitation == MeetingInvitation.accepted).length;

  int get declined =>
      _entries.where((e) => e.invitation == MeetingInvitation.declined).length;

  int get awaiting =>
      _entries.where((e) => e.invitation == MeetingInvitation.awaiting).length;

  int get present =>
      _entries.where((e) => e.presence == MeetingPresence.present).length;

  int get knocking =>
      _entries.where((e) => e.presence == MeetingPresence.knocking).length;

  int get attended => _entries.where((e) => e.attended).length;

  int noShows(MeetingPhase phase) =>
      _entries.where((e) => e.wasNoShow(phase)).length;

  Iterable<MeetingAttendance> get hosts => _entries.where((e) => e.isHost);
}
