import 'dart:async';

/// ONE MUTATION AT A TIME, PER OWNER.
///
/// Founder ruling, 2026-08-26: product events may be concurrent, but SFU
/// negotiation mutations must be serialized per transport. This is the
/// mechanism, and it is deliberately its own class so the two properties that
/// matter can be tested without a peer connection, a network or a provider.
///
/// The properties:
///
///  * operations run in submission order, never overlapping;
///  * a failed operation surfaces its error to ITS caller and does not wedge
///    the queue — the next operation still runs.
///
/// The second is the one that bites. The obvious implementation chains onto
/// the previous future, and a rejected future poisons every continuation after
/// it, so a single transient refusal silently disables the transport for the
/// rest of the call.
///
/// This is ordering, not timing. There is deliberately no delay, debounce or
/// retry here — those hide state-machine mistakes rather than fixing them.
class SerialQueue {
  Future<void> _tail = Future<void>.value();
  bool _closed = false;

  /// Whether the owner has been torn down. Queued work is dropped after this.
  bool get isClosed => _closed;

  /// Run [action] after everything already queued.
  ///
  /// The returned future completes with [action]'s result or error. The
  /// internal chain always completes successfully, which is what keeps one
  /// failure from cancelling the work behind it.
  Future<T> run<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _tail = _tail.then((_) async {
      if (_closed) {
        // Teardown must not leave queued work mutating a disposed session.
        completer.completeError(
          StateError('queue closed [queue:closed]'),
          StackTrace.current,
        );
        return;
      }
      try {
        completer.complete(await action());
      } catch (error, stack) {
        completer.completeError(error, stack);
      }
    });
    return completer.future;
  }

  /// Stop accepting work. Anything already queued but not started is dropped.
  void close() => _closed = true;
}
