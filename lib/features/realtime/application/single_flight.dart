import 'dart:async';

/// ONE OPERATION, HOWEVER MANY CALLERS ASK FOR ONE.
///
/// Built for the media boundary after a production root cause on 2026-09-07:
/// `_ensureStageConnected` tested `_stage == null`, then awaited a server round
/// trip and a full SDP negotiation before `_stage` was finally set. Any trigger
/// arriving in that window passed the same test and opened a second transport.
/// Nine call sites reach that path and several are unawaited, so transports
/// were created 2 and 3 seconds apart, five healthy ones were destroyed in
/// forty seconds, and every peer subscription to the discarded provider
/// sessions failed with 410 Gone.
///
/// The defect is not that callers ask too often — they have legitimate reasons
/// to ask. It is that asking twice produced two operations. Ownership must be
/// claimed BEFORE the first await, which is precisely what a check-then-act
/// cannot do.
///
/// Deliberately a separate, tested unit rather than a flag inside the
/// controller: a tenth caller will be added one day, and the boundary must be
/// safe by construction rather than by everyone remembering.
class SingleFlight {
  Future<void>? _inFlight;

  /// True while an operation is running. Presence, not health.
  bool get isRunning => _inFlight != null;

  /// Run [operation], or join the one already running.
  ///
  /// [onJoin] fires only for callers that joined an existing operation, so the
  /// join can be observed — a race that is invisible cannot be told from a
  /// system that never raced.
  Future<void> run(Future<void> Function() operation, {void Function()? onJoin}) {
    final existing = _inFlight;
    if (existing != null) {
      onJoin?.call();
      // Joiners await the SAME future, so they finish when the real operation
      // finishes. They must not see its error as their own failure to start —
      // it already failed once and was reported once.
      return existing.catchError((_) {});
    }

    // The future is stored BEFORE it is awaited anywhere, which is the whole
    // point: the window between deciding to act and acting is the race.
    late final Future<void> started;
    started = Future<void>.sync(operation).whenComplete(() {
      if (identical(_inFlight, started)) _inFlight = null;
    });
    _inFlight = started;
    return started;
  }
}
