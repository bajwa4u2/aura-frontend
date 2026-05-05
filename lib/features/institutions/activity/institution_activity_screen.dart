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
import '../../feed/domain/feed_item.dart';
import '../data/institutions_repository.dart';
import '../domain/institution_activity_event.dart';

/// Human-readable summary for known activity event kinds. Unknown kinds
/// fall back to the raw `kind` string verbatim.
String _summaryForKind(InstitutionActivityEvent e) {
  final actorName = (e.actor?['displayName']?.toString().trim().isNotEmpty ?? false)
      ? e.actor!['displayName'].toString().trim()
      : (e.actor?['handle']?.toString().trim().isNotEmpty ?? false)
          ? '@${e.actor!['handle']}'
          : 'Someone';

  switch (e.kind.toUpperCase()) {
    case 'MEMBER_JOINED':
      return '$actorName joined the institution.';
    case 'MEMBER_LEFT':
      return '$actorName left the institution.';
    case 'MEMBER_REMOVED':
      return '$actorName was removed.';
    case 'ROLE_CHANGED':
      final newRole = e.metadata?['newRole']?.toString().trim() ?? '';
      return newRole.isNotEmpty
          ? "$actorName's role changed to $newRole."
          : "$actorName's role was updated.";
    case 'INVITE_SENT':
      return '$actorName sent an invite.';
    case 'INVITE_ACCEPTED':
      return '$actorName accepted an invite.';
    case 'JOIN_REQUEST_CREATED':
      return '$actorName requested to join.';
    case 'JOIN_REQUEST_APPROVED':
      return 'A join request was approved.';
    case 'JOIN_REQUEST_REJECTED':
      return 'A join request was rejected.';
    case 'POST_CREATED':
      return '$actorName drafted a new post.';
    case 'POST_PUBLISHED':
      return '$actorName published a post.';
    case 'POST_ARCHIVED':
      return 'A post was archived.';
    case 'POST_SUBMITTED':
      return '$actorName submitted a post for review.';
    case 'INSTITUTION_VERIFIED':
      return 'Institution was verified.';
    case 'INSTITUTION_SUSPENDED':
      return 'Institution was suspended.';
    case 'INSTITUTION_UPDATED':
      return 'Institution profile was updated.';
    default:
      return e.kind;
  }
}

class InstitutionActivityScreen extends ConsumerStatefulWidget {
  const InstitutionActivityScreen({
    super.key,
    required this.institutionId,
  });

  final String institutionId;

  @override
  ConsumerState<InstitutionActivityScreen> createState() =>
      _InstitutionActivityScreenState();
}

class _InstitutionActivityScreenState
    extends ConsumerState<InstitutionActivityScreen> {
  String _filter = 'all'; // all | members | posts | admin

  final _scrollController = ScrollController();
  final List<InstitutionActivityEvent> _additional = [];
  String? _cursor;
  bool _exhausted = false;
  bool _loadingMore = false;
  String? _moreError;

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
      final next = await repo.listInstitutionActivity(
        institutionId: widget.institutionId,
        cursor: _cursor,
        limit: 30,
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
        _loadingMore = false;
        _moreError = 'Could not load more activity: $e';
      });
    }
  }

  void _selectFilter(String value) {
    if (_filter == value) return;
    setState(() {
      _filter = value;
      _additional.clear();
      _cursor = null;
      _exhausted = false;
      _moreError = null;
    });
  }

  List<InstitutionActivityEvent> _applyFilter(
    List<InstitutionActivityEvent> events,
  ) {
    if (_filter == 'all') return events;
    return events.where((e) => e.category == _filter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final identity = ref.watch(institutionIdentityProvider);
    final isAdminLike = identity?.canPublishPosts ?? false;

    final args = InstitutionActivityArgs(institutionId: widget.institutionId);
    final firstPage = ref.watch(institutionActivityFirstPageProvider(args));

    return AuraScaffold(
      showHeader: false,
      body: firstPage.when(
        loading: () => const AuraLoadingState(message: 'Loading activity…'),
        error: (e, _) => ListView(
          padding: const EdgeInsets.all(AuraSpace.s16),
          children: [
            AuraErrorState(
              title: 'Could not load activity',
              body: '$e',
              action: AuraSecondaryButton(
                label: 'Try again',
                icon: Icons.refresh_rounded,
                onPressed: () => ref
                    .invalidate(institutionActivityFirstPageProvider(args)),
              ),
            ),
          ],
        ),
        data: (page) {
          if (_cursor == null && !_exhausted) {
            _cursor = page.nextCursor;
            _exhausted = !page.hasMore;
          }
          final all = <InstitutionActivityEvent>[
            ...page.items,
            ..._additional,
          ];
          final filtered = _applyFilter(all);
          final grouped = _groupByDay(filtered);

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _additional.clear();
                _cursor = null;
                _exhausted = false;
                _moreError = null;
              });
              ref.invalidate(institutionActivityFirstPageProvider(args));
            },
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(
                AuraSpace.s16,
                AuraSpace.s20,
                AuraSpace.s16,
                AuraSpace.s32,
              ),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 920),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Activity', style: AuraText.headline),
                        const SizedBox(height: AuraSpace.s6),
                        Text(
                          'Recent events for this institution.',
                          style: AuraText.body
                              .copyWith(color: AuraSurface.muted),
                        ),
                        const SizedBox(height: AuraSpace.s14),
                        _FilterRow(
                          current: _filter,
                          onSelect: _selectFilter,
                          showAdmin: isAdminLike,
                        ),
                        const SizedBox(height: AuraSpace.s18),
                        if (filtered.isEmpty)
                          const AuraEmptyState(
                            icon: Icons.timeline_rounded,
                            title: 'No activity yet',
                            body:
                                'When members do things, events will appear here.',
                          )
                        else
                          ...grouped.expand(
                            (group) => [
                              _DaySectionHeader(label: group.label),
                              const SizedBox(height: AuraSpace.s8),
                              ...group.events.map(
                                (e) => Padding(
                                  padding: const EdgeInsets.only(
                                      bottom: AuraSpace.s8),
                                  child: _ActivityCard(event: e),
                                ),
                              ),
                              const SizedBox(height: AuraSpace.s14),
                            ],
                          ),
                        if (_loadingMore)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(AuraSpace.s16),
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2),
                              ),
                            ),
                          ),
                        if (_moreError != null)
                          Padding(
                            padding: const EdgeInsets.all(AuraSpace.s12),
                            child: Text(
                              _moreError!,
                              style: AuraText.small
                                  .copyWith(color: AuraSurface.dangerInk),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DayGroup {
  const _DayGroup({required this.label, required this.events});
  final String label;
  final List<InstitutionActivityEvent> events;
}

List<_DayGroup> _groupByDay(List<InstitutionActivityEvent> events) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));

  final groups = <String, List<InstitutionActivityEvent>>{};
  final order = <String>[];

  for (final e in events) {
    final dt = e.createdAt?.toLocal();
    String label;
    if (dt == null) {
      label = 'Earlier';
    } else {
      final d = DateTime(dt.year, dt.month, dt.day);
      if (d == today) {
        label = 'Today';
      } else if (d == yesterday) {
        label = 'Yesterday';
      } else {
        label = '${d.year}-${d.month.toString().padLeft(2, '0')}-'
            '${d.day.toString().padLeft(2, '0')}';
      }
    }
    if (!groups.containsKey(label)) {
      groups[label] = [];
      order.add(label);
    }
    groups[label]!.add(e);
  }

  return [for (final l in order) _DayGroup(label: l, events: groups[l]!)];
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.current,
    required this.onSelect,
    required this.showAdmin,
  });

  final String current;
  final ValueChanged<String> onSelect;
  final bool showAdmin;

  @override
  Widget build(BuildContext context) {
    final chips = <(String, String)>[
      ('all', 'All'),
      ('members', 'Members'),
      ('posts', 'Posts'),
      if (showAdmin) ('admin', 'Admin'),
    ];

    return Wrap(
      spacing: AuraSpace.s8,
      runSpacing: AuraSpace.s8,
      children: [
        for (final c in chips)
          _FilterChip(
            label: c.$2,
            selected: current == c.$1,
            onTap: () => onSelect(c.$1),
          ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AuraRadius.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AuraSpace.s14,
          vertical: AuraSpace.s8,
        ),
        decoration: BoxDecoration(
          color: selected ? AuraSurface.accentSoft : AuraSurface.subtle,
          borderRadius: BorderRadius.circular(AuraRadius.pill),
          border: Border.all(
            color: selected
                ? AuraSurface.accent.withValues(alpha: 0.4)
                : AuraSurface.divider,
          ),
        ),
        child: Text(
          label,
          style: AuraText.small.copyWith(
            color: selected ? AuraSurface.accentText : AuraSurface.muted,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _DaySectionHeader extends StatelessWidget {
  const _DaySectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: AuraText.micro.copyWith(
        color: AuraSurface.faint,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.event});

  final InstitutionActivityEvent event;

  @override
  Widget build(BuildContext context) {
    final actorName = event.actor?['displayName']?.toString().trim() ?? '';
    final summary = _summaryForKind(event);
    final time = event.createdAt != null ? _formatTime(event.createdAt!) : '';

    // Backend now ships a canonical `targetRoute` on each event when it
    // refers to a navigable entity (post, announcement, etc.). For events
    // that don't resolve to a target (INSTITUTION_VERIFIED, role changes,
    // …) the row stays untappable.
    final route = event.targetRoute;
    final adapted = route == null || route.isEmpty
        ? null
        : FeedRouting.adaptTargetRoute(
            route,
            currentPath: GoRouterState.of(context).uri.path,
          );

    final card = Container(
      padding: const EdgeInsets.all(AuraSpace.s12),
      decoration: BoxDecoration(
        color: AuraSurface.card,
        borderRadius: BorderRadius.circular(AuraRadius.card),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AuraAvatar(name: actorName.isNotEmpty ? actorName : event.kind, size: 32),
          const SizedBox(width: AuraSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  summary,
                  style: AuraText.body.copyWith(
                    color: AuraSurface.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      event.kind,
                      style:
                          AuraText.micro.copyWith(color: AuraSurface.faint),
                    ),
                    if (time.isNotEmpty) ...[
                      const SizedBox(width: AuraSpace.s8),
                      const Text('·',
                          style: TextStyle(color: AuraSurface.faint)),
                      const SizedBox(width: AuraSpace.s8),
                      Text(
                        time,
                        style: AuraText.micro
                            .copyWith(color: AuraSurface.faint),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (adapted != null)
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 12,
              color: AuraSurface.faint,
            ),
        ],
      ),
    );

    if (adapted == null) return card;
    return InkWell(
      onTap: () => context.push(adapted),
      borderRadius: BorderRadius.circular(AuraRadius.card),
      child: card,
    );
  }

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }
}
