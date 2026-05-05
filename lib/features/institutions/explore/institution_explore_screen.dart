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
import '../../feed/presentation/unified_feed_card.dart';

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
    return const AuraEmptyState(
      icon: Icons.lock_outline_rounded,
      title: 'No content available',
      body: 'You do not have access to any post visibility scope yet.',
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
          return AuraEmptyState(
            icon: _emptyIcon(),
            title: widget.emptyTitle,
            body: widget.emptyBody,
          );
        }
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(institutionExploreFeedProvider(args));
            await ref.read(institutionExploreFeedProvider(args).future);
          },
          child: ListView.separated(
            padding: const EdgeInsets.all(AuraSpace.s16),
            itemCount: page.items.length,
            separatorBuilder: (_, __) =>
                const SizedBox(height: AuraSpace.s10),
            itemBuilder: (context, i) =>
                UnifiedFeedCard(item: page.items[i]),
          ),
        );
      },
    );
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
