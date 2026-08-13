/// Realtime Architecture Correction — Runtime Lifecycle Phase 2 fix
/// (Founder Acceptance Register domain 5, Runtime Lifecycle / Attention
/// Coherence).
///
/// `findOrphanedActiveSession` is a pure, already-proven reconciliation
/// between backend truth (`mySessions`) and this process's in-memory
/// `RealtimeState` — that logic was never wrong. The founder-observed
/// defect ("dismiss the banner, reopen the browser, it's back") traced to
/// `OrphanedSessionBanner` keeping its `_dismissed` set in `State`, which
/// is destroyed on every reload/relaunch. A session that is still
/// genuinely active on the backend (correctly) resurfaces as orphaned on
/// the next cold start, because nothing remembered the user already
/// dismissed it — a missing governed lifecycle for dismissal, not a
/// session-truth bug. Doctrine: dismissal must never mutate canonical
/// session truth (nothing here calls the backend), but canonical truth
/// must not force the overlay to recreate indefinitely either.
///
/// Persisted per session id, never "dismissed forever" — a *new* call
/// still banners normally; only the exact session already seen and
/// dismissed is suppressed. `markDismissed` prunes against the caller's
/// current `mySessions` snapshot on every write, so the stored set can
/// never grow past however many sessions are simultaneously active —
/// once a session ends it drops out of `mySessions` and its dismissal
/// marker is pruned on the very next dismiss.
library;

import 'package:shared_preferences/shared_preferences.dart';

class OrphanedSessionDismissalCache {
  OrphanedSessionDismissalCache._();

  static const String _key = 'aura.realtime.orphanedDismissed';

  static Future<Set<String>> read() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_key) ?? const <String>[]).toSet();
  }

  static Future<void> markDismissed(
    String sessionId, {
    required Set<String> stillActiveIds,
  }) async {
    final id = sessionId.trim();
    if (id.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final current = await read();
    final next = {...current, id}..retainWhere(stillActiveIds.contains);
    await prefs.setStringList(_key, next.toList());
  }
}
