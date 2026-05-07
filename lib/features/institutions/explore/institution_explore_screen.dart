import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/institutions/institution_access_provider.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../feed/data/unified_feed_providers.dart';
import '../../feed/domain/feed_item.dart';
import '../../feed/presentation/unified_feed_card.dart';
import '../domain/communication_type.dart';
import '../live_rooms/institution_live_rooms_screen.dart'
    show institutionLiveRoomsProvider;
import '../live_rooms/institution_session_meta.dart';
import '../ui/institution_ds.dart';

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
    extends ConsumerState<InstitutionExploreScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<_ExploreScopeKey> _visibleScopes = const [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 1, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _ensureTabController(int length) {
    if (_tabController.length == length) return;
    _tabController.dispose();
    _tabController = TabController(length: length, vsync: this);
  }

  List<_ExploreScopeKey> _scopesFor(InstitutionIdentity? identity) {
    final role = (identity?.role ?? '').toUpperCase();
    final isAdminLike = identity?.canPublishPosts ?? false;
    final isMember = identity != null;
    return [
      // Public is always visible — it is the global feed and any user can
      // see it. Member requires institution membership; Internal requires
      // editor/admin/owner.
      _ExploreScopeKey.public,
      if (isMember) _ExploreScopeKey.member,
      if (isAdminLike || role == 'EDITOR') _ExploreScopeKey.internal,
    ];
  }

  void _onCompose(_ExploreScopeKey scope) {
    final id = widget.institutionId.trim();
    if (id.isEmpty) return;
    context.push(
      '/institution/$id/posts/new?scope=${scope.wire}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final identity = ref.watch(institutionIdentityProvider);
    final id = widget.institutionId.trim();

    if (id.isEmpty) {
      return AuraScaffold(
        showHeader: false,
        body: InsScreen(
          children: [
            InsModeHeader(
              title: 'Communication',
              description:
                  'Official posts, member-visible updates, and institutional discussion.',
              primaryAction: AuraSecondaryButton(
                label: 'Go to dashboard',
                icon: Icons.arrow_forward_rounded,
                onPressed: () => context.go('/institution/dashboard'),
              ),
            ),
            const InsModeHeaderGap(),
            const InsEmptyState(
              icon: Icons.apartment_outlined,
              title: 'Institution not selected',
              description:
                  'Open the institution dashboard to enter the workspace.',
            ),
          ],
        ),
      );
    }

    final scopes = _scopesFor(identity);
    if (!_listEquals(scopes, _visibleScopes)) {
      _visibleScopes = scopes;
      _ensureTabController(scopes.length.clamp(1, 3));
    }

    final canCompose = identity?.canCreatePosts ?? false;
    final activeScope = scopes.isEmpty
        ? _ExploreScopeKey.public
        : scopes[_tabController.index.clamp(0, scopes.length - 1)];

    return AuraScaffold(
      showHeader: false,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              InsSpacing.screenHPad,
              InsSpacing.screenVPad,
              InsSpacing.screenHPad,
              AuraSpace.s8,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: InsSpacing.contentMaxWidth,
                ),
                child: InsModeHeader(
                  title: 'Communication',
                  description:
                      'Official posts, member-visible updates, and institutional discussion.',
                  primaryAction: canCompose
                      ? AuraPrimaryButton(
                          label: 'Compose',
                          icon: Icons.edit_rounded,
                          onPressed: () => _onCompose(activeScope),
                        )
                      : null,
                  tabs: scopes.isEmpty
                      ? null
                      : _ScopeTabs(
                          controller: _tabController,
                          scopes: scopes,
                          onChanged: (_) => setState(() {}),
                        ),
                ),
              ),
            ),
          ),
          if (scopes.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: InsSpacing.screenHPad,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: InsSpacing.contentMaxWidth,
                  ),
                  child: Text(
                    _scopeBlurb(activeScope),
                    style: AuraText.small.copyWith(
                      color: AuraSurface.faint,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AuraSpace.s10),
          ],
          Expanded(
            child: scopes.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: InsSpacing.screenHPad,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: InsSpacing.contentMaxWidth,
                        ),
                        child: const _NoScopeAccess(),
                      ),
                    ),
                  )
                : Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: InsSpacing.contentMaxWidth,
                      ),
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          for (final scope in scopes)
                            _UnifiedFeedList(
                              institutionId: widget.institutionId,
                              scope: scope.wire,
                              emptyTitle: _emptyTitle(scope),
                              emptyBody: _emptyBody(scope),
                            ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  String _scopeBlurb(_ExploreScopeKey scope) {
    switch (scope) {
      case _ExploreScopeKey.public:
        return 'This institution’s public posts — visible to anyone on Aura. '
            'For the global feed across all of Aura, use Home.';
      case _ExploreScopeKey.member:
        return 'Posts visible to verified members of this institution.';
      case _ExploreScopeKey.internal:
        return 'Internal posts — visible only to admins and editors.';
    }
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

  bool _listEquals(List<_ExploreScopeKey> a, List<_ExploreScopeKey> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

// ── Tab strip ────────────────────────────────────────────────────────────────

class _ScopeTabs extends StatelessWidget {
  const _ScopeTabs({
    required this.controller,
    required this.scopes,
    required this.onChanged,
  });

  final TabController controller;
  final List<_ExploreScopeKey> scopes;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AuraSurface.subtle,
        borderRadius: BorderRadius.circular(AuraRadius.pill),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: TabBar(
        controller: controller,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        onTap: onChanged,
        indicator: BoxDecoration(
          color: AuraSurface.accentSoft,
          borderRadius: BorderRadius.circular(AuraRadius.pill),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: AuraSurface.accentText,
        unselectedLabelColor: AuraSurface.muted,
        labelStyle: AuraText.small.copyWith(fontWeight: FontWeight.w700),
        unselectedLabelStyle:
            AuraText.small.copyWith(fontWeight: FontWeight.w600),
        padding: const EdgeInsets.all(4),
        tabs: [
          for (final scope in scopes) Tab(text: scope.label, height: 34),
        ],
      ),
    );
  }
}

class _NoScopeAccess extends StatelessWidget {
  const _NoScopeAccess();

  @override
  Widget build(BuildContext context) {
    return const InsEmptyState(
      icon: Icons.lock_outline_rounded,
      title: 'No content available',
      description: 'You do not have access to any post visibility scope yet.',
    );
  }
}

// ── Unified-feed list ────────────────────────────────────────────────────────
//
// One list widget for all three scopes. It binds to
// `institutionExploreFeedProvider(institutionId, scope)` and delegates each
// row to `UnifiedFeedCard`. Phase 2 swaps in `_PublicGlobalList` /
// `_InstitutionScopedList`; we keep a `KeepAlive` mixin so cross-tab swipes
// don't refetch.

class _UnifiedFeedList extends ConsumerStatefulWidget {
  const _UnifiedFeedList({
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

class _UnifiedFeedListState extends ConsumerState<_UnifiedFeedList>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final args = InstitutionExploreFeedArgs(
      institutionId: widget.institutionId,
      scope: widget.scope,
    );
    final feed = ref.watch(institutionExploreFeedProvider(args));

    return feed.when(
      loading: () => const AuraLoadingState(message: 'Loading…'),
      error: (e, _) => ListView(
        padding: const EdgeInsets.all(AuraSpace.s16),
        children: [
          AuraErrorState(
            title: 'Could not load posts',
            body: '$e',
            action: AuraSecondaryButton(
              label: 'Try again',
              icon: Icons.refresh_rounded,
              onPressed: () =>
                  ref.invalidate(institutionExploreFeedProvider(args)),
            ),
          ),
        ],
      ),
      data: (page) {
        if (page.items.isEmpty) {
          return ListView(
            padding: const EdgeInsets.all(AuraSpace.s16),
            children: [
              InsEmptyState(
                icon: _emptyIcon(),
                title: widget.emptyTitle,
                description: widget.emptyBody,
              ),
            ],
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

        // Distribution Phase 1 — synthesize a "LIVE NOW" band at the top
        // of the feed when there is an active institution session.
        // Reuses the existing live rooms provider so we don't fan out
        // a new request, and degrades silently when there's no active
        // session.
        final liveRooms =
            ref.watch(institutionLiveRoomsProvider(widget.institutionId));
        final activeSession = liveRooms.maybeWhen(
          data: (data) {
            final raw = data['activeSession'];
            return raw is Map ? Map<String, dynamic>.from(raw) : null;
          },
          orElse: () => null,
        );

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(institutionExploreFeedProvider(args));
            await ref.read(institutionExploreFeedProvider(args).future);
          },
          child: ListView(
            padding: const EdgeInsets.all(AuraSpace.s16),
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
            ],
          ),
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

  /// Lower = higher priority. Reserve the bottom band (rank 100) for any
  /// item that isn't a top-level institution post — replies, personal
  /// posts, reposts — so they always trail authored statements.
  int _rankFor(FeedItem item) {
    if (item.type != FeedItemType.institutionPost) return 100;
    final hasTitle = (item.title?.trim().isNotEmpty ?? false);
    if (!hasTitle) return 100;
    return InsCommunicationDecoded.parse(item.title).type.priorityRank;
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

  void _join() {
    final id = (widget.session['id'] ?? '').toString();
    if (id.isEmpty) return;
    final m = _meta;
    final qp = <String, String>{
      'action': 'join',
      'returnTo': '/institution/${widget.institutionId}/explore',
      if (m != null) 'sessionType': m.type.wire,
      if (m != null) 'sessionAudience': m.audience.wire,
      if (m != null && (m.title?.trim().isNotEmpty ?? false))
        'sessionTitle': m.title!.trim(),
    };
    final qs = qp.entries
        .map((e) =>
            '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    context.push('/realtime/$id?$qs');
  }

  @override
  Widget build(BuildContext context) {
    final identity = ref.watch(institutionIdentityProvider);
    final hostName = identity?.name.trim() ?? '';
    final m = _meta;
    final headline = m != null
        ? '${m.type.label.toUpperCase()} • ${m.audience.label}'
        : 'LIVE SESSION';
    final title =
        (m?.title?.trim().isNotEmpty ?? false) ? m!.title!.trim() : null;

    return InkWell(
      onTap: _join,
      borderRadius: BorderRadius.circular(AuraRadius.lg),
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          AuraSpace.s14,
          AuraSpace.s12,
          AuraSpace.s12,
          AuraSpace.s12,
        ),
        decoration: BoxDecoration(
          color: AuraSurface.goodBg.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(AuraRadius.lg),
          border: Border.all(
            color: AuraSurface.goodInk.withValues(alpha: 0.45),
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            // Status dot — same anchor used everywhere else for "Live now".
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AuraSurface.goodInk,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: AuraSpace.s10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'LIVE NOW',
                        style: AuraText.micro.copyWith(
                          color: AuraSurface.goodInk,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.9,
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          '· $headline',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AuraText.micro.copyWith(
                            color: AuraSurface.muted,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (title != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AuraText.body.copyWith(
                        color: AuraSurface.ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                  if (hostName.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.apartment_rounded,
                          size: 11,
                          color: AuraSurface.faint,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'Hosted by $hostName',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AuraText.micro.copyWith(
                              color: AuraSurface.faint,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (identity?.isVerified == true) ...[
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.verified_rounded,
                            size: 11,
                            color: AuraSurface.accentText,
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AuraSpace.s10),
            AuraPrimaryButton(
              label: 'Join',
              icon: Icons.call_rounded,
              onPressed: _join,
            ),
          ],
        ),
      ),
    );
  }
}
