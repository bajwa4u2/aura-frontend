import 'package:aura/core/product/temporal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/institutions/institution_access_provider.dart';
import '../../../core/product/product_language.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../feed/domain/feed_item.dart';
import '../data/institutions_repository.dart';
import '../domain/institution_activity_event.dart';
import '../workspace/workspace_page.dart';
import '../../../core/identity/person_identity_model.dart';
import '../institution_words.dart';

/// Human-readable summary for activity event kinds. A kind not named here
/// says so in plain words — the server's code never reaches the screen
/// (phase 2, 2026-10-09).
String _summaryForKind(InstitutionActivityEvent e) {
  // F053/F116 — the same reader and the same fallback order as every other
  // surface. This chain already ended in 'Someone', which is what the shared
  // fallback now supplies from one place instead of being re-derived here.
  final actorName = AuraPersonIdentity.fromJson(e.actor).label;

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
          ? "$actorName is now ${_article(institutionRoleWord(newRole))}."
          : "$actorName's role was updated.";
    case 'INVITE_SENT':
      return '$actorName sent an invite.';
    case 'INVITE_ACCEPTED':
      return '$actorName accepted an invite.';
    case 'INVITE_REVOKED':
      return '$actorName withdrew an invite.';
    case 'CAPABILITY_GRANTED':
      return '$actorName gave someone permission to '
          '${institutionCapabilityWords(e.metadata?['capability'])}.';
    case 'CAPABILITY_REVOKED':
      return '$actorName took back permission to '
          '${institutionCapabilityWords(e.metadata?['capability'])}.';
    case 'OWNERSHIP_TRANSFERRED':
      return 'Ownership of the institution was handed over.';
    case 'OWNERSHIP_RECOVERY':
      return 'Aura restored an owner to the institution.';
    case 'INSTITUTION_APPROVED':
      return 'The institution was set up on Aura.';
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
    case 'POST_UPDATED':
      return '$actorName edited a post.';
    case 'POST_DELETED':
      return 'A post was deleted.';
    case 'INSTITUTION_POST_INTEGRITY_SATISFIED':
    case 'ANNOUNCEMENT_INTEGRITY_SATISFIED':
      return 'A notice passed its review.';
    case 'INSTITUTION_POST_INTEGRITY_ESCALATED':
    case 'ANNOUNCEMENT_INTEGRITY_ESCALATED':
      return 'A notice was sent for a second review.';
    case 'INSTITUTION_VERIFIED':
      return 'Institution was verified.';
    case 'INSTITUTION_SUSPENDED':
      return 'Institution was suspended.';
    case 'INSTITUTION_UPDATED':
      return 'Institution profile was updated.';
    case 'MEETING_STARTED':
      final mTitle = e.metadata?['meetingTitle']?.toString().trim() ?? '';
      return mTitle.isNotEmpty
          ? '$actorName started "$mTitle".'
          : '$actorName started a meeting.';
    case 'MEETING_ENDED':
      final mTitle = e.metadata?['meetingTitle']?.toString().trim() ?? '';
      return mTitle.isNotEmpty
          ? 'Meeting "$mTitle" ended.'
          : 'A meeting ended.';
    case 'MEETING_OUTCOMES_SAVED':
      final mTitle = e.metadata?['meetingTitle']?.toString().trim() ?? '';
      final count = e.metadata?['outcomeCount'];
      final countLabel = count != null ? ' ($count item${count == 1 ? '' : 's'})' : '';
      return mTitle.isNotEmpty
          ? '$actorName saved outcomes for "$mTitle"$countLabel.'
          : '$actorName saved meeting outcomes$countLabel.';
    default:
      return actorName.isNotEmpty && actorName != 'Someone'
          ? 'Activity by $actorName.'
          : 'Activity in the workspace.';
  }
}

String _article(String word) =>
    RegExp(r'^[aeiou]').hasMatch(word) ? 'an $word' : 'a $word';

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

  final List<InstitutionActivityEvent> _additional = [];
  String? _cursor;
  bool _exhausted = false;
  bool _loadingMore = false;
  String? _moreError;

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

  void _refresh(InstitutionActivityArgs args) {
    setState(() {
      _additional.clear();
      _cursor = null;
      _exhausted = false;
      _moreError = null;
    });
    ref.invalidate(institutionActivityFirstPageProvider(args));
  }

  @override
  Widget build(BuildContext context) {
    final identity = ref.watch(institutionIdentityProvider);
    final isAdminLike = identity?.canPublishPosts ?? false;

    final args = InstitutionActivityArgs(institutionId: widget.institutionId);
    final firstPage = ref.watch(institutionActivityFirstPageProvider(args));

    // The one tabs idiom (DD-43), from the same filter it always had.
    final tabs = <WorkspaceTab>[
      const WorkspaceTab(id: 'all', label: 'All'),
      const WorkspaceTab(id: 'members', label: 'Members'),
      const WorkspaceTab(id: 'posts', label: 'Posts'),
      if (isAdminLike) const WorkspaceTab(id: 'admin', label: 'Admin'),
    ];

    WorkspacePage page(List<Widget> children, {bool loading = false}) => WorkspacePage(
          type: WorkspacePageType.collection,
          title: 'Activity',
          purpose: 'What has happened at the institution, newest first.',
          more: [
            WorkspaceAction(
              label: 'Refresh',
              icon: Icons.refresh_rounded,
              onPressed: () => _refresh(args),
            ),
          ],
          tabs: tabs,
          selectedTab: _filter,
          onTab: _selectFilter,
          loading: loading,
          children: children,
        );

    return firstPage.when(
      loading: () => page(const [], loading: true),
      error: (e, _) => page([
        WorkspaceEmpty(
          icon: Icons.error_outline_rounded,
          title: 'Could not load activity',
          body: '$e',
          action: WorkspaceAction(
            label: ProductLabels.of(ProductAction.retry),
            icon: Icons.refresh_rounded,
            onPressed: () => ref.invalidate(institutionActivityFirstPageProvider(args)),
          ),
        ),
      ]),
      data: (firstPageData) {
        if (_cursor == null && !_exhausted) {
          _cursor = firstPageData.nextCursor;
          _exhausted = !firstPageData.hasMore;
        }
        final all = <InstitutionActivityEvent>[
          ...firstPageData.items,
          ..._additional,
        ];
        final filtered = _applyFilter(all);
        final grouped = _groupByDay(filtered);

        return page([
          if (filtered.isEmpty)
            const WorkspaceEmpty(
              icon: Icons.timeline_rounded,
              title: 'No activity yet',
              body: 'When members do things, events will appear here.',
            )
          else
            for (final group in grouped) ...[
              _DaySectionHeader(label: group.label),
              const SizedBox(height: AuraSpace.s8),
              for (final e in group.events) _ActivityCard(event: e),
              const SizedBox(height: AuraSpace.s14),
            ],
          // The frame owns the scrolling, so more is asked for, not sensed.
          if (!_exhausted && filtered.isNotEmpty)
            Center(
              child: AuraSecondaryButton(
                label: _loadingMore ? 'Loading…' : 'Load more',
                icon: _loadingMore ? Icons.hourglass_empty_rounded : Icons.expand_more_rounded,
                onPressed: _loadingMore ? null : _loadMore,
              ),
            ),
          if (_moreError != null)
            Padding(
              padding: const EdgeInsets.all(AuraSpace.s12),
              child: Text(
                _moreError!,
                style: AuraText.small.copyWith(color: AuraSurface.dangerInk),
              ),
            ),
        ]);
      },
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
        label = AuraTemporal.day(d);
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

class _DaySectionHeader extends StatelessWidget {
  const _DaySectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(label.toUpperCase(), style: WorkspaceType.eyebrow);
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.event});

  final InstitutionActivityEvent event;

  @override
  Widget build(BuildContext context) {
    // THE WHOLE IDENTITY, not one field off it. Reading `.displayName` and
    // discarding the rest is the partial-adoption pattern that left the actor
    // as an initial while the same person rendered with a photo elsewhere.
    final actor = AuraPersonIdentity.fromJson(event.actor);
    final actorName = actor.displayName;
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

    return WorkspaceRow(
      leading: AuraAvatar(
        name: actorName.isNotEmpty ? actorName : 'Aura',
        imageUrl: actor.avatarUrl,
        size: 36,
      ),
      title: summary,
      context: time.isEmpty ? null : time,
      trailing: adapted == null
          ? null
          : const Icon(Icons.chevron_right_rounded, size: 18, color: AuraSurface.faint),
      onTap: adapted == null ? null : () => context.push(adapted),
    );
  }

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    // The product writes times as "9:04 AM", never "09:04".
    final h = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final mm = local.minute.toString().padLeft(2, '0');
    return '$h:$mm ${local.hour >= 12 ? 'PM' : 'AM'}';
  }
}
