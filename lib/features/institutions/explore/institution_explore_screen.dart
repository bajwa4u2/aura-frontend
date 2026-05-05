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
import '../data/institutions_repository.dart';
import '../domain/institution_post.dart';

/// Institution Explore — paginated feed of [InstitutionPost]s, scoped by
/// visibility tabs (Public / Member / Internal). Visibility tabs are gated
/// by the viewer's role.
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

class _InstitutionExploreScreenState
    extends ConsumerState<InstitutionExploreScreen>
    with SingleTickerProviderStateMixin {
  static const _scopes = <_ExploreScope>[
    _ExploreScope(key: 'public', label: 'Public'),
    _ExploreScope(key: 'member', label: 'Member'),
    _ExploreScope(key: 'internal', label: 'Internal'),
  ];

  late TabController _tabController;
  List<_ExploreScope> _visibleScopes = const [];

  @override
  void initState() {
    super.initState();
    // Initialize with a single tab; we'll reconfigure when identity loads.
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

  List<_ExploreScope> _scopesFor(InstitutionIdentity? identity) {
    final role = (identity?.role ?? '').toUpperCase();
    final isAdminLike = identity?.canPublishPosts ?? false;
    final isMember = identity != null;

    return _scopes.where((scope) {
      switch (scope.key) {
        case 'public':
          return true;
        case 'member':
          return isMember; // any authenticated member can see member-only.
        case 'internal':
          return isAdminLike || role == 'EDITOR';
      }
      return false;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final identity = ref.watch(institutionIdentityProvider);

    // Hard guard: an empty institutionId makes the dio call hit
    // `/institutions//posts` and 404 with no useful message. Show an empty
    // state with a route back to the dashboard instead of letting the
    // network layer surface a raw 404.
    if (widget.institutionId.trim().isEmpty) {
      return AuraScaffold(
        showHeader: false,
        body: ListView(
          padding: const EdgeInsets.all(AuraSpace.s16),
          children: [
            AuraEmptyState(
              icon: Icons.apartment_outlined,
              title: 'Institution not selected',
              body:
                  'Open the institution dashboard to enter the workspace, '
                  'then choose Explore from the workspace nav.',
              action: AuraSecondaryButton(
                label: 'Go to dashboard',
                icon: Icons.arrow_forward_rounded,
                onPressed: () => context.go('/institution/dashboard'),
              ),
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

    return AuraScaffold(
      showHeader: false,
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AuraSpace.s16,
                  AuraSpace.s20,
                  AuraSpace.s16,
                  AuraSpace.s8,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 920),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text('Explore', style: AuraText.headline),
                            ),
                            if (canCompose)
                              AuraPrimaryButton(
                                label: 'Compose',
                                icon: Icons.edit_rounded,
                                onPressed: () => context.push(
                                  '/institution/${widget.institutionId}/posts/new',
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: AuraSpace.s6),
                        Text(
                          'Posts published by this institution, scoped by audience.',
                          style:
                              AuraText.body.copyWith(color: AuraSurface.muted),
                        ),
                        const SizedBox(height: AuraSpace.s14),
                        if (scopes.isNotEmpty)
                          _ScopeTabs(
                            controller: _tabController,
                            scopes: scopes,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: scopes.isEmpty
                    ? const _NoScopeAccess()
                    : Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 920),
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              for (final scope in scopes)
                                _ExploreList(
                                  institutionId: widget.institutionId,
                                  scope: scope.key,
                                ),
                            ],
                          ),
                        ),
                      ),
              ),
            ],
          ),
          // FAB-style overlay button. When the viewer cannot compose, the
          // pill is shown in a disabled state with an explanatory tooltip.
          if (!canCompose)
            const Positioned(
              right: AuraSpace.s20,
              bottom: AuraSpace.s20,
              child: Tooltip(
                message: "Members can't post",
                child: FloatingActionButton.extended(
                  onPressed: null,
                  icon: Icon(Icons.lock_outline_rounded),
                  label: Text('Compose'),
                  backgroundColor: AuraSurface.subtle,
                  foregroundColor: AuraSurface.faint,
                ),
              ),
            ),
        ],
      ),
    );
  }

  bool _listEquals(List<_ExploreScope> a, List<_ExploreScope> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].key != b[i].key) return false;
    }
    return true;
  }
}

class _ExploreScope {
  const _ExploreScope({required this.key, required this.label});
  final String key;
  final String label;
}

class _ScopeTabs extends StatelessWidget {
  const _ScopeTabs({required this.controller, required this.scopes});

  final TabController controller;
  final List<_ExploreScope> scopes;

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
        indicator: BoxDecoration(
          color: AuraSurface.accentSoft,
          borderRadius: BorderRadius.circular(AuraRadius.pill),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: AuraSurface.accentText,
        unselectedLabelColor: AuraSurface.muted,
        labelStyle:
            AuraText.small.copyWith(fontWeight: FontWeight.w700),
        unselectedLabelStyle:
            AuraText.small.copyWith(fontWeight: FontWeight.w600),
        padding: const EdgeInsets.all(4),
        tabs: [
          for (final scope in scopes)
            Tab(text: scope.label, height: 34),
        ],
      ),
    );
  }
}

class _NoScopeAccess extends StatelessWidget {
  const _NoScopeAccess();

  @override
  Widget build(BuildContext context) {
    return const AuraEmptyState(
      icon: Icons.lock_outline_rounded,
      title: 'No content available',
      body: 'You do not have access to any post visibility scope yet.',
    );
  }
}

class _ExploreList extends ConsumerStatefulWidget {
  const _ExploreList({required this.institutionId, required this.scope});

  final String institutionId;
  final String scope;

  @override
  ConsumerState<_ExploreList> createState() => _ExploreListState();
}

class _ExploreListState extends ConsumerState<_ExploreList>
    with AutomaticKeepAliveClientMixin {
  final _scrollController = ScrollController();

  bool _loadingMore = false;
  String? _cursor;
  String? _moreError;
  final List<InstitutionPost> _additional = <InstitutionPost>[];
  bool _exhausted = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  void _onScroll() {
    if (_loadingMore || _exhausted) return;
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 240) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_cursor == null || _cursor!.isEmpty) {
      _exhausted = true;
      return;
    }
    setState(() {
      _loadingMore = true;
      _moreError = null;
    });
    try {
      final repo = ref.read(institutionsRepositoryProvider);
      final next = await repo.listInstitutionPosts(
        institutionId: widget.institutionId,
        scope: widget.scope,
        cursor: _cursor,
        limit: 20,
      );
      if (!mounted) return;
      setState(() {
        _additional.addAll(next.items);
        _cursor = next.nextCursor;
        _exhausted = !next.hasMore;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _moreError = 'Could not load more: $e';
        _loadingMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final args = InstitutionPostListArgs(
      institutionId: widget.institutionId,
      scope: widget.scope,
    );
    final firstPage = ref.watch(institutionPostsFirstPageProvider(args));

    return firstPage.when(
      loading: () => const AuraLoadingState(message: 'Loading posts…'),
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
                  ref.invalidate(institutionPostsFirstPageProvider(args)),
            ),
          ),
        ],
      ),
      data: (page) {
        if (_cursor == null && !_exhausted) {
          _cursor = page.nextCursor;
          _exhausted = !page.hasMore;
        }
        final posts = <InstitutionPost>[
          ...page.items,
          ..._additional,
        ];
        if (posts.isEmpty) {
          return const AuraEmptyState(
            icon: Icons.feed_outlined,
            title: 'No posts yet',
            body: 'When this scope has posts they will show up here.',
          );
        }
        return RefreshIndicator(
          onRefresh: () async {
            setState(() {
              _additional.clear();
              _cursor = null;
              _exhausted = false;
              _moreError = null;
            });
            ref.invalidate(institutionPostsFirstPageProvider(args));
          },
          child: ListView.separated(
            controller: _scrollController,
            padding: const EdgeInsets.all(AuraSpace.s16),
            itemCount: posts.length + (_loadingMore || _moreError != null ? 1 : 0),
            separatorBuilder: (_, __) =>
                const SizedBox(height: AuraSpace.s10),
            itemBuilder: (context, index) {
              if (index >= posts.length) {
                if (_moreError != null) {
                  return Padding(
                    padding: const EdgeInsets.all(AuraSpace.s12),
                    child: Text(
                      _moreError!,
                      style:
                          AuraText.small.copyWith(color: AuraSurface.dangerInk),
                    ),
                  );
                }
                return const Padding(
                  padding: EdgeInsets.all(AuraSpace.s16),
                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              }
              return _PostCard(post: posts[index]);
            },
          ),
        );
      },
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({required this.post});

  final InstitutionPost post;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AuraSpace.s16),
      decoration: BoxDecoration(
        color: AuraSurface.card,
        borderRadius: BorderRadius.circular(AuraRadius.card),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _StatusChip(status: post.status),
              const SizedBox(width: AuraSpace.s8),
              _VisibilityChip(visibility: post.visibility),
              const Spacer(),
              if (post.publishedAt != null)
                Text(
                  _formatDate(post.publishedAt!),
                  style: AuraText.micro.copyWith(color: AuraSurface.faint),
                ),
            ],
          ),
          const SizedBox(height: AuraSpace.s10),
          Text(
            post.title,
            style: AuraText.subtitle.copyWith(fontWeight: FontWeight.w800),
          ),
          if (post.body.isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s6),
            Text(
              post.body,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style:
                  AuraText.body.copyWith(color: AuraSurface.muted, height: 1.5),
            ),
          ],
        ],
      ),
    );
  }
}

String _formatDate(DateTime dt) {
  final local = dt.toLocal();
  final yyyy = local.year.toString().padLeft(4, '0');
  final mm = local.month.toString().padLeft(2, '0');
  final dd = local.day.toString().padLeft(2, '0');
  return '$yyyy-$mm-$dd';
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final InstitutionPostStatus status;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color ink;
    switch (status) {
      case InstitutionPostStatus.published:
        bg = AuraSurface.goodBg;
        ink = AuraSurface.goodInk;
        break;
      case InstitutionPostStatus.draft:
        bg = AuraSurface.subtle;
        ink = AuraSurface.muted;
        break;
      case InstitutionPostStatus.pendingApproval:
        bg = AuraSurface.warnBg;
        ink = AuraSurface.warnInk;
        break;
      case InstitutionPostStatus.archived:
        bg = AuraSurface.subtle;
        ink = AuraSurface.faint;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AuraRadius.pill),
      ),
      child: Text(
        status.label,
        style:
            AuraText.micro.copyWith(color: ink, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _VisibilityChip extends StatelessWidget {
  const _VisibilityChip({required this.visibility});

  final InstitutionPostVisibility visibility;

  @override
  Widget build(BuildContext context) {
    IconData icon;
    switch (visibility) {
      case InstitutionPostVisibility.publicAll:
        icon = Icons.public_rounded;
        break;
      case InstitutionPostVisibility.memberOnly:
        icon = Icons.people_outline_rounded;
        break;
      case InstitutionPostVisibility.internal:
        icon = Icons.lock_outline_rounded;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AuraSurface.subtle,
        borderRadius: BorderRadius.circular(AuraRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: AuraSurface.muted),
          const SizedBox(width: 4),
          Text(
            visibility.label,
            style: AuraText.micro.copyWith(
              color: AuraSurface.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
