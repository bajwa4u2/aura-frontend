import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/route_targets.dart';
import '../../../core/communication/communication_resolver.dart';
import '../../../core/media/aura_attachment_image.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_responsive.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../feed/domain/feed_item.dart';
import '../../updates/providers.dart';
import '../../correspondence/data/threads_repository.dart';

class ActivityScreen extends ConsumerStatefulWidget {
  const ActivityScreen({super.key});

  @override
  ConsumerState<ActivityScreen> createState() => _ActivityScreenState();
}

enum _ActivityFilter { all, messages, social, announcements, system }

class _ActivityScreenState extends ConsumerState<ActivityScreen> {
  static const _resolver = CommunicationResolver();

  _ActivityFilter _activeFilter = _ActivityFilter.all;

  /// Shell-safe push: rewrites canonical routes (`/posts/:id`, `/u/:handle`,
  /// `/institutions/:slug`) for the current shell context so a user inside an
  /// institution shell stays there. For member-shell routes the helper is a
  /// no-op. Today the member activity surface only runs at top-level
  /// `/activity`; the helper exists so a future `/institution/:id/activity`
  /// or shell-aware notification deeplink stays correct without changing
  /// every call site again.
  void _safePush(String route) {
    if (route.isEmpty) return;
    final adapted = FeedRouting.adaptTargetRoute(
      route,
      currentPath: GoRouterState.of(context).uri.path,
    );
    context.push(adapted);
  }

  List<Map<String, dynamic>> _applyFilter(List<Map<String, dynamic>> items) {
    if (_activeFilter == _ActivityFilter.all) return items;
    return items.where((item) {
      final type = (item['type'] ?? '').toString().toUpperCase();
      switch (_activeFilter) {
        case _ActivityFilter.messages:
          return type == 'MESSAGE_RECEIVED' ||
              type == 'THREAD_INVITE' ||
              type == 'SPACE_INVITE';
        case _ActivityFilter.social:
          return type == 'FOLLOW' ||
              type == 'FOLLOW_REQUEST' ||
              type == 'FOLLOW_ACCEPTED' ||
              type == 'LIKE' ||
              type == 'SAVE' ||
              type == 'REPLY' ||
              type == 'REPOST' ||
              type == 'MENTION';
        case _ActivityFilter.announcements:
          return type == 'ANNOUNCEMENT_PUBLISHED';
        case _ActivityFilter.system:
          return type == 'POST_PUBLISHED' ||
              type == 'POST_PUBLISH_FAILED' ||
              type == 'SYSTEM' ||
              type == 'INVITE_ACCEPTED' ||
              type == 'INVITE_DECLINED' ||
              type == 'INVITE_REVOKED';
        case _ActivityFilter.all:
          return true;
      }
    }).toList();
  }

  Future<void> _markAllRead() async {
    await ref.read(notificationsControllerProvider.notifier).markAllRead();
  }

  Future<void> _handleTap(Map<String, dynamic> item) async {
    final id = _stringOf(item['id']);
    if (id.isNotEmpty && _stringOf(item['readAt']).isEmpty) {
      await ref.read(notificationsControllerProvider.notifier).markRead(id);
    }
    if (!mounted) return;
    await _navigateFromActivity(item);
  }

  Future<void> _navigateFromActivity(Map<String, dynamic> item) async {
    final type = _stringOf(item['type']).toUpperCase();
    final actor = _mapOf(item['actor']);
    final data = _mapOf(item['data']);

    final actorHandle = _stringOf(actor['handle']);
    final targetHandle = _stringOf(data['targetHandle']);
    final handle = targetHandle.isNotEmpty ? targetHandle : actorHandle;

    final realtimeType = _firstNonEmpty([
      _stringOf(data['realtimeType']).toUpperCase(),
      _stringOf(data['notificationKind']).toUpperCase(),
    ]);

    final deeplink = normalizeMemberFacingRoute(
      _firstNonEmpty([
        _stringOf(item['deeplink']),
        _stringOf(data['deeplink']),
        _stringOf(data['link']),
        _stringOf(data['url']),
      ]),
      fallback: '',
    );

    final announcementSlug = _firstNonEmpty([
      _stringOf(item['announcementSlug']),
      _stringOf(data['announcementSlug']),
      _stringOf(data['slug']),
    ]);

    final announcementId = _firstNonEmpty([
      _stringOf(item['announcementId']),
      _stringOf(data['announcementId']),
    ]);

    final postId = _firstNonEmpty([
      _stringOf(item['postId']),
      _stringOf(data['postId']),
      _stringOf(data['targetPostId']),
      _stringOf(data['replyPostId']),
    ]);

    final spaceId = _firstNonEmpty([
      _stringOf(data['spaceId']),
      _stringOf(item['spaceId']),
    ]);

    final threadId = _firstNonEmpty([
      _stringOf(data['threadId']),
      _stringOf(item['threadId']),
    ]);

    final realtimeSessionId = _firstNonEmpty([
      _stringOf(data['sessionId']),
      _stringOf(item['sessionId']),
    ]);

    final communicationTarget = _resolver.resolveFromPayload({
      ...item,
      ...data,
      if (threadId.isNotEmpty) 'threadId': threadId,
      if (spaceId.isNotEmpty) 'spaceId': spaceId,
      if (realtimeSessionId.isNotEmpty) 'sessionId': realtimeSessionId,
      if (deeplink.isNotEmpty) 'deeplink': deeplink,
      if (realtimeType.isNotEmpty) 'realtimeType': realtimeType,
    });

    final isRealtimeActivity =
        realtimeType.startsWith('REALTIME_') ||
        deeplink.startsWith('/realtime') ||
        realtimeSessionId.isNotEmpty;

    if (communicationTarget.owner == CommunicationOwner.thread &&
        (communicationTarget.threadId ?? '').isNotEmpty) {
      await _openThreadTarget(
        threadId: communicationTarget.threadId!,
        spaceIdHint: communicationTarget.spaceId,
        sessionIdHint: communicationTarget.sessionId,
        shouldJoin:
            isRealtimeActivity ||
            (communicationTarget.attention ?? '').toUpperCase() ==
                'INTERRUPT' ||
            (communicationTarget.mode ?? '').toUpperCase().contains('LIVE'),
      );
      return;
    }

    if (communicationTarget.owner == CommunicationOwner.space &&
        (communicationTarget.spaceId ?? '').isNotEmpty) {
      final resolvedRoute = _resolver.resolveRoute(communicationTarget);
      context.push(resolvedRoute);
      return;
    }

    if (isRealtimeActivity) {
      if (threadId.isNotEmpty) {
        await _openThreadTarget(
          threadId: threadId,
          spaceIdHint: spaceId,
          sessionIdHint: realtimeSessionId,
          shouldJoin: true,
        );
        return;
      }
      if (spaceId.isNotEmpty) {
        final route = _withLiveQuery(
          '/me/correspondence/$spaceId',
          sessionId: realtimeSessionId,
          shouldJoin: true,
        );
        context.push(route);
        return;
      }
      if (deeplink.startsWith('/me/correspondence/')) {
        context.push(
          _withLiveQuery(
            deeplink,
            sessionId: realtimeSessionId,
            shouldJoin: true,
          ),
        );
      }
      return;
    }

    if (deeplink.isNotEmpty) {
      if (deeplink.startsWith('/threads/')) {
        final idFromLink = deeplink
            .substring('/threads/'.length)
            .split('?')
            .first
            .trim();
        if (idFromLink.isNotEmpty) {
          await _openThreadTarget(
            threadId: idFromLink,
            spaceIdHint: spaceId,
            sessionIdHint: realtimeSessionId,
            shouldJoin: isRealtimeActivity,
          );
          return;
        }
      }

      if (deeplink.startsWith('/spaces/')) {
        final idFromLink = deeplink
            .substring('/spaces/'.length)
            .split('?')
            .first
            .trim();
        if (idFromLink.isNotEmpty) {
          // Phase 3 — route through `_safePush` so the route is adapted
          // for the current shell context (member vs institution) and
          // the navigator preserves the workspace.
          _safePush(
            _withLiveQuery(
              '/me/correspondence/$idFromLink',
              sessionId: realtimeSessionId,
              shouldJoin: isRealtimeActivity,
            ),
          );
          return;
        }
      }

      if (!deeplink.startsWith('/realtime')) {
        _safePush(
          _withLiveQuery(
            deeplink,
            sessionId: realtimeSessionId,
            shouldJoin: isRealtimeActivity,
          ),
        );
      }
      return;
    }

    switch (type) {
      case 'FOLLOW_REQUEST':
        context.push('/me/follow-requests');
        return;
      case 'FOLLOW_ACCEPTED':
      case 'FOLLOW':
        if (handle.isNotEmpty) _safePush('/u/$handle');
        return;
      case 'LIKE':
      case 'SAVE':
      case 'REPLY':
      case 'REPOST':
      case 'MENTION':
      case 'POST_PUBLISHED':
        if (postId.isNotEmpty) {
          _safePush('/posts/$postId');
          return;
        }
        if (handle.isNotEmpty) _safePush('/u/$handle');
        return;
      case 'POST_PUBLISH_FAILED':
        context.push('/me');
        return;
      case 'ANNOUNCEMENT_PUBLISHED':
        if (announcementSlug.isNotEmpty) {
          context.push('/announcements/$announcementSlug');
          return;
        }
        if (announcementId.isNotEmpty) {
          context.push('/announcements/$announcementId');
          return;
        }
        context.push('/announcements');
        return;
      case 'SPACE_INVITE':
      case 'INVITE_ACCEPTED':
      case 'INVITE_DECLINED':
      case 'INVITE_REVOKED':
        if (spaceId.isNotEmpty) context.push('/me/correspondence/$spaceId');
        return;
      case 'THREAD_INVITE':
      case 'MESSAGE_RECEIVED':
        if (threadId.isNotEmpty) {
          await _openThreadTarget(
            threadId: threadId,
            spaceIdHint: spaceId,
            sessionIdHint: realtimeSessionId,
            shouldJoin: isRealtimeActivity,
          );
          return;
        }
        if (spaceId.isNotEmpty) {
          context.push('/me/correspondence/$spaceId');
        }
        return;
      default:
        if (postId.isNotEmpty) {
          _safePush('/posts/$postId');
          return;
        }
        if (handle.isNotEmpty) {
          _safePush('/u/$handle');
          return;
        }
        if (spaceId.isNotEmpty && threadId.isNotEmpty) {
          context.push(
            _withLiveQuery(
              '/me/correspondence/$spaceId/thread/$threadId',
              sessionId: realtimeSessionId,
              shouldJoin: isRealtimeActivity,
            ),
          );
          return;
        }
        if (spaceId.isNotEmpty) context.push('/me/correspondence/$spaceId');
    }
  }

  Future<void> _openThreadTarget({
    required String threadId,
    String? spaceIdHint,
    String? sessionIdHint,
    bool shouldJoin = false,
  }) async {
    final cleanThreadId = threadId.trim();
    final cleanSpaceId = (spaceIdHint ?? '').trim();
    final cleanSessionId = (sessionIdHint ?? '').trim();

    if (cleanThreadId.isEmpty) {
      context.push('/me/correspondence');
      return;
    }

    if (cleanSpaceId.isNotEmpty) {
      context.push(
        _withLiveQuery(
          '/me/correspondence/$cleanSpaceId/thread/$cleanThreadId',
          sessionId: cleanSessionId,
          shouldJoin: shouldJoin,
        ),
      );
      return;
    }

    try {
      final thread = await ref
          .read(threadsRepositoryProvider)
          .getThread(cleanThreadId);
      if (!mounted) return;

      final resolvedSpaceId = _firstNonEmpty([
        _stringOf(thread['spaceId']),
        _stringOf(thread['space_id']),
      ]);

      if (resolvedSpaceId.isNotEmpty) {
        context.push(
          _withLiveQuery(
            '/me/correspondence/$resolvedSpaceId/thread/$cleanThreadId',
            sessionId: cleanSessionId,
            shouldJoin: shouldJoin,
          ),
        );
        return;
      }
    } catch (_) {}

    if (!mounted) return;
    context.push('/me/correspondence');
  }

  String _withLiveQuery(
    String route, {
    String? sessionId,
    bool shouldJoin = false,
  }) {
    final cleanRoute = route.trim();
    final cleanSessionId = (sessionId ?? '').trim();
    if (!shouldJoin || cleanRoute.isEmpty || cleanSessionId.isEmpty) {
      return cleanRoute;
    }

    final uri = Uri.parse(cleanRoute);
    final query = <String, String>{...uri.queryParameters};
    query['join'] = '1';
    query['sessionId'] = cleanSessionId;

    return uri.replace(queryParameters: query).toString();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationsControllerProvider);
    final allItems = state.items;
    final filteredItems = _applyFilter(allItems);
    final unreadCount = state.unreadCount;

    final unread = filteredItems
        .where((i) => (i['readAt'] ?? '').toString().trim().isEmpty)
        .toList();
    final read = filteredItems
        .where((i) => (i['readAt'] ?? '').toString().trim().isNotEmpty)
        .toList();

    return AuraScaffold(
      showHeader: false,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kFeedWidth),
            child: RefreshIndicator(
              color: AuraSurface.accent,
              onRefresh: () => ref
                  .read(notificationsControllerProvider.notifier)
                  .refresh(force: true),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AuraSpace.s16,
                  AuraSpace.s20,
                  AuraSpace.s16,
                  AuraSpace.s32,
                ),
                children: [
                  _ActivityHeader(
                    unreadCount: unreadCount,
                    onMarkAllRead: allItems.isEmpty ? null : _markAllRead,
                    markingAllRead: state.isRefreshing,
                  ),
                  const SizedBox(height: AuraSpace.s16),
                  _ActivityFilterRow(
                    active: _activeFilter,
                    onChange: (f) => setState(() => _activeFilter = f),
                  ),
                  const SizedBox(height: AuraSpace.s20),
                  if (state.isLoading)
                    const _ActivitySkeletonList()
                  else if ((state.error ?? '').isNotEmpty)
                    AuraErrorState(
                      title: 'Activity unavailable',
                      body: state.error!,
                      action: AuraSecondaryButton(
                        label: 'Try again',
                        onPressed: () => ref
                            .read(notificationsControllerProvider.notifier)
                            .refresh(force: true),
                        icon: Icons.refresh_rounded,
                      ),
                    )
                  else if (filteredItems.isEmpty)
                    const _ActivityEmptyState()
                  else ...[
                    if (unread.isNotEmpty) ...[
                      _ActivitySectionLabel(
                        label: 'New',
                        count: unread.length,
                        accent: true,
                      ),
                      const SizedBox(height: AuraSpace.s10),
                      for (final item in unread)
                        _ActivityTile(
                          item: item,
                          onTap: () => _handleTap(item),
                        ),
                      if (read.isNotEmpty)
                        const SizedBox(height: AuraSpace.s20),
                    ],
                    if (read.isNotEmpty) ...[
                      _ActivitySectionLabel(
                        label: unread.isEmpty ? 'Activity' : 'Earlier',
                        count: read.length,
                      ),
                      const SizedBox(height: AuraSpace.s10),
                      for (final item in read)
                        _ActivityTile(
                          item: item,
                          onTap: () => _handleTap(item),
                        ),
                    ],
                    if ((state.nextCursor ?? '').isNotEmpty) ...[
                      const SizedBox(height: AuraSpace.s20),
                      Center(
                        child: AuraSecondaryButton(
                          label: state.isLoadingMore ? 'Loading…' : 'Load more',
                          onPressed: state.isLoadingMore
                              ? null
                              : () => ref
                                    .read(
                                      notificationsControllerProvider.notifier,
                                    )
                                    .loadMore(),
                          icon: Icons.expand_more_rounded,
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Filter row ─────────────────────────────────────────────────────────────

class _ActivityFilterRow extends StatelessWidget {
  const _ActivityFilterRow({required this.active, required this.onChange});

  final _ActivityFilter active;
  final ValueChanged<_ActivityFilter> onChange;

  @override
  Widget build(BuildContext context) {
    const filters = [
      (_ActivityFilter.all, 'All'),
      (_ActivityFilter.messages, 'Messages'),
      (_ActivityFilter.social, 'Social'),
      (_ActivityFilter.announcements, 'Announcements'),
      (_ActivityFilter.system, 'System'),
    ];

    // Wrap (not horizontal scroll) so narrow viewports lay the pills
    // across two short rows instead of forcing the user to discover a
    // hidden right-edge scroll. On wide viewports everything still fits
    // on a single row.
    return Wrap(
      spacing: AuraSpace.s8,
      runSpacing: AuraSpace.s8,
      children: [
        for (final (filter, label) in filters)
          _FilterPill(
            label: label,
            selected: active == filter,
            onTap: () => onChange(filter),
          ),
      ],
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AuraRadius.pill),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(
              horizontal: AuraSpace.s12,
              vertical: AuraSpace.s6,
            ),
            decoration: BoxDecoration(
              color: selected ? AuraSurface.accentSoft : AuraSurface.card,
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
                fontWeight: FontWeight.w600,
                color: selected ? AuraSurface.accentText : AuraSurface.muted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Section label ──────────────────────────────────────────────────────────

class _ActivitySectionLabel extends StatelessWidget {
  const _ActivitySectionLabel({
    required this.label,
    required this.count,
    this.accent = false,
  });

  final String label;
  final int count;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label.toUpperCase(),
          style: AuraText.label.copyWith(
            color: accent ? AuraSurface.accentText : AuraSurface.faint,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(width: AuraSpace.s8),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AuraSpace.s8,
            vertical: 2,
          ),
          decoration: BoxDecoration(
            color: accent ? AuraSurface.accentSoft : AuraSurface.elevated,
            borderRadius: BorderRadius.circular(AuraRadius.pill),
            border: Border.all(
              color: accent
                  ? AuraSurface.accent.withValues(alpha: 0.3)
                  : AuraSurface.divider,
            ),
          ),
          child: Text(
            '$count',
            style: AuraText.micro.copyWith(
              color: accent ? AuraSurface.accentText : AuraSurface.faint,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Data helpers ───────────────────────────────────────────────────────────

Map<String, dynamic> _mapOf(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, val) => MapEntry(key.toString(), val));
  }
  return const {};
}

String _stringOf(dynamic value) {
  if (value == null) return '';
  return value.toString().trim();
}

String _firstNonEmpty(List<String> values) {
  for (final value in values) {
    if (value.trim().isNotEmpty) return value.trim();
  }
  return '';
}

class _ActivityHeader extends StatelessWidget {
  const _ActivityHeader({
    required this.unreadCount,
    required this.onMarkAllRead,
    required this.markingAllRead,
  });

  final int unreadCount;
  final VoidCallback? onMarkAllRead;
  final bool markingAllRead;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Activity', style: AuraText.headline),
              const SizedBox(height: AuraSpace.s4),
              if (unreadCount > 0)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AuraSurface.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: AuraSpace.s6),
                    Text(
                      '$unreadCount unread',
                      style: AuraText.small.copyWith(
                        color: AuraSurface.accentText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                )
            ],
          ),
        ),
        if (onMarkAllRead != null)
          AuraActionPill(
            icon: Icons.done_all_rounded,
            label: markingAllRead ? 'Marking…' : 'Mark all read',
            onTap: markingAllRead ? () {} : onMarkAllRead!,
          ),
      ],
    );
  }
}

class _ActivitySkeletonList extends StatelessWidget {
  const _ActivitySkeletonList();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        5,
        (_) => const Padding(
          padding: EdgeInsets.only(bottom: AuraSpace.s12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AuraSkeleton(width: 40, height: 40, radius: AuraRadius.pill),
              SizedBox(width: AuraSpace.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AuraSkeleton(
                      width: double.infinity,
                      height: 14,
                      radius: AuraRadius.r10,
                    ),
                    SizedBox(height: AuraSpace.s8),
                    AuraSkeleton(
                      width: 160,
                      height: 12,
                      radius: AuraRadius.r10,
                    ),
                  ],
                ),
              ),
              SizedBox(width: AuraSpace.s12),
              AuraSkeleton(width: 32, height: 12, radius: AuraRadius.r10),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivityEmptyState extends StatelessWidget {
  const _ActivityEmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AuraSpace.s32),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AuraSurface.subtle,
              shape: BoxShape.circle,
              border: Border.all(color: AuraSurface.divider),
            ),
            child: const Icon(
              Icons.notifications_none_rounded,
              size: 24,
              color: AuraSurface.muted,
            ),
          ),
          const SizedBox(height: AuraSpace.s14),
          Text(
            'All caught up',
            style: AuraText.subtitle.copyWith(color: AuraSurface.ink),
          ),
          const SizedBox(height: AuraSpace.s6),
          Text(
            'You\'re up to date.',
            style: AuraText.small.copyWith(color: AuraSurface.muted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.item, required this.onTap});

  final Map<String, dynamic> item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final actor = _mapOf(item['actor']);
    final type = _stringOf(item['type']).toUpperCase();
    final title = _buildTitle(item);
    final subtitle = _buildSubtitle(item);
    final cta = _ctaLabel(item);
    final timeLabel = _timeAgoLabel(item['createdAt']);
    final unread = _stringOf(item['readAt']).isEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: AuraSpace.s4),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AuraRadius.card),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(
                horizontal: AuraSpace.s12,
                vertical: AuraSpace.s14,
              ),
              decoration: BoxDecoration(
                color: unread ? AuraSurface.subtle : Colors.transparent,
                borderRadius: BorderRadius.circular(AuraRadius.card),
                border: unread
                    ? Border.all(
                        color: AuraSurface.accent.withValues(alpha: 0.15),
                      )
                    : null,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ActivityLeadingIcon(
                    type: type,
                    avatarUrl: _stringOf(actor['avatarUrl']),
                    unread: unread,
                  ),
                  const SizedBox(width: AuraSpace.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: AuraText.small.copyWith(
                            fontWeight:
                                unread ? FontWeight.w700 : FontWeight.w600,
                            color: AuraSurface.ink,
                          ),
                        ),
                        if (subtitle.isNotEmpty) ...[
                          const SizedBox(height: AuraSpace.s4),
                          Text(
                            subtitle,
                            style: AuraText.small.copyWith(
                              color: AuraSurface.muted,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: AuraSpace.s6),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              cta,
                              style: AuraText.small.copyWith(
                                color: AuraSurface.accentText,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 2),
                            const Icon(
                              Icons.arrow_forward_rounded,
                              size: 12,
                              color: AuraSurface.accentText,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AuraSpace.s8),
                  Text(
                    timeLabel,
                    style: AuraText.micro.copyWith(color: AuraSurface.faint),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActivityLeadingIcon extends StatelessWidget {
  const _ActivityLeadingIcon({
    required this.type,
    required this.avatarUrl,
    required this.unread,
  });

  final String type;
  final String avatarUrl;
  final bool unread;

  IconData _iconForType() {
    switch (type) {
      case 'FOLLOW':
      case 'FOLLOW_REQUEST':
      case 'FOLLOW_ACCEPTED':
        return Icons.person_add_alt_1_outlined;
      case 'REPLY':
      case 'MENTION':
        return Icons.reply_outlined;
      case 'REPOST':
        return Icons.repeat_rounded;
      case 'LIKE':
        return Icons.favorite_border_rounded;
      case 'SAVE':
        return Icons.bookmark_border_rounded;
      case 'SPACE_INVITE':
      case 'THREAD_INVITE':
      case 'INVITE_ACCEPTED':
        return Icons.mail_outline_rounded;
      case 'POST_PUBLISHED':
        return Icons.check_circle_outline_rounded;
      case 'ANNOUNCEMENT_PUBLISHED':
        return Icons.campaign_outlined;
      case 'MESSAGE_RECEIVED':
        return Icons.mail_outline_rounded;
      case 'POST_PUBLISH_FAILED':
        return Icons.error_outline_rounded;
      default:
        return Icons.notifications_none_rounded;
    }
  }

  Color _iconColor() {
    switch (type) {
      case 'LIKE':
        return const Color(0xFFE8738A);
      case 'ANNOUNCEMENT_PUBLISHED':
      case 'POST_PUBLISHED':
        return AuraSurface.accentText;
      case 'POST_PUBLISH_FAILED':
        return AuraSurface.warnInk;
      case 'MESSAGE_RECEIVED':
      case 'THREAD_INVITE':
      case 'SPACE_INVITE':
        return AuraSurface.accentText;
      default:
        return AuraSurface.muted;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AuraSurface.card,
            borderRadius: BorderRadius.circular(AuraRadius.pill),
            border: Border.all(color: AuraSurface.divider),
          ),
          child: avatarUrl.isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(AuraRadius.pill),
                  child: AuraAttachmentImage(
                    url: avatarUrl,
                    fit: BoxFit.cover,
                    errorWidget: (_) =>
                        Icon(_iconForType(), size: 18, color: _iconColor()),
                  ),
                )
              : Icon(_iconForType(), size: 18, color: _iconColor()),
        ),
        if (unread)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              width: 11,
              height: 11,
              decoration: BoxDecoration(
                color: AuraSurface.accent,
                borderRadius: BorderRadius.circular(AuraRadius.pill),
                border: Border.all(color: AuraSurface.page, width: 2),
              ),
            ),
          ),
      ],
    );
  }
}

String _resolveCallType(Map<String, dynamic> data) {
  final raw = _firstNonEmpty([
    _stringOf(data['mediaMode']),
    _stringOf(data['mode']),
    _stringOf(data['kind']),
    _stringOf(data['sessionType']),
  ]).toUpperCase();
  switch (raw) {
    case 'VIDEO':
      return 'video call';
    case 'SCREEN':
      return 'screen share';
    default:
      return 'audio call';
  }
}

String _buildTitle(Map<String, dynamic> item) {
  final type = _stringOf(item['type']).toUpperCase();
  final actor = _mapOf(item['actor']);
  final data = _mapOf(item['data']);
  final actorName = _firstNonEmpty([
    _stringOf(actor['displayName']),
    _stringOf(actor['handle']),
    'Someone',
  ]);
  final notifKind = _firstNonEmpty([
    _stringOf(data['notificationKind']).toUpperCase(),
    _stringOf(data['realtimeType']).toUpperCase(),
  ]);

  // LIVE type — distinguish call invite vs missed call
  if (type == 'LIVE') {
    final callType = _resolveCallType(data);
    if (notifKind == 'CALL_RINGING' || notifKind == 'REALTIME_INVITE') {
      return '$actorName invited you to an $callType';
    }
    if (notifKind == 'CALL_MISSED') {
      return 'Missed $callType from $actorName';
    }
    return '$actorName started a $callType';
  }

  switch (type) {
    case 'FOLLOW_REQUEST':
      return '$actorName sent you a follow request';
    case 'FOLLOW_ACCEPTED':
      return '$actorName accepted your follow request';
    case 'FOLLOW':
      return '$actorName followed you';
    case 'LIKE':
      return '$actorName appreciated your work';
    case 'SAVE':
      return '$actorName saved your work';
    case 'REPLY':
      return '$actorName replied to your work';
    case 'REPOST':
      return '$actorName reposted your work';
    case 'MENTION':
      return '$actorName mentioned you';
    case 'SPACE_INVITE':
      return '$actorName invited you to a space';
    case 'THREAD_INVITE':
      return '$actorName invited you to a thread';
    case 'MESSAGE_RECEIVED':
      return '$actorName sent you a message';
    case 'INVITE_ACCEPTED':
      return '$actorName accepted your invitation';
    case 'INVITE_DECLINED':
      return '$actorName declined your invitation';
    case 'INVITE_REVOKED':
      return '$actorName revoked an invitation';
    case 'ANNOUNCEMENT_PUBLISHED':
      final title = _firstNonEmpty([
        _stringOf(item['title']),
        _stringOf(data['title']),
      ]);
      return title.isNotEmpty ? title : 'New announcement';
    case 'POST_PUBLISHED':
      return 'Your work was published';
    case 'POST_PUBLISH_FAILED':
      return 'A work could not be published';
    case 'SYSTEM':
      final title = _stringOf(data['title']);
      return title.isNotEmpty ? title : 'System notice';
    default:
      final fallbackTitle = _firstNonEmpty([
        _stringOf(item['title']),
        _stringOf(data['title']),
      ]);
      return fallbackTitle.isNotEmpty ? fallbackTitle : 'New notification';
  }
}

String _buildSubtitle(Map<String, dynamic> item) {
  final type = _stringOf(item['type']).toUpperCase();
  final post = _mapOf(item['post']);
  final data = _mapOf(item['data']);

  // LIVE type — show context label ("in Design Space", "Direct call")
  if (type == 'LIVE') {
    final contextLabel = _firstNonEmpty([
      _stringOf(data['contextLabel']),
      _stringOf(data['contextName']),
      _stringOf(data['roomTitle']),
      _stringOf(data['spaceName']),
      _stringOf(data['threadTitle']),
    ]);
    return contextLabel.isNotEmpty ? 'in $contextLabel' : '';
  }

  final customMessage = _firstNonEmpty([
    _stringOf(data['secondaryText']),
    _stringOf(data['message']),
    _stringOf(data['body']),
  ]);
  if (customMessage.isNotEmpty) return customMessage;

  final postText = _stringOf(post['text']);
  if (postText.isNotEmpty) return _truncate(postText, 120);

  switch (type) {
    case 'FOLLOW_REQUEST':
      return 'Open requests';
    case 'FOLLOW_ACCEPTED':
    case 'FOLLOW':
      return 'Open profile';
    case 'REPLY':
    case 'LIKE':
    case 'SAVE':
    case 'REPOST':
    case 'MENTION':
    case 'POST_PUBLISHED':
      return 'Open work';
    case 'SPACE_INVITE':
      final spaceName = _stringOf(data['spaceName']);
      return spaceName.isNotEmpty ? 'in $spaceName' : 'Open space';
    case 'THREAD_INVITE':
    case 'MESSAGE_RECEIVED':
      return 'Open conversation';
    case 'INVITE_ACCEPTED':
    case 'INVITE_DECLINED':
    case 'INVITE_REVOKED':
      return 'Open messages';
    case 'ANNOUNCEMENT_PUBLISHED':
      return 'Read announcement';
    case 'POST_PUBLISH_FAILED':
      return 'Return to presence';
    default:
      return '';
  }
}

String _ctaLabel(Map<String, dynamic> item) {
  final type = _stringOf(item['type']).toUpperCase();
  final data = _mapOf(item['data']);
  final notifKind = _firstNonEmpty([
    _stringOf(data['notificationKind']).toUpperCase(),
    _stringOf(data['realtimeType']).toUpperCase(),
  ]);

  // LIVE type CTAs
  if (type == 'LIVE') {
    if (notifKind == 'CALL_RINGING' || notifKind == 'REALTIME_INVITE') return 'Join';
    return 'View';
  }
  switch (type) {
    case 'MESSAGE_RECEIVED':
    case 'THREAD_INVITE':
      return 'Reply';
    case 'SPACE_INVITE':
    case 'INVITE_ACCEPTED':
    case 'INVITE_DECLINED':
    case 'INVITE_REVOKED':
      return 'Open';
    case 'FOLLOW_REQUEST':
      return 'Review';
    case 'FOLLOW':
    case 'FOLLOW_ACCEPTED':
      return 'View';
    case 'LIKE':
    case 'SAVE':
    case 'REPLY':
    case 'REPOST':
    case 'MENTION':
    case 'POST_PUBLISHED':
      return 'View';
    case 'ANNOUNCEMENT_PUBLISHED':
      return 'Read';
    default:
      return 'Open';
  }
}

String _truncate(String value, int max) {
  final text = value.trim();
  if (text.length <= max) return text;
  return '${text.substring(0, max - 1).trimRight()}…';
}

String _timeAgoLabel(dynamic raw) {
  final value = _stringOf(raw);
  if (value.isEmpty) return '';
  final createdAt = DateTime.tryParse(value)?.toLocal();
  if (createdAt == null) return '';
  final now = DateTime.now();
  final diff = now.difference(createdAt);
  if (diff.inSeconds < 60) return 'now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}h';
  if (diff.inDays < 7) return '${diff.inDays}d';
  if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w';
  if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}mo';
  return '${(diff.inDays / 365).floor()}y';
}
