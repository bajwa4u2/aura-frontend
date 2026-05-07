/// Phase 2 Distribution — global discovery surface for institutional
/// live sessions.
///
/// Backend reality:
///   * `liveSessionsProvider` calls `/realtime/sessions?scope=me`, which
///     returns sessions the viewer is a participant or member of. This
///     is NOT a true cross-institution global feed — sessions in
///     institutions the viewer doesn't belong to will not appear.
///   * `RealtimeSession` has no `audience` field. Audience is captured
///     and cached frontend-only via `InsSessionMetaCache`.
///
/// What this file provides:
///   * `globalDiscoverableLiveProvider` — wraps the existing
///     `discoverableLiveSessionsProvider`, narrows to institution
///     sessions, and merges in cached audience/title where the local
///     device has it. Sessions without cached meta are still surfaced
///     because they pass the discoverable filter (active + ≥2
///     participants), and the contract says "fallback: generic live
///     card".
///   * `LiveNowDiscoveryEntry` — a small DTO carrying just the bits the
///     UI cards + banner need.
///
/// The provider degrades silently to an empty list when:
///   * the user is not authenticated,
///   * the realtime endpoint fails,
///   * no sessions are active.
///
/// All consumers must treat the empty case as "render nothing".
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../realtime/application/realtime_providers.dart';
import '../../realtime/domain/realtime_enums.dart';
import '../../realtime/domain/realtime_models.dart';
import 'institution_session_meta.dart';

/// One discoverable live entry — a `RealtimeSession` paired with the
/// best-effort frontend audience metadata for its session id.
class LiveNowDiscoveryEntry {
  const LiveNowDiscoveryEntry({
    required this.session,
    required this.meta,
  });

  final RealtimeSession session;

  /// May be null when the session was started on another device or
  /// before the meta cache existed. UI must degrade gracefully.
  final InsSessionMeta? meta;

  String get sessionId => session.id;

  /// True when we have explicit confirmation this is a public-audience
  /// session. False when meta is missing OR audience is internal.
  /// Callers that want "show only public" must use this getter; callers
  /// that want "show every active institutional broadcast we can see"
  /// can read the session directly.
  bool get isExplicitlyPublic =>
      meta?.audience == InsSessionAudience.publicAudience;

  /// True when meta is missing entirely — useful for callers that want
  /// to skip "audience-unknown" entries from the more aggressive
  /// banner surface but include them in the gentler feed-card surface.
  bool get hasNoMeta => meta == null;

  /// Resolved display title: prefers the host-provided session title
  /// from cached meta, falls back to the type label, then to the
  /// session's server-side title, then to a generic string.
  String get displayTitle {
    final cached = meta?.title?.trim() ?? '';
    if (cached.isNotEmpty) return cached;
    if (meta != null) return meta!.type.label;
    final server = session.title?.trim() ?? '';
    if (server.isNotEmpty) return server;
    return 'Live session';
  }

  /// Eyebrow label: `[TYPE] • [Audience]` when meta is known, otherwise
  /// a generic `LIVE SESSION` so the card still reads as institutional.
  String get eyebrow {
    final m = meta;
    if (m == null) return 'LIVE SESSION';
    return '${m.type.label.toUpperCase()} • ${m.audience.label}';
  }
}

/// Discoverable institutional live sessions with frontend audience meta
/// merged in. Returns at most 3 entries (the upstream provider's cap).
final globalDiscoverableLiveProvider =
    FutureProvider<List<LiveNowDiscoveryEntry>>((ref) async {
  final base = await ref.watch(discoverableLiveSessionsProvider.future);
  final institutionOnly = base
      .where((s) => s.surfaceType == RealtimeSurfaceType.institution)
      .toList();
  if (institutionOnly.isEmpty) return const [];

  // Resolve cached meta for each session id sequentially. SharedPreferences
  // calls are cheap; doing them serially also keeps the code simple and
  // avoids parallel-write races in the (unlikely) case of concurrent
  // cache mutations during the read.
  final entries = <LiveNowDiscoveryEntry>[];
  for (final s in institutionOnly) {
    final meta = await InsSessionMetaCache.read(s.id);
    entries.add(LiveNowDiscoveryEntry(session: s, meta: meta));
  }
  return entries;
});

/// Same provider, but narrowed to entries we know are public-audience.
/// Drives the global banner overlay where surfacing internal sessions
/// would be a leak — we err on the side of "skip if uncertain".
final publicLiveDiscoveryProvider =
    Provider<List<LiveNowDiscoveryEntry>>((ref) {
  final asyncEntries = ref.watch(globalDiscoverableLiveProvider);
  return asyncEntries.maybeWhen(
    data: (entries) =>
        entries.where((e) => e.isExplicitlyPublic).toList(growable: false),
    orElse: () => const [],
  );
});
