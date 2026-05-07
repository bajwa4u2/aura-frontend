/// Public-UX Phase 6 — frontend-only "last seen" tracking for post
/// threads (user posts AND institution posts).
///
/// The backend has `markSeen` for *direct* threads only. Post threads
/// don't have an equivalent — and adding one would require new
/// per-(user, post) state on the server. For Phase 6 we keep this
/// purely client-side: the cache lives in SharedPreferences keyed by
/// `aura.thread.lastSeen:{postId}`, stores an ISO timestamp, and is
/// updated on screen exit.
///
/// On screen entry, the thread reads the existing value, renders a
/// "New since you last visited" divider before any reply newer than
/// it, and writes the *current* time on dispose so the next visit
/// has a fresh baseline.
library;

import 'package:shared_preferences/shared_preferences.dart';

const String _kPrefix = 'aura.thread.lastSeen:';

class ThreadLastSeenCache {
  ThreadLastSeenCache._();

  static Future<DateTime?> read(String postId) async {
    final id = postId.trim();
    if (id.isEmpty) return null;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_kPrefix$id');
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  static Future<void> markSeenNow(String postId) async {
    final id = postId.trim();
    if (id.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_kPrefix$id',
      DateTime.now().toUtc().toIso8601String(),
    );
  }
}
