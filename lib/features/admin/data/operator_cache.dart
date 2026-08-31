/// HOW LONG A READING STAYS GOOD.
///
/// PERFORMANCE IS PRODUCT, and the console's transition cost was structural
/// rather than cosmetic. Every shared read — the operator's own authority, the
/// worklist, platform health — is `autoDispose`. Moving from NOW to WORK
/// disposes them, and arriving at WORK issues the same requests again.
///
/// Those two areas SHOW THE SAME NUMBERS. The worklist an operator just read
/// on NOW is the worklist WORK is about to list, seconds later, and the
/// console was throwing it away in between and then drawing a skeleton while
/// it fetched the identical answer. An operator moving back and forth pays
/// that on every step.
///
/// So a reading survives a short while after nothing is watching it. The
/// window is deliberately SHORT: this is a console for looking at live
/// governed state, and a stale answer presented as current is a worse failure
/// than a slow one. Long enough to cross a navigation, never long enough to
/// be wrong about a queue.
///
/// WHAT THIS IS NOT. Not a general cache, and not a substitute for the
/// coordinator's refresh tick — a surface left open still refreshes on its own
/// cadence. This only stops the console re-asking a question it asked two
/// seconds ago.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// How long a shared operator reading outlives its last listener.
///
/// Roughly one navigation, not one session. An operator who leaves the console
/// and returns a minute later gets a fresh read, which is the honest default
/// for state that other people are changing while they are away.
const Duration kOperatorReadingLifetime = Duration(seconds: 20);

/// Keeps [ref]'s provider alive for [lifetime] after its last listener leaves.
///
/// Cancels on dispose, so a provider invalidated by an operator ACTION (a
/// grant revoked, a report resolved) is discarded immediately rather than
/// serving the answer from before the decision.
void cacheOperatorReading(
  Ref ref, {
  Duration lifetime = kOperatorReadingLifetime,
}) {
  final link = ref.keepAlive();
  Timer? release;

  ref.onDispose(() => release?.cancel());

  // A listener arriving before the timer fires means the reading is in use
  // again; the timer is restarted rather than cleared, so the window is always
  // measured from the LAST time somebody looked.
  ref.onCancel(() {
    release?.cancel();
    release = Timer(lifetime, link.close);
  });

  ref.onResume(() => release?.cancel());
}
