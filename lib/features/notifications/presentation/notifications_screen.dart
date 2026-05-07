import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/interactions/actor_context.dart';
import '../../../core/interactions/notifications_repository.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../feed/domain/feed_item.dart';

/// Phase-3 actor-aware notifications list. Each row carries enough data to
/// route on tap (post detail, institution-post detail, direct thread,
/// profile) and renders the actor as either an institution or a user.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  bool _markingRead = false;

  Future<void> _markAllRead() async {
    if (_markingRead) return;
    setState(() => _markingRead = true);
    try {
      await ref.read(notificationsRepositoryProvider).markAllRead();
      ref.invalidate(notificationsListProvider);
      ref.invalidate(unreadNotificationCountProvider);
    } catch (_) {
      // No-op — the list refresh will reveal any persistent failure.
    } finally {
      if (mounted) setState(() => _markingRead = false);
    }
  }

  Future<void> _onTap(AppNotification n, {List<String> alsoMark = const []}) async {
    // Mark this row (and any other ids in the same group) as read.
    final ids = <String>{n.id, ...alsoMark}.toList(growable: false);
    try {
      await ref.read(notificationsRepositoryProvider).markRead(ids);
      ref.invalidate(notificationsListProvider);
      ref.invalidate(unreadNotificationCountProvider);
    } catch (_) {}

    if (!mounted) return;
    final route = _routeFor(n);
    if (route == null) return;
    // Route through the shared shell adapter so notifications opened from
    // inside an institution shell preserve that shell; otherwise the
    // canonical route is returned untouched.
    final adapted = FeedRouting.adaptTargetRoute(
      route,
      currentPath: GoRouterState.of(context).uri.path,
    );
    context.push(adapted);
  }

  String? _routeFor(AppNotification n) {
    if (n.directThreadId != null && n.directThreadId!.isNotEmpty) {
      return '/direct/${n.directThreadId}';
    }
    // Phase 6.1 — SPACE_ACTIVITY notifications carry a `slug` payload
    // pointing at the followed space.
    if (n.type.toUpperCase() == 'SPACE_ACTIVITY') {
      final slug = n.payload['slug']?.toString().trim() ?? '';
      if (slug.isNotEmpty) return '/spaces/$slug';
    }
    if (n.institutionPostId != null && n.institutionPostId!.isNotEmpty) {
      final inst = n.institutionPost?['institutionId']?.toString() ?? '';
      if (inst.isNotEmpty) {
        return '/institution/$inst/posts/${n.institutionPostId}';
      }
    }
    if (n.postId != null && n.postId!.isNotEmpty) {
      return '/posts/${n.postId}';
    }
    if (n.type.toUpperCase() == 'FOLLOW') {
      if (n.actorType == ActorType.institution) {
        final slug = n.actorInstitution?['slug']?.toString() ?? '';
        if (slug.isNotEmpty) return '/institutions/$slug';
      } else {
        final handle = n.actor?['handle']?.toString() ?? '';
        if (handle.isNotEmpty) return '/u/$handle';
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final pageAsync = ref.watch(notificationsListProvider);

    return AuraScaffold(
      showHeader: false,
      body: SafeArea(
        child: Column(
          children: [
            _Header(busy: _markingRead, onMarkAllRead: _markAllRead),
            Expanded(
              child: pageAsync.when(
                loading: () =>
                    const AuraLoadingState(message: 'Loading notifications…'),
                error: (e, _) => Center(
                  child: AuraErrorState(
                    title: 'Could not load notifications',
                    body: '$e',
                    action: AuraSecondaryButton(
                      label: 'Try again',
                      icon: Icons.refresh_rounded,
                      onPressed: () =>
                          ref.invalidate(notificationsListProvider),
                    ),
                  ),
                ),
                data: (page) {
                  if (page.items.isEmpty) {
                    return const Center(
                      child: AuraEmptyState(
                        icon: Icons.notifications_none_rounded,
                        title: 'You\'re all caught up',
                        body:
                            'New likes, replies, follows, reposts and messages will land here.',
                      ),
                    );
                  }
                  // Phase 6.1 — collapse runs of REPLY / THREAD_ACTIVITY
                  // notifications about the same parent post into a
                  // single rollup tile. Other types remain 1:1.
                  final groups = _groupNotifications(page.items);
                  return RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(notificationsListProvider);
                      ref.invalidate(unreadNotificationCountProvider);
                    },
                    child: ListView.separated(
                      padding: const EdgeInsets.all(AuraSpace.s12),
                      itemCount: groups.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AuraSpace.s8),
                      itemBuilder: (context, i) => _Tile(
                        group: groups[i],
                        onTap: () => _onTap(
                          groups[i].representative,
                          alsoMark: [
                            for (final x in groups[i].items.skip(1)) x.id,
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.busy, required this.onMarkAllRead});

  final bool busy;
  final VoidCallback onMarkAllRead;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AuraSpace.s14,
        AuraSpace.s14,
        AuraSpace.s14,
        AuraSpace.s8,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: const Icon(
              Icons.arrow_back_rounded,
              size: 20,
              color: AuraSurface.muted,
            ),
          ),
          const SizedBox(width: AuraSpace.s10),
          const Text('Notifications', style: AuraText.headline),
          const Spacer(),
          AuraSecondaryButton(
            label: busy ? 'Working…' : 'Mark all read',
            icon: Icons.done_all_rounded,
            onPressed: busy ? null : onMarkAllRead,
          ),
        ],
      ),
    );
  }
}

/// Phase 6.1 — rollup container.
///
/// Holds 1+ notifications that should render as a single tile. Single-
/// notification groups behave exactly like the old per-row rendering.
/// Multi-notification groups show a "X new replies in this discussion"
/// summary using the most-recent entry as the representative.
class _TileGroup {
  _TileGroup(this.items);
  final List<AppNotification> items;
  bool get isGroup => items.length > 1;
  AppNotification get representative => items.first;
}

/// Walk a freshly-fetched (newest-first) notifications list and merge
/// runs of same-parent REPLY / THREAD_ACTIVITY entries. We only collapse
/// when the run is contiguous in the timeline so distant duplicates
/// stay separate rows. Other types pass through 1:1.
List<_TileGroup> _groupNotifications(List<AppNotification> items) {
  final out = <_TileGroup>[];
  for (final n in items) {
    final type = n.type.toUpperCase();
    final groupable = type == 'REPLY' || type == 'THREAD_ACTIVITY';
    if (groupable && out.isNotEmpty) {
      final last = out.last;
      final lastType = last.representative.type.toUpperCase();
      final samePost = (n.postId ?? '').isNotEmpty &&
          n.postId == last.representative.postId;
      final sameInst = (n.institutionPostId ?? '').isNotEmpty &&
          n.institutionPostId == last.representative.institutionPostId;
      if (lastType == type && (samePost || sameInst)) {
        last.items.add(n);
        continue;
      }
    }
    out.add(_TileGroup([n]));
  }
  return out;
}

class _Tile extends StatelessWidget {
  const _Tile({required this.group, required this.onTap});

  final _TileGroup group;
  final VoidCallback onTap;

  AppNotification get notification => group.representative;

  String _label() {
    final actorName = notification.isInstitutionVoice
        ? (notification.actorInstitution?['name']?.toString() ?? 'Institution')
        : (notification.actor?['displayName']?.toString() ??
            notification.actor?['handle']?.toString() ??
            'Someone');
    // Rollup label first — overrides per-type wording when multiple.
    if (group.isGroup) {
      final n = group.items.length;
      final type = notification.type.toUpperCase();
      if (type == 'THREAD_ACTIVITY') {
        return '$n new replies in a discussion you follow';
      }
      return '$n new replies in this discussion';
    }
    switch (notification.type.toUpperCase()) {
      case 'LIKE':
        return '$actorName liked your post';
      case 'REPLY':
        return '$actorName replied to your post';
      case 'REPOST':
        return '$actorName reposted your post';
      case 'FOLLOW':
        return '$actorName started following you';
      case 'MESSAGE':
        return '$actorName sent you a message';
      case 'MENTION':
        return '$actorName mentioned you';
      case 'THREAD_ACTIVITY':
        return '$actorName replied in a discussion you follow';
      case 'SPACE_ACTIVITY':
        final spaceName =
            notification.payload['spaceName']?.toString().trim() ?? '';
        return spaceName.isNotEmpty
            ? '$actorName posted in $spaceName'
            : '$actorName posted in a space you follow';
      default:
        return '$actorName interacted with your content';
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = notification.isInstitutionVoice
        ? (notification.actorInstitution?['logoUrl']?.toString() ?? '')
        : (notification.actor?['avatarUrl']?.toString() ?? '');
    final fallback = notification.isInstitutionVoice
        ? ((notification.actorInstitution?['name']?.toString() ?? 'I')
            .substring(0, 1)
            .toUpperCase())
        : ((notification.actor?['displayName']?.toString() ??
                notification.actor?['handle']?.toString() ??
                'U')
            .substring(0, 1)
            .toUpperCase());
    final snippet = notification.payload['snippet']?.toString() ?? '';

    // For grouped tiles, the row is "unread" when any underlying entry
    // is unread — so the wash persists until the user opens the post.
    final allRead = group.items.every((e) => e.isRead);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AuraRadius.md),
      child: Container(
        padding: const EdgeInsets.all(AuraSpace.s12),
        decoration: BoxDecoration(
          color: allRead ? AuraSurface.subtle : AuraSurface.accentSoft,
          borderRadius: BorderRadius.circular(AuraRadius.md),
          border: Border.all(color: AuraSurface.divider),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AuraSurface.accentSoft,
                border: Border.all(color: AuraSurface.divider),
              ),
              child: imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _initialFallback(fallback),
                    )
                  : _initialFallback(fallback),
            ),
            const SizedBox(width: AuraSpace.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _label(),
                    style:
                        AuraText.body.copyWith(fontWeight: FontWeight.w700),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (snippet.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      snippet,
                      style: AuraText.small
                          .copyWith(color: AuraSurface.muted),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AuraSpace.s8),
            Text(
              _formatRelative(notification.createdAt),
              style: AuraText.micro.copyWith(color: AuraSurface.faint),
            ),
          ],
        ),
      ),
    );
  }

  Widget _initialFallback(String fallback) {
    return Center(
      child: Text(
        fallback,
        style: AuraText.small.copyWith(
          color: AuraSurface.accentText,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

String _formatRelative(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inSeconds < 60) return 'now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}h';
  if (diff.inDays < 7) return '${diff.inDays}d';
  final yyyy = dt.year.toString().padLeft(4, '0');
  final mm = dt.month.toString().padLeft(2, '0');
  final dd = dt.day.toString().padLeft(2, '0');
  return '$yyyy-$mm-$dd';
}
