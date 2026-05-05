import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/feed_item.dart';
import 'unified_feed_repository.dart';

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
  return repo.globalPublic(limit: 20);
});

/// First page of `/feed/member` — member home / Works feed surface.
final memberHomeFeedProvider = FutureProvider<FeedPage>((ref) async {
  final repo = ref.watch(unifiedFeedRepositoryProvider);
  return repo.memberHome(limit: 20);
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
  return repo.institutionExplore(
    institutionId: args.institutionId,
    scope: args.scope,
    limit: 20,
  );
});

/// First page of `/feed/institutions/:id/profile` — institution-only public
/// posts for profile pages and public previews.
final institutionProfileFeedProvider =
    FutureProvider.family<FeedPage, String>((ref, institutionId) async {
  final repo = ref.watch(unifiedFeedRepositoryProvider);
  return repo.institutionProfile(institutionId: institutionId, limit: 20);
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
  return repo.itemDetail(type: args.type, id: args.id);
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
