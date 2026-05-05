import 'package:dio/dio.dart';
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
import '../../posts/data/reactions_repository.dart';
import '../data/institutions_repository.dart';
import '../domain/explore_feed_item.dart';
import '../domain/institution_post.dart';

/// Maps a member-shell route like `/u/:handle` or `/institutions/:slug` to
/// the equivalent institution-shell variant when the caller is currently
/// inside `/institution/:institutionId/...`. This keeps institution actor
/// context intact when a user opens a profile from inside the workspace.
String _profileRoute(BuildContext context, String memberShellPath) {
  final path = GoRouterState.of(context).uri.path;
  final m = RegExp(r'^/institution/([^/]+)(/|$)').firstMatch(path);
  if (m == null) return memberShellPath;
  final institutionId = m.group(1)!;
  if (institutionId.isEmpty) return memberShellPath;
  // memberShellPath starts with '/' — strip the leading slash so we can
  // splice it under /institution/:id.
  final tail = memberShellPath.startsWith('/')
      ? memberShellPath.substring(1)
      : memberShellPath;
  return '/institution/$institutionId/$tail';
}

/// Institution Explore — three distinct surfaces:
///
///  * **Public** — global feed merging user posts + globally-distributable
///    institution posts. Backend `GET /posts/public` (handled by the platform
///    posts controller, NOT the institution-scoped controller).
///  * **Member** — institution-scoped feed visible to members.
///    `GET /institutions/:id/posts?scope=member`.
///  * **Internal** — institution-scoped feed visible to admins/editors only.
///    `GET /institutions/:id/posts?scope=internal`.
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

  /// Maps the tab key to the scope query param the composer expects.
  String get composeScope {
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
      '/institution/$id/posts/new?scope=${scope.composeScope}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final identity = ref.watch(institutionIdentityProvider);
    final id = widget.institutionId.trim();

    if (id.isEmpty) {
      // Defensive: the primary nav routes to /institution/dashboard when id
      // is empty so this case should not normally fire. Keep a clean fallback
      // rather than crash if a deep-link slips through.
      return AuraScaffold(
        showHeader: false,
        body: ListView(
          padding: const EdgeInsets.all(AuraSpace.s16),
          children: [
            AuraEmptyState(
              icon: Icons.apartment_outlined,
              title: 'Institution not selected',
              body:
                  'Open the institution dashboard to enter the workspace.',
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
    final activeScope = scopes.isEmpty
        ? _ExploreScopeKey.public
        : scopes[_tabController.index.clamp(0, scopes.length - 1)];

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
                                onPressed: () => _onCompose(activeScope),
                              ),
                          ],
                        ),
                        const SizedBox(height: AuraSpace.s6),
                        Text(
                          _scopeBlurb(activeScope),
                          style: AuraText.body
                              .copyWith(color: AuraSurface.muted),
                        ),
                        const SizedBox(height: AuraSpace.s14),
                        if (scopes.isNotEmpty)
                          _ScopeTabs(
                            controller: _tabController,
                            scopes: scopes,
                            onChanged: (_) => setState(() {}),
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
                                _scopeBody(
                                  scope: scope,
                                  institutionId: widget.institutionId,
                                ),
                            ],
                          ),
                        ),
                      ),
              ),
            ],
          ),
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

  Widget _scopeBody({
    required _ExploreScopeKey scope,
    required String institutionId,
  }) {
    switch (scope) {
      case _ExploreScopeKey.public:
        return _PublicGlobalList(institutionId: institutionId);
      case _ExploreScopeKey.member:
        return _InstitutionScopedList(
          institutionId: institutionId,
          scope: 'member',
        );
      case _ExploreScopeKey.internal:
        return _InstitutionScopedList(
          institutionId: institutionId,
          scope: 'internal',
        );
    }
  }

  String _scopeBlurb(_ExploreScopeKey scope) {
    switch (scope) {
      case _ExploreScopeKey.public:
        return 'Global feed — public posts from people and institutions across Aura. '
            'Posting here as your institution publishes to this feed.';
      case _ExploreScopeKey.member:
        return 'Posts visible to verified members of this institution.';
      case _ExploreScopeKey.internal:
        return 'Internal posts — visible only to admins and editors.';
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
    return const AuraEmptyState(
      icon: Icons.lock_outline_rounded,
      title: 'No content available',
      body: 'You do not have access to any post visibility scope yet.',
    );
  }
}

// ── Public global merged feed ────────────────────────────────────────────────

class _PublicGlobalList extends ConsumerStatefulWidget {
  const _PublicGlobalList({required this.institutionId});

  final String institutionId;

  @override
  ConsumerState<_PublicGlobalList> createState() => _PublicGlobalListState();
}

class _PublicGlobalListState extends ConsumerState<_PublicGlobalList>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final asyncFeed =
        ref.watch(institutionExplorePublicFeedProvider(widget.institutionId));

    return asyncFeed.when(
      loading: () => const AuraLoadingState(message: 'Loading public feed…'),
      error: (e, _) => ListView(
        padding: const EdgeInsets.all(AuraSpace.s16),
        children: [
          AuraErrorState(
            title: 'Could not load public feed',
            body: '$e',
            action: AuraSecondaryButton(
              label: 'Try again',
              icon: Icons.refresh_rounded,
              onPressed: () => ref.invalidate(
                institutionExplorePublicFeedProvider(widget.institutionId),
              ),
            ),
          ),
        ],
      ),
      data: (page) {
        if (page.items.isEmpty) {
          return const AuraEmptyState(
            icon: Icons.public_rounded,
            title: 'Public feed is empty',
            body:
                'Public posts from people and institutions will appear here.',
          );
        }
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(
              institutionExplorePublicFeedProvider(widget.institutionId),
            );
          },
          child: ListView.separated(
            padding: const EdgeInsets.all(AuraSpace.s16),
            itemCount: page.items.length,
            separatorBuilder: (_, __) => const SizedBox(height: AuraSpace.s10),
            itemBuilder: (context, i) =>
                _ExploreFeedCard(item: page.items[i]),
          ),
        );
      },
    );
  }
}

// ── Institution-scoped feed (Member / Internal) ──────────────────────────────

class _InstitutionScopedList extends ConsumerStatefulWidget {
  const _InstitutionScopedList({
    required this.institutionId,
    required this.scope,
  });

  final String institutionId;

  /// 'member' | 'internal'
  final String scope;

  @override
  ConsumerState<_InstitutionScopedList> createState() =>
      _InstitutionScopedListState();
}

class _InstitutionScopedListState extends ConsumerState<_InstitutionScopedList>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

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
        if (page.items.isEmpty) {
          return AuraEmptyState(
            icon: Icons.feed_outlined,
            title: 'No posts yet',
            body: widget.scope == 'internal'
                ? 'Internal posts visible only to admins and editors will appear here.'
                : 'Member-only posts from this institution will appear here.',
          );
        }
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(institutionPostsFirstPageProvider(args));
          },
          child: ListView.separated(
            padding: const EdgeInsets.all(AuraSpace.s16),
            itemCount: page.items.length,
            separatorBuilder: (_, __) => const SizedBox(height: AuraSpace.s10),
            itemBuilder: (context, i) =>
                _InstitutionPostCard(post: page.items[i]),
          ),
        );
      },
    );
  }
}

// ── Cards ────────────────────────────────────────────────────────────────────

String _formatDate(DateTime dt) {
  final local = dt.toLocal();
  final yyyy = local.year.toString().padLeft(4, '0');
  final mm = local.month.toString().padLeft(2, '0');
  final dd = local.day.toString().padLeft(2, '0');
  return '$yyyy-$mm-$dd';
}

class _ExploreFeedCard extends StatelessWidget {
  const _ExploreFeedCard({required this.item});

  final ExploreFeedItem item;

  @override
  Widget build(BuildContext context) {
    final entry = item;
    if (entry is ExploreUserPost) {
      return _ExploreUserPostCard(post: entry);
    }
    if (entry is ExploreInstitutionPost) {
      return _ExploreInstitutionPostCard(post: entry);
    }
    return const SizedBox.shrink();
  }
}

class _ExploreUserPostCard extends ConsumerWidget {
  const _ExploreUserPostCard({required this.post});

  final ExploreUserPost post;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final initial = post.authorDisplayName.trim().isNotEmpty
        ? post.authorDisplayName.trim()[0].toUpperCase()
        : (post.authorHandle.isNotEmpty ? post.authorHandle[0].toUpperCase() : 'U');

    return Container(
      padding: const EdgeInsets.all(AuraSpace.s14),
      decoration: BoxDecoration(
        color: AuraSurface.card,
        borderRadius: BorderRadius.circular(AuraRadius.card),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: post.authorHandle.isNotEmpty
                    ? () => context.push(
                        _profileRoute(context, '/u/${post.authorHandle}'))
                    : null,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _AuthorAvatar(
                      imageUrl: post.authorAvatarUrl,
                      fallback: initial,
                    ),
                    const SizedBox(width: AuraSpace.s10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post.authorDisplayName.isNotEmpty
                              ? post.authorDisplayName
                              : (post.authorHandle.isNotEmpty
                                  ? '@${post.authorHandle}'
                                  : 'Unknown'),
                          style: AuraText.small
                              .copyWith(fontWeight: FontWeight.w700),
                        ),
                        if (post.authorHandle.isNotEmpty &&
                            post.authorDisplayName.isNotEmpty)
                          Text(
                            '@${post.authorHandle}',
                            style: AuraText.micro
                                .copyWith(color: AuraSurface.faint),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (post.publishedAt != null)
                Text(
                  _formatDate(post.publishedAt!),
                  style: AuraText.micro.copyWith(color: AuraSurface.faint),
                ),
            ],
          ),
          if (post.text.isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s10),
            Text(
              post.text,
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
              style:
                  AuraText.body.copyWith(color: AuraSurface.ink, height: 1.5),
            ),
          ],
          if (post.media.isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s10),
            _MediaThumb(url: post.media.first.url, isVideo: post.media.first.isVideo),
          ],
          const SizedBox(height: AuraSpace.s12),
          _ExploreInteractionBar(target: PostReactionTarget(post.id)),
        ],
      ),
    );
  }
}

class _ExploreInstitutionPostCard extends ConsumerWidget {
  const _ExploreInstitutionPostCard({required this.post});

  final ExploreInstitutionPost post;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final initial = post.institutionName.trim().isNotEmpty
        ? post.institutionName.trim()[0].toUpperCase()
        : 'I';

    return InkWell(
      onTap: () => context.push(
        '/institution/${post.institutionId}/posts/${post.id}',
      ),
      borderRadius: BorderRadius.circular(AuraRadius.card),
      child: Container(
      padding: const EdgeInsets.all(AuraSpace.s14),
      decoration: BoxDecoration(
        color: AuraSurface.card,
        borderRadius: BorderRadius.circular(AuraRadius.card),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: post.institutionSlug.isNotEmpty
                    ? () => context.push(
                        _profileRoute(
                          context,
                          '/institutions/${post.institutionSlug}',
                        ),
                      )
                    : null,
                child: _AuthorAvatar(
                  imageUrl: post.institutionLogoUrl,
                  fallback: initial,
                ),
              ),
              const SizedBox(width: AuraSpace.s10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            post.institutionName.isNotEmpty
                                ? post.institutionName
                                : 'Institution',
                            style: AuraText.small
                                .copyWith(fontWeight: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: AuraSpace.s6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: AuraSurface.accentSoft,
                            borderRadius: BorderRadius.circular(AuraRadius.pill),
                          ),
                          child: Text(
                            'Institution',
                            style: AuraText.micro.copyWith(
                              color: AuraSurface.accentText,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (post.institutionSlug.isNotEmpty)
                      Text(
                        '@${post.institutionSlug}',
                        style: AuraText.micro
                            .copyWith(color: AuraSurface.faint),
                      ),
                  ],
                ),
              ),
              if (post.publishedAt != null)
                Text(
                  _formatDate(post.publishedAt!),
                  style: AuraText.micro.copyWith(color: AuraSurface.faint),
                ),
            ],
          ),
          if (post.title.isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s10),
            Text(
              post.title,
              style: AuraText.body.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
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
          if (post.mediaUrl != null) ...[
            const SizedBox(height: AuraSpace.s10),
            _MediaThumb(url: post.mediaUrl!, isVideo: false),
          ],
          const SizedBox(height: AuraSpace.s12),
          _ExploreInteractionBar(
            target: InstitutionPostReactionTarget(
              institutionId: post.institutionId,
              postId: post.id,
            ),
          ),
        ],
      ),
      ),
    );
  }
}

class _InstitutionPostCard extends ConsumerWidget {
  const _InstitutionPostCard({required this.post});

  final InstitutionPost post;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () => context.push(
        '/institution/${post.institutionId}/posts/${post.id}',
      ),
      borderRadius: BorderRadius.circular(AuraRadius.card),
      child: Container(
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
          if (post.mediaUrl != null && post.mediaUrl!.isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s10),
            _MediaThumb(url: post.mediaUrl!, isVideo: false),
          ],
          const SizedBox(height: AuraSpace.s12),
          _ExploreInteractionBar(
            target: InstitutionPostReactionTarget(
              institutionId: post.institutionId,
              postId: post.id,
            ),
          ),
        ],
      ),
      ),
    );
  }
}

class _AuthorAvatar extends StatelessWidget {
  const _AuthorAvatar({this.imageUrl, required this.fallback});

  final String? imageUrl;
  final String fallback;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: AuraSurface.accentSoft,
        shape: BoxShape.circle,
        border: Border.all(color: AuraSurface.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: (imageUrl != null && imageUrl!.isNotEmpty)
          ? Image.network(
              imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _initialFallback(fallback),
            )
          : _initialFallback(fallback),
    );
  }

  Widget _initialFallback(String text) {
    return Center(
      child: Text(
        text,
        style: AuraText.small.copyWith(
          color: AuraSurface.accentText,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _MediaThumb extends StatelessWidget {
  const _MediaThumb({required this.url, required this.isVideo});

  final String url;
  final bool isVideo;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AuraRadius.md),
      child: Stack(
        alignment: Alignment.center,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: AuraSurface.subtle,
                child: const Center(
                  child: Icon(Icons.broken_image_outlined,
                      color: AuraSurface.faint),
                ),
              ),
            ),
          ),
          if (isVideo)
            Container(
              padding: const EdgeInsets.all(AuraSpace.s8),
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
        ],
      ),
    );
  }
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
        style: AuraText.micro.copyWith(color: ink, fontWeight: FontWeight.w700),
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

// ── Action bar shared by every Explore card ────────────────────────────────
//
// Phase 1.5: this bar now serves both `_ExploreUserPostCard` (regular Post)
// and `_ExploreInstitutionPostCard` / `_InstitutionPostCard` (InstitutionPost
// rows). The `target` discriminator routes the toggle/state calls to the
// right backend surface.
//
// Reply CTA opens compose pre-loaded with the institution actor when the
// active institution identity has speaker rights; otherwise the user is the
// actor.
class _ExploreInteractionBar extends ConsumerWidget {
  const _ExploreInteractionBar({required this.target});

  final ReactionTarget target;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identity = ref.watch(institutionIdentityProvider);
    final actor = identity != null && identity.id.isNotEmpty
        ? ReactionActor.institution(identity.id)
        : const ReactionActor.user();
    final canActAsInstitution =
        actor.isInstitution && (identity?.canPublishPosts ?? false);

    final reactionKey = ReactionStateKey(target: target, actor: actor);
    final reactionAsync = ref.watch(reactionStateProvider(reactionKey));

    Future<void> toggleLike() async {
      try {
        final repo = ref.read(reactionsRepositoryProvider);
        await repo.toggle(target, actor: actor);
        ref.invalidate(reactionStateProvider(reactionKey));
      } catch (e) {
        if (!context.mounted) return;
        if (e is DioException && e.response?.statusCode == 403) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Only institution speakers can react as institution.',
              ),
            ),
          );
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update like')),
        );
      }
    }

    String composeReplyTarget() {
      final replyKey = target is InstitutionPostReactionTarget
          ? 'replyToInstitutionPostId=${target.postId}'
              '&parentInstitutionId='
              '${(target as InstitutionPostReactionTarget).institutionId}'
          : 'replyTo=${target.postId}';
      final base = '/compose?$replyKey&surface=dm';
      if (actor.isInstitution && canActAsInstitution) {
        return '$base&asInstitution=1'
            '&institutionId=${actor.actorInstitutionId}';
      }
      return base;
    }

    final liked = reactionAsync.maybeWhen(
      data: (s) => s.liked,
      orElse: () => false,
    );
    final likeLabel = reactionAsync.maybeWhen(
      data: (s) {
        final base = s.liked ? 'Liked' : 'Like';
        return s.likeCount > 0 ? '$base · ${s.likeCount}' : base;
      },
      orElse: () => 'Like',
    );

    return Wrap(
      spacing: AuraSpace.s8,
      runSpacing: AuraSpace.s8,
      children: [
        AuraActionPill(
          icon: liked ? Icons.favorite : Icons.favorite_border,
          label: likeLabel,
          onTap: toggleLike,
          active: liked,
        ),
        AuraActionPill(
          icon: Icons.reply_outlined,
          label: 'Reply',
          onTap: () => context.push(composeReplyTarget()),
        ),
      ],
    );
  }
}
