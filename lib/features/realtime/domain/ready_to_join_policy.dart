/// F044 — WHEN IS "READY TO JOIN" A TRUTHFUL THING TO SAY?
///
/// The surface reading "Ready to join / Tap Join call to enter" is an
/// INSTRUCTION. It tells a person there is an action left for them to perform.
/// It is only honest when that is true.
///
/// ─────────────────────────────────────────────────────────────────────────
/// THE DEFECT IT EXISTS TO PREVENT
/// ─────────────────────────────────────────────────────────────────────────
///
/// The instruction was being shown in two states where the person had nothing
/// left to do:
///
///   POST-ACCEPT   Someone accepts an incoming call. The room mounts, and the
///                 join is issued from a post-frame callback — so the FIRST
///                 FRAME paints while `joinState` is still `idle`, and the
///                 idle presentation is "tap Join call to enter". The person
///                 who just accepted is told to accept again. It clears itself
///                 a frame later, which is why it reads as a flash: the
///                 founder's word for it was a "mediator", something that
///                 comes and goes between accepting and being in the call.
///
///   POST-END      A call ends and `joinState` returns to `idle`. Until the
///                 canonical session state catches up, the same idle
///                 presentation offers to join a call that is over.
///
/// Both are the same mistake: treating `joinState == idle` as "this person has
/// not asked to join", when idle also covers "has asked, and it is in flight"
/// and "it already finished".
///
/// ─────────────────────────────────────────────────────────────────────────
/// WHAT THIS DELIBERATELY DOES NOT DO
/// ─────────────────────────────────────────────────────────────────────────
///
/// It does not collapse RINGING → ACCEPTED → JOINING → CONNECTED. Those remain
/// distinct lifecycle states and none is removed, merged or short-circuited.
/// The repair is entirely about PRESENTATION RELATIVE TO LIFECYCLE: which
/// sentence is truthful in a state, not which states exist.
///
/// It is also not a timing hack. Hiding the widget for N milliseconds would
/// have made the flash less visible while leaving the presentation rule wrong,
/// and the same wrongness would resurface anywhere else the idle state is
/// rendered. The predicate below is the authority, and it is a pure function
/// so it can be proven rather than eyeballed.
library;

import 'realtime_enums.dart';

/// Whether an explicit Join instruction is truthful for this viewer.
///
/// [joinState] is the canonical lifecycle position. [joinIntentInFlight] is
/// true once the viewer has expressed intent to be in the call — accepting an
/// incoming call, or arriving on an `action=join` / `action=resume` address —
/// and before that intent has resolved. [sessionIsActive] is the canonical
/// session's own truth: `null` when not yet known, which is treated as "do not
/// instruct", because inventing an actionable join for a session we cannot
/// describe is precisely the post-end symptom.
bool readyToJoinIsTruthful({
  required RealtimeJoinState joinState,
  required bool joinIntentInFlight,
  required bool? sessionIsActive,
  bool isBusy = false,
  bool isRecovering = false,
}) {
  // A DROPPED CONNECTION IS NOT AN INVITATION TO JOIN.
  //
  // Founder-photographed 2026-08-28: mid-call, with the network pulled, the
  // room offered "Ready to join / Tap Join call to enter" -- for a call the
  // person was ALREADY IN, that the server was still holding, and that the
  // client was in the middle of rejoining on its own.
  //
  // The predicate reached that conclusion honestly from what it was given:
  // joinState falls to idle when a transport drops, the session really is
  // active, and no join was in flight. Every input was correct and the
  // answer was wrong, because the one fact that mattered was missing --
  // whether this idle is a person who has not joined, or a person whose
  // connection broke. Those need opposite sentences, and only one of them
  // has a Join button.
  if (isRecovering) return false;

  // Intent already expressed: whatever the lifecycle says this instant, the
  // person is not waiting to be told to join.
  if (joinIntentInFlight) return false;

  // Work is under way. "Connecting…" is the honest sentence here.
  if (isBusy) return false;

  // Anything other than idle has its own truthful presentation — joining,
  // joined, waiting for approval, declined, removed, locked, replaced, failed.
  if (joinState != RealtimeJoinState.idle) return false;

  // Idle, and the session is over or not yet known. Offering to join it would
  // be an instruction to do something impossible.
  if (sessionIsActive != true) return false;

  return true;
}
