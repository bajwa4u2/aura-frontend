import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/route_targets.dart';
import '../../../core/communication/communication_resolver.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../updates/providers.dart';
import '../../correspondence/data/threads_repository.dart';

class ActivityScreen extends ConsumerStatefulWidget {
  const ActivityScreen({super.key});

  @override
  ConsumerState<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends ConsumerState<ActivityScreen> {
  static const _resolver = CommunicationResolver();

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

    final isRealtimeActivity = realtimeType.startsWith('REALTIME_') ||
        deeplink.startsWith('/realtime') ||
        realtimeSessionId.isNotEmpty;

    if (communicationTarget.owner == CommunicationOwner.thread &&
        (communicationTarget.threadId ?? '').isNotEmpty) {
      await _openThreadTarget(
        threadId: communicationTarget.threadId!,
        spaceIdHint: communicationTarget.spaceId,
        sessionIdHint: communicationTarget.sessionId,
        shouldJoin: isRealtimeActivity ||
            (communicationTarget.attention ?? '').toUpperCase() == 'INTERRUPT' ||
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
        context.push(_withLiveQuery(
          deeplink,
          sessionId: realtimeSessionId,
          shouldJoin: true,
        ));
      }
      return;
    }

    if (deeplink.isNotEmpty) {
      if (deeplink.startsWith('/threads/')) {
        final idFromLink = deeplink.substring('/threads/'.length).split('?').first.trim();
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
        final idFromLink = deeplink.substring('/spaces/'.length).split('?').first.trim();
        if (idFromLink.isNotEmpty) {
          context.push(_withLiveQuery(
            '/me/correspondence/$idFromLink',
            sessionId: realtimeSessionId,
            shouldJoin: isRealtimeActivity,
          ));
          return;
        }
      }

      if (!deeplink.startsWith('/realtime')) {
        context.push(_withLiveQuery(
          deeplink,
          sessionId: realtimeSessionId,
          shouldJoin: isRealtimeActivity,
        ));
      }
      return;
    }

    switch (type) {
      case 'FOLLOW_REQUEST':
        context.push('/me/follow-requests');
        return;
      case 'FOLLOW_ACCEPTED':
      case 'FOLLOW':
        if (handle.isNotEmpty) context.push('/u/$handle');
        return;
      case 'LIKE':
      case 'SAVE':
      case 'REPLY':
      case 'REPOST':
      case 'MENTION':
      case 'POST_PUBLISHED':
        if (postId.isNotEmpty) {
          context.push('/posts/$postId');
          return;
        }
        if (handle.isNotEmpty) context.push('/u/$handle');
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
          context.push('/posts/$postId');
          return;
        }
        if (handle.isNotEmpty) {
          context.push('/u/$handle');
          return;
        }
        if (spaceId.isNotEmpty && threadId.isNotEmpty) {
          context.push(_withLiveQuery(
            '/me/correspondence/$spaceId/thread/$threadId',
            sessionId: realtimeSessionId,
            shouldJoin: isRealtimeActivity,
          ));
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
      context.push(_withLiveQuery(
        '/me/correspondence/$cleanSpaceId/thread/$cleanThreadId',
        sessionId: cleanSessionId,
        shouldJoin: shouldJoin,
      ));
      return;
    }

    try {
      final thread = await ref.read(threadsRepositoryProvider).getThread(cleanThreadId);
      if (!mounted) return;

      final resolvedSpaceId = _firstNonEmpty([
        _stringOf(thread['spaceId']),
        _stringOf(thread['space_id']),
      ]);

      if (resolvedSpaceId.isNotEmpty) {
        context.push(_withLiveQuery(
          '/me/correspondence/$resolvedSpaceId/thread/$cleanThreadId',
          sessionId: cleanSessionId,
          shouldJoin: shouldJoin,
        ));
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
    final items = state.items;
    final unreadCount = state.unreadCount;

    return AuraScaffold(
      showHeader: false,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: RefreshIndicator(
              onRefresh: () =>
                  ref.read(notificationsControllerProvider.notifier).refresh(force: true),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AuraSpace.s16,
                  AuraSpace.s16,
                  AuraSpace.s16,
                  AuraSpace.s24,
                ),
                children: [
                  _ActivityHeader(
                    unreadCount: unreadCount,
                    onMarkAllRead: items.isEmpty ? null : _markAllRead,
                    markingAllRead: state.isRefreshing,
                  ),
                  const SizedBox(height: AuraSpace.s16),
                  if (state.isLoading)
                    const _ActivityLoadingState()
                  else if ((state.error ?? '').isNotEmpty)
                    _ActivityErrorState(
                      message: state.error!,
                      onRetry: () =>
                          ref.read(notificationsControllerProvider.notifier).refresh(force: true),
                    )
                  else if (items.isEmpty)
                    const _ActivityEmptyState()
                  else ...[
                    for (final item in items)
                      _ActivityTile(
                        item: item,
                        onTap: () => _handleTap(item),
                      ),
                    if ((state.nextCursor ?? '').isNotEmpty) ...[
                      const SizedBox(height: AuraSpace.s16),
                      Center(
                        child: OutlinedButton(
                          onPressed: state.isLoadingMore
                              ? null
                              : () => ref
                                  .read(notificationsControllerProvider.notifier)
                                  .loadMore(),
                          child: Text(state.isLoadingMore ? 'Loading…' : 'Load more'),
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Activity', style: AuraText.title),
              const SizedBox(height: AuraSpace.s6),
              Text(
                unreadCount > 0 ? '$unreadCount unread' : 'All caught up',
                style: AuraText.small.copyWith(color: AuraSurface.muted),
              ),
            ],
          ),
        ),
        const SizedBox(width: AuraSpace.s12),
        OutlinedButton(
          onPressed: markingAllRead ? null : onMarkAllRead,
          child: Text(markingAllRead ? 'Marking…' : 'Mark all read'),
        ),
      ],
    );
  }
}

class _ActivityLoadingState extends StatelessWidget {
  const _ActivityLoadingState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AuraSpace.s32),
      child: Column(
        children: const [
          SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
        ],
      ),
    );
  }
}

class _ActivityErrorState extends StatelessWidget {
  const _ActivityErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AuraSpace.s32),
      child: Column(
        children: [
          const Icon(Icons.error_outline, size: 28, color: AuraSurface.muted),
          const SizedBox(height: AuraSpace.s12),
          Text(message, style: AuraText.small.copyWith(color: AuraSurface.muted)),
          const SizedBox(height: AuraSpace.s16),
          OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
        ],
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
          const Icon(Icons.notifications_none, size: 32, color: AuraSurface.muted),
          const SizedBox(height: AuraSpace.s12),
          Text('No activity yet.', style: AuraText.small.copyWith(color: AuraSurface.muted)),
        ],
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({
    required this.item,
    required this.onTap,
  });

  final Map<String, dynamic> item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final actor = _mapOf(item['actor']);
    final type = _stringOf(item['type']).toUpperCase();
    final title = _buildTitle(item);
    final subtitle = _buildSubtitle(item);
    final timeLabel = _timeAgoLabel(item['createdAt']);
    final unread = _stringOf(item['readAt']).isEmpty;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AuraSpace.s14),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AuraSurface.divider)),
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
                      fontWeight: unread ? FontWeight.w700 : FontWeight.w600,
                      color: AuraSurface.ink,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: AuraText.small.copyWith(color: AuraSurface.muted),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AuraSpace.s8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(timeLabel, style: AuraText.small.copyWith(color: AuraSurface.muted)),
                if (unread) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AuraSurface.ink,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ],
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
    if (type == 'SYSTEM') {
      return Icons.videocam_outlined;
    }
    switch (type) {
      case 'FOLLOW':
      case 'FOLLOW_REQUEST':
      case 'FOLLOW_ACCEPTED':
        return Icons.person_add_alt_1_outlined;
      case 'REPLY':
      case 'MENTION':
        return Icons.reply_outlined;
      case 'REPOST':
        return Icons.repeat;
      case 'LIKE':
        return Icons.favorite_border;
      case 'SAVE':
        return Icons.bookmark_border;
      case 'SPACE_INVITE':
      case 'THREAD_INVITE':
      case 'INVITE_ACCEPTED':
        return Icons.mail_outline;
      case 'POST_PUBLISHED':
        return Icons.check_circle_outline;
      case 'ANNOUNCEMENT_PUBLISHED':
        return Icons.campaign_outlined;
      case 'MESSAGE_RECEIVED':
        return Icons.mail_outline;
      case 'POST_PUBLISH_FAILED':
        return Icons.error_outline;
      default:
        return Icons.notifications_none;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AuraSurface.card,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AuraSurface.divider),
          ),
          child: avatarUrl.isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: Image.network(
                    avatarUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Icon(
                      _iconForType(),
                      size: 18,
                      color: AuraSurface.ink,
                    ),
                  ),
                )
              : Icon(_iconForType(), size: 18, color: AuraSurface.ink),
        ),
        if (unread)
          Positioned(
            right: -1,
            top: -1,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: AuraSurface.ink,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AuraSurface.page, width: 1.5),
              ),
            ),
          ),
      ],
    );
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
  final realtimeType = _firstNonEmpty([
    _stringOf(data['realtimeType']).toUpperCase(),
    _stringOf(data['notificationKind']).toUpperCase(),
  ]);

  if (realtimeType == 'REALTIME_INVITE') {
    return '$actorName invited you to join live here';
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
      return title.isNotEmpty ? title : 'Update';
    default:
      return 'Update';
  }
}

String _buildSubtitle(Map<String, dynamic> item) {
  final type = _stringOf(item['type']).toUpperCase();
  final post = _mapOf(item['post']);
  final data = _mapOf(item['data']);
  final realtimeType = _firstNonEmpty([
    _stringOf(data['realtimeType']).toUpperCase(),
    _stringOf(data['notificationKind']).toUpperCase(),
  ]);

  final customMessage = _firstNonEmpty([
    _stringOf(data['secondaryText']),
    _stringOf(data['message']),
    _stringOf(data['body']),
  ]);
  if (customMessage.isNotEmpty) return customMessage;

  final postText = _stringOf(post['text']);
  if (postText.isNotEmpty) return _truncate(postText, 120);

  if (realtimeType == 'REALTIME_INVITE') {
    final roomTitle = _firstNonEmpty([
      _stringOf(data['roomTitle']),
      _stringOf(item['title']),
    ]);
    return roomTitle.isNotEmpty ? 'Open $roomTitle in correspondence' : 'Return to correspondence';
  }

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
      return 'Open space';
    case 'THREAD_INVITE':
    case 'MESSAGE_RECEIVED':
      return 'Open conversation';
    case 'INVITE_ACCEPTED':
    case 'INVITE_DECLINED':
    case 'INVITE_REVOKED':
      return 'Open correspondence';
    case 'ANNOUNCEMENT_PUBLISHED':
      return 'Read announcement';
    case 'POST_PUBLISH_FAILED':
      return 'Return to presence';
    default:
      return '';
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
