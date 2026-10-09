import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/institutions/institution_access_provider.dart';
import '../../../core/product/product_language.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../feed/data/unified_feed_providers.dart';
import '../../feed/domain/feed_item.dart';
import '../../feed/presentation/feed_filter_bar.dart';
import '../../feed/presentation/unified_feed_card.dart';
import '../../topics/topic.dart';
import '../domain/communication_type.dart';
import '../live_rooms/institution_live_rooms_screen.dart'
    show institutionLiveRoomsProvider;
import '../live_rooms/institution_session_meta.dart';
import '../live_rooms/live_now_card.dart';
import '../workspace/workspace_filter.dart';
import '../workspace/workspace_page.dart';

/// Institution Explore — three distinct surfaces, all served by the unified
/// feed contract:
///
///  * **Public** — global merged feed via
///    `/v1/feed/institutions/:id/explore?scope=public` (which delegates to
///    the global `/feed/public` merge on the server).
///  * **Member** — `/v1/feed/institutions/:id/explore?scope=member`.
///  * **Internal** — `/v1/feed/institutions/:id/explore?scope=internal`.
///
/// Each tab owns its own provider so a 404 / load error in one surface
/// cannot empty the others. The Compose pill defaults the post visibility
/// to the active tab's scope and pushes onto the navigator so popping
/// returns the user to the same tab.
class InstitutionExploreScreen extends ConsumerStatefulWidget {
  const InstitutionExploreScreen({
    super.key,
    required this.institutionId,
  });

  final String institutionId;

  @override
  ConsumerState<InstitutionExploreScreen> createState() =>
      _InstitutionExploreScreenState();
}

enum _ExploreScopeKey { public, member, internal }

extension on _ExploreScopeKey {
  String get label {
    switch (this) {
      case _ExploreScopeKey.public:
        return 'Public';
      case _ExploreScopeKey.member:
        return 'Member';
      case _ExploreScopeKey.internal:
        return 'Internal';
    }
  }

  /// Wire scope sent to the backend (and to the composer).
  String get wire {
    switch (this) {
      case _ExploreScopeKey.public:
        return 'public';
      case _ExploreScopeKey.member:
        return 'member';
      case _ExploreScopeKey.internal:
        return 'internal';
    }
  }
}

class _InstitutionExploreScreenState
    extends ConsumerState<InstitutionExploreScreen> {
  /// The scope the person chose. Null until they choose: Explore opens on
  /// Public (founder, 2026-10-09, superseding ruling D2 of 2026-08-23).
  _ExploreScopeKey? _chosen;

  List<_ExploreScopeKey> _scopesFor(InstitutionIdentity? identity) {
    final canPublishOfficially = identity?.canPublishPosts ?? false;
    final isMember = identity != null;
    return [
      // Public is the global feed and needs no standing. Member requires
      // standing. Internal requires PUBLISH_OFFICIAL.
      //
      // The `role == 'EDITOR'` half of this test was dead: EDITOR was retired
      // in the Governance V1 establishment and its rows were migrated to
      // MEMBER with capabilities, so the client was carrying a role concept
      // the product no longer has. The capability beside it is the real answer.
      _ExploreScopeKey.public,
      if (isMember) _ExploreScopeKey.member,
      if (canPublishOfficially) _ExploreScopeKey.internal,
    ];
  }

  /// WHERE EXPLORE OPENS: PUBLIC (founder, 2026-10-09, superseding ruling D2
  /// of 2026-08-23).
  ///
  /// Explore sits under PUBLIC in the workspace, and Aura is public-first: it
  /// opens on what the public sees. Member and Internal stay one tap away.
  /// D2 opened members on the Member projection; the founder: "explore lands
  /// on members by default rather than public".
  _ExploreScopeKey _activeScope(List<_ExploreScopeKey> scopes) {
    final chosen = _chosen;
    if (chosen != null && scopes.contains(chosen)) return chosen;
    return scopes.contains(_ExploreScopeKey.public) ? _ExploreScopeKey.public : scopes.first;
  }

  void _onCompose(_ExploreScopeKey scope) {
    final id = widget.institutionId.trim();
    if (id.isEmpty) return;
    context.push(
      '/institution/$id/posts/new?scope=${scope.wire}',
    );
  }

  /// Topic and Resources, as ONE Filter control (DD-43). They share the
  /// global feedFilterProvider with Works so the doctrine is identical
  /// across surfaces.
  void _openFilter() {
    final filter = ref.read(feedFilterProvider);
    showWorkspaceFilterSheet(
      context,
      groups: [
        WorkspaceFilterGroup<String?>(
          title: 'Topic',
          options: [
            (null, 'All Topics'),
            for (final x in AuraTopic.values) (x.wire, x.label),
          ],
          selected: filter.topic,
          onSelected: (v) {
            final now = ref.read(feedFilterProvider);
            ref.read(feedFilterProvider.notifier).state = FeedFilter(topic: v, source: now.source);
          },
        ),
        WorkspaceFilterGroup<String?>(
          title: 'Resources',
          options: FeedFilterBar.resources,
          selected: filter.source,
          onSelected: (v) {
            final now = ref.read(feedFilterProvider);
            ref.read(feedFilterProvider.notifier).state = FeedFilter(topic: now.topic, source: v);
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final identity = ref.watch(institutionIdentityProvider);
    final id = widget.institutionId.trim();

    if (id.isEmpty) {
      return WorkspacePage(
        type: WorkspacePageType.collection,
        title: 'Posts',
        children: [
          WorkspaceEmpty(
            icon: Icons.apartment_outlined,
            title: 'Institution not selected',
            body: 'Open the institution dashboard to enter the workspace.',
            action: WorkspaceAction(
              label: 'Go to dashboard',
              icon: Icons.arrow_forward_rounded,
              onPressed: () => context.go('/institution/dashboard'),
            ),
          ),
        ],
      );
    }

    final scopes = _scopesFor(identity);
    final active = _activeScope(scopes);
    final canCompose = identity?.canCreatePosts ?? false;
    final filter = ref.watch(feedFilterProvider);
    final filtersOn = (filter.topic != null ? 1 : 0) + (filter.source != null ? 1 : 0);

    return WorkspacePage(
      type: WorkspacePageType.collection,
      title: 'Posts',
      purpose: 'What this institution has posted, by who can see it.',
      primary: canCompose
          ? WorkspaceAction(
              label: 'Compose',
              icon: Icons.edit_rounded,
              onPressed: () => _onCompose(active),
            )
          : null,
      tabs: [
        for (final scope in scopes) WorkspaceTab(id: scope.wire, label: scope.label),
      ],
      selectedTab: active.wire,
      onTab: (wire) => setState(() {
        _chosen = scopes.firstWhere((s) => s.wire == wire);
      }),
      tabTrailing: WorkspaceFilterButton(active: filtersOn, onPressed: _openFilter),
      children: [
        _UnifiedFeedList(
          key: ValueKey('explore-${active.wire}'),
          institutionId: widget.institutionId,
          scope: active.wire,
          // With a filter on, "no posts yet" is untrue: say the filter hid them.
          emptyTitle: filtersOn > 0 ? 'Nothing matches the filter' : _emptyTitle(active),
          emptyBody: filtersOn > 0
              ? 'Open Filter and choose All Topics and All Resources to see every post.'
              : _emptyBody(active),
        ),
      ],
    );
  }

  String _emptyTitle(_ExploreScopeKey scope) {
    switch (scope) {
      case _ExploreScopeKey.public:
        return 'No public posts yet';
      case _ExploreScopeKey.member:
        return 'No member posts yet';
      case _ExploreScopeKey.internal:
        return 'No internal posts yet';
    }
  }

  String _emptyBody(_ExploreScopeKey scope) {
    switch (scope) {
      case _ExploreScopeKey.public:
        return 'Public posts published by this institution will appear here.';
      case _ExploreScopeKey.member:
        return 'Member-only posts from this institution will appear here.';
      case _ExploreScopeKey.internal:
        return 'Internal posts visible only to admins and editors will appear here.';
    }
  }
}

// ── Unified-feed list ────────────────────────────────────────────────────────
//
// One list for all three scopes, inside the workspace frame's column (the
// frame owns the scrolling). It binds to
// `institutionExploreFeedPagedProvider(institutionId, scope)` and delegates
// each post to `UnifiedFeedCard`, unchanged.

class _UnifiedFeedList extends ConsumerStatefulWidget {
  const _UnifiedFeedList({
    super.key,
    required this.institutionId,
    required this.scope,
    required this.emptyTitle,
    required this.emptyBody,
  });

  final String institutionId;
  final String scope;
  final String emptyTitle;
  final String emptyBody;

  @override
  ConsumerState<_UnifiedFeedList> createState() => _UnifiedFeedListState();
}

class _UnifiedFeedListState extends ConsumerState<_UnifiedFeedList> {
  @override
  Widget build(BuildContext context) {
    final args = InstitutionExploreFeedArgs(
      institutionId: widget.institutionId,
      scope: widget.scope,
    );
    final feed = ref.watch(institutionExploreFeedPagedProvider(args));

    return feed.when(
      loading: () => const WorkspaceLoading(),
      error: (e, _) => WorkspaceEmpty(
        icon: Icons.error_outline_rounded,
        title: 'Could not load posts',
        body: '$e',
        action: WorkspaceAction(
          label: ProductLabels.of(ProductAction.retry),
          icon: Icons.refresh_rounded,
          onPressed: () => ref.read(institutionExploreFeedPagedProvider(args).notifier).refresh(),
        ),
      ),
      data: (page) {
        if (page.items.isEmpty) {
          return WorkspaceEmpty(
            icon: _emptyIcon(),
            title: widget.emptyTitle,
            body: widget.emptyBody,
          );
        }
        // Phase 2 — client-side priority sort. Backend ordering is preserved
        // as the within-priority tiebreaker via stable sort. The first
        // OFFICIAL ANNOUNCEMENT (if any) is pinned in its own band so the
        // most institutionally significant statement always reads first.
        final ordered = _orderByCommunicationPriority(page.items);
        final pinned = _firstOfficialAnnouncement(ordered);
        final rest = pinned == null
            ? ordered
            : [for (final i in ordered) if (!identical(i, pinned)) i];

        // Distribution Phase 1 — a "LIVE NOW" band at the top of the feed
        // when there is an active institution session. Reuses the live rooms
        // provider and degrades silently when no session is active.
        final liveRooms =
            ref.watch(institutionLiveRoomsProvider(widget.institutionId));
        final activeSession = liveRooms.maybeWhen(
          data: (data) {
            final raw = data['activeSession'];
            return raw is Map ? Map<String, dynamic>.from(raw) : null;
          },
          orElse: () => null,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (activeSession != null) ...[
              _LiveNowBand(
                institutionId: widget.institutionId,
                session: activeSession,
              ),
              const SizedBox(height: AuraSpace.s10),
            ],
            if (pinned != null) ...[
              _PinnedAnnouncementBand(item: pinned),
              const SizedBox(height: AuraSpace.s10),
            ],
            for (var i = 0; i < rest.length; i++) ...[
              UnifiedFeedCard(item: rest[i]),
              if (i < rest.length - 1)
                const SizedBox(height: AuraSpace.s10),
            ],
            // Phase 3 — Load more for the institution explore feed.
            if (page.hasMore) ...[
              const SizedBox(height: AuraSpace.s14),
              Center(
                child: AuraSecondaryButton(
                  label: page.loadingMore ? 'Loading…' : 'Load more',
                  icon: page.loadingMore
                      ? Icons.hourglass_empty_rounded
                      : Icons.expand_more_rounded,
                  onPressed: page.loadingMore
                      ? null
                      : () => ref
                          .read(institutionExploreFeedPagedProvider(args)
                              .notifier)
                          .loadMore(),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  /// Stable sort by communication-type priority. Items that aren't
  /// top-level institutional speech (or carry no marker) keep their
  /// backend order at the bottom of the list.
  List<FeedItem> _orderByCommunicationPriority(List<FeedItem> input) {
    final indexed = <_RankedItem>[];
    for (var i = 0; i < input.length; i++) {
      final item = input[i];
      final rank = _rankFor(item);
      indexed.add(_RankedItem(item: item, rank: rank, original: i));
    }
    indexed.sort((a, b) {
      if (a.rank != b.rank) return a.rank.compareTo(b.rank);
      return a.original.compareTo(b.original);
    });
    return indexed.map((e) => e.item).toList(growable: false);
  }

  /// Lower = higher priority. Only genuinely official institution
  /// communications — posts explicitly marked `[OFFICIAL:TYPE]`
  /// (Announcement, Advisory, Notice, Update) — get pulled above the
  /// chronological mix. Everything else (unmarked institution posts,
  /// replies, personal posts, reposts) shares the bottom band (rank 100)
  /// and keeps the backend's chronological order via the stable sort below
  /// — it no longer automatically trails every official post regardless
  /// of recency.
  int _rankFor(FeedItem item) {
    if (item.type != FeedItemType.institutionPost) return 100;
    final hasTitle = (item.title?.trim().isNotEmpty ?? false);
    if (!hasTitle) return 100;
    final decoded = InsCommunicationDecoded.parse(item.title);
    if (!decoded.hadMarker) return 100;
    return decoded.type.priorityRank;
  }

  FeedItem? _firstOfficialAnnouncement(List<FeedItem> ordered) {
    for (final item in ordered) {
      if (item.type != FeedItemType.institutionPost) continue;
      final hasTitle = (item.title?.trim().isNotEmpty ?? false);
      if (!hasTitle) continue;
      final decoded = InsCommunicationDecoded.parse(item.title);
      if (!decoded.hadMarker) continue;
      if (decoded.type == InsCommunicationType.announcement) return item;
    }
    return null;
  }

  IconData _emptyIcon() {
    switch (widget.scope) {
      case 'internal':
        return Icons.lock_outline_rounded;
      case 'member':
        return Icons.group_rounded;
      default:
        return Icons.public_rounded;
    }
  }
}

class _RankedItem {
  const _RankedItem({
    required this.item,
    required this.rank,
    required this.original,
  });

  final FeedItem item;
  final int rank;
  final int original;
}

/// Pinned-announcement band. Phase 3 — elevated to feel like an
/// institutional alert: heavier eyebrow ("OFFICIAL ANNOUNCEMENT"), an
/// "Important update from [Name]" sub-label, and breathing-room top
/// padding so the band reads as load-bearing rather than just another
/// card.
class _PinnedAnnouncementBand extends ConsumerWidget {
  const _PinnedAnnouncementBand({required this.item});

  final FeedItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Source for the "Important update from …" line. The active workspace
    // identity is the most reliable source for the host institution name;
    // fall back to the feed item's author display name when identity is
    // unavailable (e.g. a non-member viewing a public room).
    final identity = ref.watch(institutionIdentityProvider);
    final hostName = (identity?.name.trim().isNotEmpty ?? false)
        ? identity!.name.trim()
        : item.author.name.trim();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AuraSpace.s8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          AuraSpace.s10,
          AuraSpace.s12,
          AuraSpace.s10,
          AuraSpace.s10,
        ),
        decoration: BoxDecoration(
          color: AuraSurface.accentSoft.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(AuraRadius.lg),
          border: Border.all(
            color: AuraSurface.accent.withValues(alpha: 0.45),
            width: 1.2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(
                left: AuraSpace.s4,
                right: AuraSpace.s4,
                bottom: AuraSpace.s8,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.campaign_rounded,
                        size: 13,
                        color: AuraSurface.accentText,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'OFFICIAL ANNOUNCEMENT',
                        style: AuraText.micro.copyWith(
                          color: AuraSurface.accentText,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.9,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                  if (hostName.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Important update from $hostName',
                      style: AuraText.small.copyWith(
                        color: AuraSurface.accentText,
                        fontWeight: FontWeight.w700,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            UnifiedFeedCard(item: item),
          ],
        ),
      ),
    );
  }
}

/// Distribution Phase 1 — "LIVE NOW" band rendered at the top of the
/// institution explore feed when an active session exists. The band
/// is the institutional equivalent of an in-feed live indicator: it
/// reads the same `activeSession` payload the live rooms screen uses,
/// looks up the cached session meta for type/audience/title, and
/// navigates to `/realtime/:id` on tap with the same query params used
/// elsewhere so the in-session header carries the institutional
/// context immediately on join.
/// Thin wrapper that loads cached session meta for the institution
/// active session and delegates rendering to the shared [LiveNowCard].
/// Kept here so the institution explore feed gets the same "LIVE NOW"
/// surface as the global feeds, with a single rendering path.
class _LiveNowBand extends ConsumerStatefulWidget {
  const _LiveNowBand({
    required this.institutionId,
    required this.session,
  });

  final String institutionId;
  final Map<String, dynamic> session;

  @override
  ConsumerState<_LiveNowBand> createState() => _LiveNowBandState();
}

class _LiveNowBandState extends ConsumerState<_LiveNowBand> {
  InsSessionMeta? _meta;

  @override
  void initState() {
    super.initState();
    _loadMeta();
  }

  Future<void> _loadMeta() async {
    final id = (widget.session['id'] ?? '').toString();
    final m = await InsSessionMetaCache.read(id);
    if (mounted) setState(() => _meta = m);
  }

  @override
  Widget build(BuildContext context) {
    final identity = ref.watch(institutionIdentityProvider);
    final data = LiveNowCardData.fromInstitution(
      session: widget.session,
      institutionId: widget.institutionId,
      hostName: identity?.name.trim() ?? '',
      isVerifiedHost: identity?.isVerified == true,
      meta: _meta,
    );
    return LiveNowCard(data: data);
  }
}
