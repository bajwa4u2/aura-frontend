import 'realtime_models.dart';
import 'realtime_state.dart';

/// Realtime Architecture Correction — Runtime Lifecycle Phase 2.
///
/// Stage 1 (`ThreadCallLifecycleController`/`RealtimeController`) already
/// keeps a live session's transport reconnected and its floating
/// return-to-call UI visible across navigation and app-resume, for every
/// surface (Thread/DM/Space/Meeting alike) — that machinery is shared and
/// already surface-agnostic, confirmed by reading `RealtimeController`'s
/// app-resume handling and the floating-call widget's mount point, both of
/// which key off `state.isJoined` with no surface-type branch.
///
/// What none of that covers: a full process kill + relaunch (not a mere
/// background/resume — the Dart VM and every in-memory `RealtimeController`
/// field are gone). On a fresh process, `RealtimeState` starts at
/// `RealtimeState.initial()` with no awareness that the backend still holds
/// this user as an ACTIVE/JOINING participant on some session — nothing
/// re-derives that awareness from the one source that still has it: the
/// user's own session list (`GET /realtime/sessions?scope=me`, the same
/// backend query already used for `liveSessionsProvider`).
///
/// This function is that missing derivation — a pure comparison between
/// what the backend says (`mySessions`, ACTIVE/JOINING participant rows for
/// the current user) and what the client currently knows about
/// (`RealtimeState`). It does not decide UI, does not auto-join, and does
/// not touch any surface-specific policy — callers route the result through
/// the existing `/realtime/:id?action=join` path, identical to every other
/// entry point into a session.
RealtimeSession? findOrphanedActiveSession({
  required List<RealtimeSession> mySessions,
  required RealtimeState clientState,
}) {
  final trackedSessionId =
      (clientState.session?.id ?? clientState.sessionId ?? '').trim();
  final clientKnowsAboutIt =
      clientState.isJoined && trackedSessionId.isNotEmpty;

  for (final session in mySessions) {
    if (!session.isActive) continue;
    if (clientKnowsAboutIt && session.id.trim() == trackedSessionId) {
      continue;
    }
    return session;
  }
  return null;
}
