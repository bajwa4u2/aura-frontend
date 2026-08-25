/// WHAT "LIVE" MEANS IN AURA, AND WHAT IT DOES NOT.
///
/// Founder ruling 2026-08-25, R-1 and §XXVIII:
///
///     LIVE_BROADCAST_SYSTEM = NOT_CURRENTLY_ESTABLISHED
///
/// and, in as many words: *do not let naming define architecture*.
///
/// The Meetings audit found no Live Broadcast system anywhere in the product —
/// no `lib/features/live/`, no `src/live/`. What it found instead was one word
/// doing three unrelated jobs, in a codebase where a later chapter is going to
/// arrive looking for "Live" and find 240 matches.
///
/// This file exists so that chapter finds a classification instead of a guess.
/// It renames nothing: routes in the world stay addressable, and renaming a
/// live route to prove a point would break links to prove a point. It states
/// the boundary and lets a test hold it.
///
/// ─────────────────────────────────────────────────────────────────────────
/// THE THREE THINGS CALLED LIVE
/// ─────────────────────────────────────────────────────────────────────────
///
/// **1. An active meeting.** `/meetings/:id/live` and its institution mirror.
/// `MeetingLiveRoomScreen` is the A/V presentation of a Meeting, and is
/// Meetings-plus-A/V, not Live. It is the largest population of the word and
/// the most misleading, because the screen's NAME is the only reason anyone
/// would think Aura has a Live system.
///
/// **2. An institution live room.** `/institution/:id/live-rooms`, living in
/// `features/institutions/live_rooms/`. A legacy institution capability for
/// ad-hoc rooms. It predates this vocabulary and is not a broadcast: it is a
/// list of rooms people can be in.
///
/// **3. A discovery indicator.** The "LIVE NOW" banner on Explore and the
/// rail. Presentation over the same data as (2) — it announces that something
/// is happening, and owns nothing.
///
/// **4. Live Broadcast.** Does not exist. When it is built it will be its own
/// chapter, and none of the above becomes it by inheritance.
library;

/// Which of the four a path or symbol belongs to.
enum LiveMeaning {
  /// The A/V room of a meeting. Meetings + A/V, never Live.
  activeMeeting,

  /// The legacy institution live-room capability.
  institutionLiveRoom,

  /// A discovery indicator over institution live rooms.
  discoveryIndicator,

  /// Reserved. Nothing in the product is this yet, and nothing should claim
  /// to be until the Live chapter says so.
  liveBroadcast,

  /// The English word, used for something else entirely — a `liveRegion` in
  /// accessibility, a meeting's `liveNotes`.
  unrelated,
}

/// Classify a route path by which system it actually belongs to.
///
/// Deliberately total and deliberately narrow: anything that is not one of the
/// three known populations is [LiveMeaning.unrelated] rather than being
/// guessed into the Live chapter.
LiveMeaning classifyLivePath(String path) {
  final p = path.trim().toLowerCase();
  if (RegExp(r'^/meetings/[^/]+/live(/|$)').hasMatch(p) ||
      RegExp(r'^/institution/[^/]+/meetings/[^/]+/live(/|$)').hasMatch(p)) {
    return LiveMeaning.activeMeeting;
  }
  if (RegExp(r'live-rooms(/|$)').hasMatch(p)) {
    return LiveMeaning.institutionLiveRoom;
  }
  return LiveMeaning.unrelated;
}

/// True when a path belongs to a system this chapter must not reconstruct.
///
/// The Meetings chapter may establish the A/V boundary and must leave the A/V
/// implementation, and Live, to their own chapters.
bool isDeferredLiveSystem(String path) =>
    classifyLivePath(path) == LiveMeaning.institutionLiveRoom;
