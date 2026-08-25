import 'meeting.dart';
import 'meeting_room.dart';

/// THE MEETING LIFECYCLE — ONE AUTHORITY.
///
/// Founder ruling 2026-08-25 §XIII: "Do not let UI booleans, socket presence,
/// booking state, participant status, meeting record status independently
/// invent lifecycle truth."
///
/// Before this, three things answered "what is happening with this meeting":
///
///   * `Meeting.state`      — the durable record column (DRAFT…CANCELLED);
///   * `MeetingRoom.status` — a twelve-value backend projection of the live
///                            room, which knows about waiting, host presence
///                            and transport;
///   * `Meeting.isActive` / `isScheduled` / `isEnded` — getters that mixed
///     the two together, each with a slightly different idea of the answer.
///
/// `isEnded` was true when the *room* said `missed` even though the record
/// still said `SCHEDULED`; `isScheduled` was true only for a specific subset
/// of room statuses. A surface asking two of those three questions could get
/// two incompatible answers about the same meeting in the same frame.
///
/// ## The rule
///
/// The record is the SPINE. The room REFINES it. Neither is discarded, because
/// they answer different halves of one question: the record is what the
/// meeting *is*, the room is how far along it *currently* is.
///
/// The room is a fresher computation of the same underlying truth, so it may
/// move the meeting FORWARD — a record cached as SCHEDULED whose room says
/// `live` really has started. It may never move it BACKWARD, because a stale
/// or reconnecting room projection must not un-start a meeting that the record
/// says is ACTIVE.
///
///     phase = max(recordPhase, roomPhase)      // by lifecycle rank
///
/// with two exceptions that are not "later", they are *decisions*:
///
///   * CANCELLED on the record is absolute. A cancelled meeting is cancelled
///     even if a room projection is still describing a session.
///   * DRAFT on the record is absolute. An unpublished meeting has no room to
///     speak for it, and anything a room says about one is noise.
///
/// This is monotonic, total, and pure — which is why it is testable, and why
/// no surface needs to reason about it again.
enum MeetingPhase {
  /// Being configured. Not yet anybody else's business.
  draft,

  /// On the calendar, not yet joinable.
  scheduled,

  /// Joinable now — starting soon, or someone is already waiting.
  ready,

  /// In progress.
  active,

  /// Finished, and it happened.
  ended,

  /// Called off before it happened.
  cancelled,

  /// The time passed and nobody came.
  missed,

  /// The record did not say, and neither did the room. Rendered honestly
  /// rather than guessed at.
  unknown,
}

/// Lifecycle rank. Terminal phases share the top: none of them is "later"
/// than another, they are different ways of being over.
int _rank(MeetingPhase phase) => switch (phase) {
      MeetingPhase.unknown => -1,
      MeetingPhase.draft => 0,
      MeetingPhase.scheduled => 1,
      MeetingPhase.ready => 2,
      MeetingPhase.active => 3,
      MeetingPhase.ended => 4,
      MeetingPhase.cancelled => 4,
      MeetingPhase.missed => 4,
    };

/// The durable record column, alone.
MeetingPhase phaseFromRecordState(String? state) =>
    switch ((state ?? '').trim().toUpperCase()) {
      'DRAFT' => MeetingPhase.draft,
      'SCHEDULED' => MeetingPhase.scheduled,
      'ACTIVE' => MeetingPhase.active,
      'ENDED' => MeetingPhase.ended,
      'CANCELLED' => MeetingPhase.cancelled,
      _ => MeetingPhase.unknown,
    };

/// The live room projection, alone.
MeetingPhase phaseFromRoomStatus(MeetingRoomStatus? status) =>
    switch (status) {
      null => MeetingPhase.unknown,
      MeetingRoomStatus.scheduled => MeetingPhase.scheduled,
      // Starting soon, and every flavour of "someone is at the door", all mean
      // the same thing to a person: you can go in now.
      MeetingRoomStatus.startingSoon ||
      MeetingRoomStatus.waiting ||
      MeetingRoomStatus.hostWaiting ||
      MeetingRoomStatus.guestWaiting =>
        MeetingPhase.ready,
      MeetingRoomStatus.live ||
      MeetingRoomStatus.inProgress ||
      // A connection problem is a transport condition, not a lifecycle one.
      // The meeting is still happening; the A/V layer owns saying so.
      MeetingRoomStatus.connectionIssue =>
        MeetingPhase.active,
      MeetingRoomStatus.ended => MeetingPhase.ended,
      MeetingRoomStatus.missed => MeetingPhase.missed,
      MeetingRoomStatus.cancelled => MeetingPhase.cancelled,
      MeetingRoomStatus.unknown => MeetingPhase.unknown,
    };

/// THE resolver. Every surface asks this and nothing else.
MeetingPhase resolveMeetingPhase({
  required String? recordState,
  MeetingRoomStatus? roomStatus,
}) {
  final record = phaseFromRecordState(recordState);

  // Absolute record decisions — see the doc comment.
  if (record == MeetingPhase.cancelled) return MeetingPhase.cancelled;
  if (record == MeetingPhase.draft) return MeetingPhase.draft;

  final room = phaseFromRoomStatus(roomStatus);
  if (room == MeetingPhase.unknown) return record;
  if (record == MeetingPhase.unknown) return room;

  // Forward-only. A stale room may not un-start a live meeting.
  return _rank(room) > _rank(record) ? room : record;
}

/// What the workspace may offer, and who decides.
///
/// Capability is BACKEND authority — `MeetingRoom` carries `canEnter`,
/// `canStart`, `canEnd` computed against the real participant graph and the
/// real session. The client does not recompute them, because it cannot see
/// what they are computed from.
///
/// When there is no room projection at all (a record fetched without one), the
/// client answers conservatively from the phase alone rather than guessing
/// generously — offering a join that will be refused is worse than not
/// offering it yet.
class MeetingCapability {
  const MeetingCapability({
    required this.canJoin,
    required this.canStart,
    required this.canEnd,
    required this.isAuthoritative,
  });

  /// This person may enter the room now.
  final bool canJoin;

  /// This person may start the meeting (host-side).
  final bool canStart;

  /// This person may end it for everybody (host-side).
  final bool canEnd;

  /// True when these came from the backend projection. False when they were
  /// derived from the phase because no projection was present — surfaces use
  /// this to stay quiet rather than assert.
  final bool isAuthoritative;

  static const MeetingCapability none = MeetingCapability(
    canJoin: false,
    canStart: false,
    canEnd: false,
    isAuthoritative: false,
  );

  factory MeetingCapability.resolve({
    required MeetingPhase phase,
    MeetingRoom? room,
  }) {
    if (room != null) {
      return MeetingCapability(
        canJoin: room.canEnter,
        canStart: room.canStart,
        canEnd: room.canEnd,
        isAuthoritative: true,
      );
    }
    // No projection: the phase is all we have, and it only ever licenses
    // joining. Starting and ending are host acts and need real authority.
    return MeetingCapability(
      canJoin: phase == MeetingPhase.ready || phase == MeetingPhase.active,
      canStart: false,
      canEnd: false,
      isAuthoritative: false,
    );
  }
}

/// The whole lifecycle answer for one meeting, resolved once.
class MeetingLifecycle {
  const MeetingLifecycle({
    required this.phase,
    required this.capability,
    this.scheduledAt,
    this.startedAt,
    this.endedAt,
    this.durationMinutes,
  });

  final MeetingPhase phase;
  final MeetingCapability capability;
  final DateTime? scheduledAt;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final int? durationMinutes;

  factory MeetingLifecycle.of(Meeting meeting) {
    final phase = resolveMeetingPhase(
      recordState: meeting.state,
      roomStatus: meeting.room?.status,
    );
    return MeetingLifecycle(
      phase: phase,
      capability:
          MeetingCapability.resolve(phase: phase, room: meeting.room),
      scheduledAt: meeting.scheduledAt ?? meeting.room?.scheduledStartAt,
      startedAt: meeting.room?.actualStartedAt,
      endedAt: meeting.room?.actualEndedAt,
      durationMinutes: meeting.durationMinutes,
    );
  }

  bool get isDraft => phase == MeetingPhase.draft;
  bool get isUpcoming => phase == MeetingPhase.scheduled;
  bool get isReady => phase == MeetingPhase.ready;
  bool get isActive => phase == MeetingPhase.active;

  /// Over, however it ended.
  bool get isConcluded =>
      phase == MeetingPhase.ended ||
      phase == MeetingPhase.cancelled ||
      phase == MeetingPhase.missed;

  /// It happened and it is over — the only phase with something to look back
  /// at. A cancelled meeting has no record of what occurred, because nothing
  /// did.
  bool get hasAftermath => phase == MeetingPhase.ended;

  /// Whether the room is worth reaching for at all.
  bool get isLiveSurface =>
      phase == MeetingPhase.ready || phase == MeetingPhase.active;
}
