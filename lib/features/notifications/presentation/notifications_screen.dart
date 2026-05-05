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

  Future<void> _onTap(AppNotification n) async {
    // Mark this row as read first (best-effort).
    try {
      await ref.read(notificationsRepositoryProvider).markRead([n.id]);
      ref.invalidate(notificationsListProvider);
      ref.invalidate(unreadNotificationCountProvider);
    } catch (_) {}

    if (!mounted) return;
    final route = _routeFor(n);
    if (route == null) return;
    context.push(route);
  }

  String? _routeFor(AppNotification n) {
    if (n.directThreadId != null && n.directThreadId!.isNotEmpty) {
      return '/direct/${n.directThreadId}';
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
                  return RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(notificationsListProvider);
                      ref.invalidate(unreadNotificationCountProvider);
                    },
                    child: ListView.separated(
                      padding: const EdgeInsets.all(AuraSpace.s12),
                      itemCount: page.items.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AuraSpace.s8),
                      itemBuilder: (context, i) => _Tile(
                        notification: page.items[i],
                        onTap: () => _onTap(page.items[i]),
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

class _Tile extends StatelessWidget {
  const _Tile({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  String _label() {
    final actorName = notification.isInstitutionVoice
        ? (notification.actorInstitution?['name']?.toString() ?? 'Institution')
        : (notification.actor?['displayName']?.toString() ??
            notification.actor?['handle']?.toString() ??
            'Someone');
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

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AuraRadius.md),
      child: Container(
        padding: const EdgeInsets.all(AuraSpace.s12),
        decoration: BoxDecoration(
          color: notification.isRead
              ? AuraSurface.subtle
              : AuraSurface.accentSoft,
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
