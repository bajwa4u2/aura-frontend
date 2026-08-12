import 'dart:async';

/// Ensures at most one asynchronous operation runs at a time for a given
/// instance — a concurrent caller that arrives while one is already in
/// flight awaits that SAME operation instead of starting a competing one.
///
/// 2026-08-14 — extracted from the realtime transport-ownership repair.
/// The proven defect it replaces: two independent code paths each had
/// their own "is something already happening?" guard, using different,
/// desyncable signals (a Riverpod state field in one place, a raw
/// `Future<void>?` field in another). Both guards could be bypassed by a
/// concurrent caller, and — combined with `Future.timeout()` not actually
/// cancelling an abandoned attempt — two callers ended up independently
/// tearing down and recreating a shared realtime socket, each destroying
/// the other's in-progress connection before it could stabilize.
///
/// A boolean guard cannot be awaited by a second caller, which is exactly
/// the gap that let this happen. `SingleFlight` closes it structurally:
/// there is exactly one [Completer] per in-flight operation, and every
/// caller — first or Nth — awaits that same completer.
class SingleFlight<T> {
  Completer<T>? _inFlight;

  /// True while an operation started by [run] has not yet settled.
  bool get isInFlight => _inFlight != null;

  /// Runs [operation] if nothing is currently in flight; otherwise awaits
  /// the already-in-flight operation and returns its result (or rethrows
  /// its error) without starting a second one.
  Future<T> run(Future<T> Function() operation) {
    final existing = _inFlight;
    if (existing != null) {
      return existing.future;
    }

    final completer = Completer<T>();
    _inFlight = completer;

    Future<void> runAndSettle() async {
      try {
        final value = await operation();
        if (!completer.isCompleted) completer.complete(value);
      } catch (error, stackTrace) {
        if (!completer.isCompleted) completer.completeError(error, stackTrace);
      } finally {
        // Only clear if we're still the current slot — a caller may have
        // already aborted us (see abort()), which already cleared it.
        if (identical(_inFlight, completer)) {
          _inFlight = null;
        }
      }
    }

    unawaited(runAndSettle());
    return completer.future;
  }

  /// Fails any current waiters with [error] and frees the slot so a new
  /// [run] can start fresh — for intentional teardown (e.g. explicit
  /// disconnect/dispose) where waiters must not hang forever on an
  /// operation that is being deliberately abandoned. Cannot cancel the
  /// underlying Future itself (Dart has no such primitive); it only stops
  /// making callers wait for its result.
  void abort(Object error, [StackTrace? stackTrace]) {
    final existing = _inFlight;
    _inFlight = null;
    if (existing != null && !existing.isCompleted) {
      existing.completeError(error, stackTrace ?? StackTrace.current);
    }
  }
}
