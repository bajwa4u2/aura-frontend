import 'package:flutter/foundation.dart';

import 'call_participant.dart';

/// THE ROSTER — one canonical identity renders once, in every product.
///
/// Founder ruling, *Call Presentation Authority*. This is the shared answer to
/// "who is in this call and in what order", so a thread room, a meeting room,
/// an institution room and a future Live surface cannot disagree about it.
///
/// It replaces two independent implementations that already had:
///
/// * a full-roster path with no identity dedupe at all — a re-join therefore
///   seated the same human twice, founder-observed 2026-08-25;
/// * a single-participant merge that appended anything it could not match,
///   seating a participant nobody could name.
///
/// The rule it enforces is the one the rest of Aura already asserts —
/// `@@unique([sessionId, userId])` in the database, presence keyed by
/// `(sessionId, userId)` with device ids held as a Set *inside* one record,
/// replaced sockets disconnected by the gateway, and mid-call device handoff
/// modelled as a TRANSFER rather than a second seat.
@immutable
class CallRoster {
  const CallRoster(this.participants);

  static const CallRoster empty = CallRoster(<CallParticipant>[]);

  final List<CallParticipant> participants;

  /// Everyone who is not the local person, in seat order.
  List<CallParticipant> get others =>
      participants.where((p) => !p.isSelf).toList(growable: false);

  CallParticipant? get self {
    for (final p in participants) {
      if (p.isSelf) return p;
    }
    return null;
  }

  /// How many humans are in the call. Counts seats, never transports — which
  /// is the distinction the duplicate-participant defect blurred.
  int get presentCount => participants.where((p) => p.isPresent).length;

  bool get isAlone => others.where((p) => p.isPresent).isEmpty;

  /// Build a roster from entries that may repeat a human.
  ///
  /// * Entries sharing a seat collapse to one; **the last wins**, because the
  ///   newest binding carries the live transport and media state.
  /// * The seat keeps the position of its FIRST appearance, so the roster does
  ///   not reshuffle under the people reading it.
  /// * An entry with no identifying information at all is kept rather than
  ///   merged — merging unidentified entries combines strangers.
  factory CallRoster.converge(Iterable<CallParticipant> entries) {
    final index = <String, int>{};
    final out = <CallParticipant>[];

    for (final entry in entries) {
      final seat = entry.seatId.trim();
      if (seat.isEmpty) {
        out.add(entry);
        continue;
      }
      final at = index[seat];
      if (at == null) {
        index[seat] = out.length;
        out.add(entry);
      } else {
        out[at] = entry;
      }
    }

    return CallRoster(List<CallParticipant>.unmodifiable(out));
  }

  @override
  String toString() =>
      'CallRoster(${participants.length} seats: ${participants.map((p) => p.displayName).join(', ')})';
}
