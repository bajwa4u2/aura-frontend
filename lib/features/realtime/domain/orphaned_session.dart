import 'realtime_models.dart';
import 'realtime_state.dart';

/// Realtime Architecture Correction — Runtime Lifecycle Phase 2, corrected
/// 2026-08-17 after live founder evidence.
///
/// Original defect set this correction addresses (all observed on
/// production during the three-party certification night):
///
/// 1. The comparison only excluded a session the client was fully JOINED
///    to. During initiation, ring-accept, transport establishment, and the
///    "Ready to join" screen, the user's OWN in-progress call was
///    classified as orphaned — so the "You have an active call /
///    Dismiss / Rejoin" banner rendered on top of the very call screen the
///    user was on ("on call initiation and accepting side starting mess").
///    Fix: exclude the session the client is engaged with at ANY stage —
///    `RealtimeState.sessionId` is set from the first join attempt, not
///    only after join completes.
///
/// 2. A session the user was merely INVITED to (never joined —
///    `joinedAt == null`) offered "Rejoin". There is nothing to re-join;
///    ringing is the incoming-call pipeline's job, and a stale never-
///    answered invite must not masquerade as "your active call" (the
///    review account carried such a banner for hours from someone else's
///    stale session). Fix: only sessions this user actually joined
///    (`joinedAt != null`) qualify.
///
/// 3. A session the user explicitly LEFT re-bannered while the session
///    stayed active for others (group semantics). Leaving is an answered
///    question, not an orphaned state. Fix: joinState LEFT never banners.
///    (Process-kill recovery still works: until the server heartbeat
///    reaper marks the dead device LEFT, the row remains ACTIVE and the
///    banner correctly offers Rejoin — the immediate-reopen window this
///    surface exists for.)
///
/// Still deliberately does not auto-join, and still routes through the
/// same `/realtime/:id?action=join` entry point.
RealtimeSession? findOrphanedActiveSession({
  required List<RealtimeSession> mySessions,
  required RealtimeState clientState,
  required String currentUserId,
}) {
  final engagedSessionId =
      (clientState.sessionId ?? clientState.session?.id ?? '').trim();

  for (final session in mySessions) {
    if (!session.isActive) continue;
    // Engaged at ANY stage (connecting / ready / joined) — the call
    // surface owns this session's presentation, never the banner.
    if (engagedSessionId.isNotEmpty &&
        session.id.trim() == engagedSessionId) {
      continue;
    }
    final me = session.participantOf(currentUserId);
    // No roster row or payload without participants: cannot prove the
    // user was ever in this call — never claim "you have an active call".
    if (me == null) continue;
    if (me.joinedAt == null) continue; // invited, never joined
    final js = me.joinState;
    if (js == 'LEFT') continue; // explicitly left / reaped — answered
    return session;
  }
  return null;
}
