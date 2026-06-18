import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/institutions/institution_access_provider.dart';
import '../domain/feed_item.dart';
import 'unified_feed_repository.dart';

/// Phase 3 — current actor wire token used for `?actor=` on feed reads.
///
/// Resolves to:
///   * `institution:<id>` when the user is acting as an institution
///     (admin / owner / authorized speaker), so `viewerLiked` reflects
///     the institution-actor reaction state.
///   * `null` otherwise — the backend treats no `actor` param as
///     "personal user actor", which is the default everywhere else.
final feedActorProvider = Provider<String?>((ref) {
  final identity = ref.watch(institutionIdentityProvider);
  if (identity == null) return null;
  if (!identity.canPublishPosts) return null;
  if (identity.id.isEmpty) return null;
  return 'institution:${identity.id}';
});

/// Read-only providers over the unified `/feed/*` endpoints.
///
/// These are the **only** feed-shape providers in the app — every legacy
/// provider (`institutionPostsFirstPageProvider`,
/// `institutionExplorePublicFeedProvider`, `feedProvider`,
/// `feedControllerProvider`, `institutionPublicPostsProvider`,
/// `institutionPostDetailProvider`, `institutionPostRepliesProvider`) was
/// removed during the unified-feed migration. Detail and replies for both
/// USER_POST and INSTITUTION_POST flow through `feedItemDetailProvider` /
/// `feedItemRepliesProvider`.

/// First page of `/feed/public` — global merged user + institution-public feed.
final globalPublicFeedProvider = FutureProvider<FeedPage>((ref) async {
  final repo = ref.watch(unifiedFeedRepositoryProvider);
  final actor = ref.watch(feedActorProvider);
  return repo.globalPublic(limit: 20, actor: actor);
});

/// First page of `/feed/member` — member home / Works feed surface.
final memberHomeFeedProvider = FutureProvider<FeedPage>((ref) async {
  final repo = ref.watch(unifiedFeedRepositoryProvider);
  final actor = ref.watch(feedActorProvider);
  return repo.memberHome(limit: 20, actor: actor);
});

/// Family arg for [institutionExploreFeedProvider]. Equality is structural so
/// `(institutionId, scope)` keys map 1-to-1 with provider instances.
class InstitutionExploreFeedArgs {
  const InstitutionExploreFeedArgs({
    required this.institutionId,
    required this.scope,
  });

  final String institutionId;

  /// 'public' | 'member' | 'internal'
  final String scope;

  @override
  bool operator ==(Object other) =>
      other is InstitutionExploreFeedArgs &&
      other.institutionId == institutionId &&
      other.scope == scope;

  @override
  int get hashCode => Object.hash(institutionId, scope);
}

/// First page of `/feed/institutions/:id/explore?scope=...`.
final institutionExploreFeedProvider = FutureProvider.family<
    FeedPage, InstitutionExploreFeedArgs>((ref, args) async {
  final repo = ref.watch(unifiedFeedRepositoryProvider);
  final actor = ref.watch(feedActorProvider);
  return repo.institutionExplore(
    institutionId: args.institutionId,
    scope: args.scope,
    limit: 20,
    actor: actor,
  );
});

/// First page of `/feed/institutions/:id/profile` — institution-only public
/// posts for profile pages and public previews.
final institutionProfileFeedProvider =
    FutureProvider.family<FeedPage, String>((ref, institutionId) async {
  final repo = ref.watch(unifiedFeedRepositoryProvider);
  final actor = ref.watch(feedActorProvider);
  return repo.institutionProfile(
    institutionId: institutionId,
    limit: 20,
    actor: actor,
  );
});

/// Family arg for [feedItemDetailProvider].
class FeedItemDetailArgs {
  const FeedItemDetailArgs({required this.type, required this.id});
  final FeedItemType type;
  final String id;

  @override
  bool operator ==(Object other) =>
      other is FeedItemDetailArgs &&
      other.type == type &&
      other.id == id;

  @override
  int get hashCode => Object.hash(type, id);
}

/// `/feed/items/:type/:id` — single feed-shape detail.
final feedItemDetailProvider = FutureProvider.autoDispose
    .family<FeedItem?, FeedItemDetailArgs>((ref, args) async {
  final repo = ref.watch(unifiedFeedRepositoryProvider);
  final actor = ref.watch(feedActorProvider);
  return repo.itemDetail(type: args.type, id: args.id, actor: actor);
});

/// `/feed/items/:type/:id/replies` — Phase 3 unified replies.
///
/// Replaces the legacy `institutionPostRepliesProvider` for institution
/// posts and is also the canonical way to fetch user-post replies through
/// the unified surface. Replies for inaccessible parents return a 404 from
/// the backend; the AsyncValue surfaces that as an error which the screen
/// renders with the standard error UI.
final feedItemRepliesProvider = FutureProvider.autoDispose
    .family<FeedRepliesPage, FeedItemDetailArgs>((ref, args) async {
  final repo = ref.watch(unifiedFeedRepositoryProvider);
  return repo.itemReplies(type: args.type, id: args.id, limit: 50);
});

// ─────────────────────────────────────────────────────────────────────────────
// Phase 3 — pagination notifiers
//
// Backend paginates every feed surface; the original FutureProvider variants
// only ever fetched the first page. Each surface below exposes a paged
// notifier that calls `loadMore()` against the same underlying repository and
// accumulates items locally. Existing FutureProvider consumers continue to
// work — the paged variants are opt-in for surfaces that want load-more.
// ─────────────────────────────────────────────────────────────────────────────

class FeedPagedState {
  const FeedPagedState({
    required this.items,
    required this.nextCursor,
    required this.loadingMore,
  });

  final List<FeedItem> items;
  final String? nextCursor;
  final bool loadingMore;

  bool get hasMore => nextCursor != null && nextCursor!.isNotEmpty;

  FeedPagedState copyWith({
    List<FeedItem>? items,
    Object? nextCursor = _kKeep,
    bool? loadingMore,
  }) {
    return FeedPagedState(
      items: items ?? this.items,
      nextCursor:
          identical(nextCursor, _kKeep) ? this.nextCursor : nextCursor as String?,
      loadingMore: loadingMore ?? this.loadingMore,
    );
  }

  static const Object _kKeep = Object();
}

/// Generic paginating notifier — fetches the first page on construction,
/// accepts a fetch closure that takes a `cursor`, and surfaces an
/// `AsyncValue<FeedPagedState>` so consumers can render loading / error /
/// data states uniformly.
class FeedPagedNotifier extends StateNotifier<AsyncValue<FeedPagedState>> {
  FeedPagedNotifier(this._fetch) : super(const AsyncValue.loading()) {
    refresh();
  }

  final Future<FeedPage> Function({String? cursor}) _fetch;

  Future<void> refresh() async {
    // Content-flash contract: a refresh MUST NOT blank a feed the user is
    // already reading. Only the very first load (no items yet) shows the
    // loading state. Every later refresh — pull-to-refresh, a realtime
    // reconcile, an interaction-driven refresh — keeps the current items
    // on screen and swaps the new page in only once it has arrived. A
    // transient failure keeps the existing items rather than dropping a
    // populated feed to a blank error screen.
    //
    // Disposal discipline: this notifier can be disposed mid-fetch when
    // its `StateNotifierProvider` rebuilds (e.g. `feedActorProvider`
    // flips from null to `institution:<id>` after the post-login probe
    // resolves). Writing `state` on a disposed notifier throws
    // "Bad state: Tried to use FeedPagedNotifier after `dispose` was
    // called" — `mounted` short-circuits each post-await write.
    final previous = state.valueOrNull;
    if (previous == null && mounted) {
      state = const AsyncValue.loading();
    }
    try {
      final page = await _fetch(cursor: null);
      if (!mounted) return;
      state = AsyncValue.data(FeedPagedState(
        items: page.items,
        nextCursor: page.nextCursor,
        loadingMore: false,
      ));
    } catch (e, st) {
      if (!mounted) return;
      // Only surface an error when there was nothing on screen to keep —
      // a genuine first-load failure. Otherwise hold the existing items.
      if (previous == null) state = AsyncValue.error(e, st);
    }
  }

  Future<void> loadMore() async {
    final cur = state.valueOrNull;
    if (cur == null || !cur.hasMore || cur.loadingMore) return;
    if (!mounted) return;
    state = AsyncValue.data(cur.copyWith(loadingMore: true));
    try {
      final page = await _fetch(cursor: cur.nextCursor);
      if (!mounted) return;
      // De-dupe by (type, id) so a server-side overlap on the cursor
      // boundary doesn't render duplicates.
      final seen = <String>{
        for (final it in cur.items) '${it.type.wire}:${it.id}',
      };
      final additions = <FeedItem>[];
      for (final it in page.items) {
        final key = '${it.type.wire}:${it.id}';
        if (seen.add(key)) additions.add(it);
      }
      state = AsyncValue.data(FeedPagedState(
        items: [...cur.items, ...additions],
        nextCursor: page.nextCursor,
        loadingMore: false,
      ));
    } catch (_) {
      if (!mounted) return;
      state = AsyncValue.data(cur.copyWith(loadingMore: false));
    }
  }
}

/// Viewer feed filters — two independent dimensions that combine:
///   * topic  — AuraTopic wire token (LEFT, "what is it about?"). null = All.
///   * source — institutions | members | official | announcements |
///              public | member | internal (RIGHT, "who/what kind?"). null = Latest/All.
/// Changing this rebuilds the member/public paged providers, which re-fetch
/// with the filter as query params. Ordering stays reverse-chronological.
class FeedFilter {
  const FeedFilter({this.topic, this.source});
  final String? topic;
  final String? source;
}

final feedFilterProvider =
    StateProvider<FeedFilter>((ref) => const FeedFilter());

/// Paged variant of [globalPublicFeedProvider].
final globalPublicFeedPagedProvider = StateNotifierProvider<
    FeedPagedNotifier, AsyncValue<FeedPagedState>>((ref) {
  final repo = ref.watch(unifiedFeedRepositoryProvider);
  final actor = ref.watch(feedActorProvider);
  final filter = ref.watch(feedFilterProvider);
  return FeedPagedNotifier(({cursor}) => repo.globalPublic(
      limit: 20,
      cursor: cursor,
      actor: actor,
      topic: filter.topic,
      source: filter.source));
});

/// Paged variant of [memberHomeFeedProvider].
final memberHomeFeedPagedProvider = StateNotifierProvider<
    FeedPagedNotifier, AsyncValue<FeedPagedState>>((ref) {
  final repo = ref.watch(unifiedFeedRepositoryProvider);
  final actor = ref.watch(feedActorProvider);
  final filter = ref.watch(feedFilterProvider);
  return FeedPagedNotifier(({cursor}) => repo.memberHome(
      limit: 20,
      cursor: cursor,
      actor: actor,
      topic: filter.topic,
      source: filter.source));
});

/// Paged variant of [institutionExploreFeedProvider].
final institutionExploreFeedPagedProvider = StateNotifierProvider.family<
    FeedPagedNotifier,
    AsyncValue<FeedPagedState>,
    InstitutionExploreFeedArgs>((ref, args) {
  final repo = ref.watch(unifiedFeedRepositoryProvider);
  final actor = ref.watch(feedActorProvider);
  return FeedPagedNotifier(({cursor}) => repo.institutionExplore(
        institutionId: args.institutionId,
        scope: args.scope,
        limit: 20,
        cursor: cursor,
        actor: actor,
      ));
});

/// Paged variant of [institutionProfileFeedProvider].
final institutionProfileFeedPagedProvider =
    StateNotifierProvider.family<FeedPagedNotifier,
        AsyncValue<FeedPagedState>, String>((ref, institutionId) {
  final repo = ref.watch(unifiedFeedRepositoryProvider);
  final actor = ref.watch(feedActorProvider);
  return FeedPagedNotifier(({cursor}) => repo.institutionProfile(
        institutionId: institutionId,
        limit: 20,
        cursor: cursor,
        actor: actor,
      ));
});

/// Phase 3 — invalidate every feed surface plus the autoDispose detail
/// family after a write (like / reply / repost). Surfaces that use the
/// FutureProvider variant get re-fetched on next watch; surfaces that
/// use a paged notifier get a `refresh()` (which resets to page 1).
///
/// Call from interaction sites — `FeedInteractionBar` after a
/// successful reply or repost — so list surfaces show up-to-date
/// counts without forcing the user to navigate away and back.
void invalidateUnifiedFeedSurfaces(WidgetRef ref) {
  ref.invalidate(globalPublicFeedProvider);
  ref.invalidate(memberHomeFeedProvider);
  ref.invalidate(institutionExploreFeedProvider);
  ref.invalidate(institutionProfileFeedProvider);
  ref.invalidate(feedItemDetailProvider);
  ref.read(globalPublicFeedPagedProvider.notifier).refresh();
  ref.read(memberHomeFeedPagedProvider.notifier).refresh();
  // Family variants are refreshed via `invalidate` — paged notifiers
  // for specific institutions rebuild on next watch.
  ref.invalidate(institutionExploreFeedPagedProvider);
  ref.invalidate(institutionProfileFeedPagedProvider);
}
