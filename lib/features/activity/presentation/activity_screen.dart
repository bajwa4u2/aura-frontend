import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/net/dio_provider.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';

class ActivityScreen extends ConsumerStatefulWidget {
  const ActivityScreen({super.key});

  @override
  ConsumerState<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends ConsumerState<ActivityScreen> {
  bool _loading = true;
  bool _markingAllRead = false;
  String? _error;
  List<Map<String, dynamic>> _items = const [];
  String? _nextCursor;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get('/notifications');
      final payload = _normalizePayload(response.data);

      if (!mounted) return;
      setState(() {
        _items = payload.items;
        _nextCursor = payload.nextCursor;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load activity right now.';
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    final cursor = _nextCursor;
    if (cursor == null || cursor.isEmpty) return;

    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get(
        '/notifications',
        queryParameters: {'cursor': cursor},
      );
      final payload = _normalizePayload(response.data);
      final existingIds = _items.map((e) => _stringOf(e['id'])).where((e) => e.isNotEmpty).toSet();
      final merged = <Map<String, dynamic>>[..._items];

      for (final item in payload.items) {
        final id = _stringOf(item['id']);
        if (id.isEmpty || existingIds.contains(id)) continue;
        merged.add(item);
      }

      if (!mounted) return;
      setState(() {
        _items = merged;
        _nextCursor = payload.nextCursor;
      });
    } catch (_) {
      // Keep the current list stable. We do not collapse the screen for pagination failure.
    }
  }

  Future<void> _markAllRead() async {
    if (_markingAllRead || _items.isEmpty) return;

    setState(() => _markingAllRead = true);

    try {
      final dio = ref.read(dioProvider);
      await dio.post('/notifications/read-all');

      if (!mounted) return;
      setState(() {
        _items = _items
            .map(
              (item) => {
                ...item,
                'readAt': item['readAt'] ?? DateTime.now().toIso8601String(),
              },
            )
            .toList(growable: false);
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not mark activity as read.')),
      );
    } finally {
      if (mounted) {
        setState(() => _markingAllRead = false);
      }
    }
  }

  Future<void> _handleTap(Map<String, dynamic> item) async {
    final id = _stringOf(item['id']);
    final readAt = item['readAt'];

    if (id.isNotEmpty && (readAt == null || _stringOf(readAt).isEmpty)) {
      try {
        final dio = ref.read(dioProvider);
        await dio.post('/notifications/$id/read');
        if (mounted) {
          setState(() {
            _items = _items
                .map(
                  (entry) => _stringOf(entry['id']) == id
                      ? {
                          ...entry,
                          'readAt': DateTime.now().toIso8601String(),
                        }
                      : entry,
                )
                .toList(growable: false);
          });
        }
      } catch (_) {
        // Navigation should still proceed.
      }
    }

    if (!mounted) return;
    _navigateFromActivity(item);
  }

  void _navigateFromActivity(Map<String, dynamic> item) {
    final type = _stringOf(item['type']).toUpperCase();
    final actor = _mapOf(item['actor']);
    final data = _mapOf(item['data']);

    final actorHandle = _stringOf(actor['handle']);
    final targetHandle = _stringOf(data['targetHandle']);
    final handle = targetHandle.isNotEmpty ? targetHandle : actorHandle;

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

    switch (type) {
      case 'FOLLOW_REQUEST':
        context.push('/me/follow-requests');
        return;
      case 'FOLLOW_ACCEPTED':
      case 'FOLLOW':
        if (handle.isNotEmpty) {
          context.push('/u/$handle');
        }
        return;
      case 'LIKE':
      case 'REPLY':
      case 'REPOST':
      case 'MENTION':
      case 'POST_PUBLISHED':
        if (postId.isNotEmpty) {
          context.push('/posts/$postId');
          return;
        }
        if (handle.isNotEmpty) {
          context.push('/u/$handle');
        }
        return;
      case 'POST_PUBLISH_FAILED':
        context.push('/me');
        return;
      case 'SPACE_INVITE':
      case 'INVITE_ACCEPTED':
        if (spaceId.isNotEmpty) {
          context.push('/me/correspondence/$spaceId');
        }
        return;
      case 'THREAD_INVITE':
        if (spaceId.isNotEmpty && threadId.isNotEmpty) {
          context.push('/me/correspondence/$spaceId/thread/$threadId');
          return;
        }
        if (spaceId.isNotEmpty) {
          context.push('/me/correspondence/$spaceId');
        }
        return;
      case 'SYSTEM':
        if (postId.isNotEmpty) {
          context.push('/posts/$postId');
          return;
        }
        context.push('/me');
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
          context.push('/me/correspondence/$spaceId/thread/$threadId');
          return;
        }
        if (spaceId.isNotEmpty) {
          context.push('/me/correspondence/$spaceId');
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AuraSurface.page,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: RefreshIndicator(
              onRefresh: _loadInitial,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AuraSpace.s16,
                  AuraSpace.s16,
                  AuraSpace.s16,
                  AuraSpace.s24,
                ),
                children: [
                  _ActivityHeader(
                    onMarkAllRead: _items.isEmpty ? null : _markAllRead,
                    markingAllRead: _markingAllRead,
                  ),
                  const SizedBox(height: AuraSpace.s16),
                  if (_loading)
                    const _ActivityLoadingState()
                  else if (_error != null)
                    _ActivityErrorState(
                      message: _error!,
                      onRetry: _loadInitial,
                    )
                  else if (_items.isEmpty)
                    const _ActivityEmptyState()
                  else ...[
                    for (final item in _items)
                      _ActivityTile(
                        item: item,
                        onTap: () => _handleTap(item),
                      ),
                    if (_nextCursor != null && _nextCursor!.isNotEmpty) ...[
                      const SizedBox(height: AuraSpace.s16),
                      Center(
                        child: OutlinedButton(
                          onPressed: _loadMore,
                          child: const Text('Load more'),
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

class _ActivityPayload {
  const _ActivityPayload({
    required this.items,
    required this.nextCursor,
  });

  final List<Map<String, dynamic>> items;
  final String? nextCursor;
}

_ActivityPayload _normalizePayload(dynamic raw) {
  final map = _mapOf(raw);
  final rawItems = map['items'];
  final items = <Map<String, dynamic>>[];

  if (rawItems is List) {
    for (final entry in rawItems) {
      final normalized = _mapOf(entry);
      if (normalized.isNotEmpty) items.add(normalized);
    }
  }

  final nextCursor = _stringOf(map['nextCursor']);
  return _ActivityPayload(
    items: items,
    nextCursor: nextCursor.isEmpty ? null : nextCursor,
  );
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
    required this.onMarkAllRead,
    required this.markingAllRead,
  });

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
              Text(
                'Activity',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AuraSurface.ink,
                      fontWeight: FontWeight.w700,
                    ) ??
                    const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AuraSurface.ink,
                    ),
              ),
              const SizedBox(height: AuraSpace.s8),
              Text(
                'Signals around your writing, presence, and correspondence.',
                style: AuraText.small.copyWith(
                  color: AuraSurface.muted,
                ),
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
          SizedBox(height: AuraSpace.s16),
          _MutedBodyText('Loading activity…'),
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
          const Icon(
            Icons.error_outline,
            size: 28,
            color: AuraSurface.muted,
          ),
          const SizedBox(height: AuraSpace.s12),
          _MutedBodyText(message),
          const SizedBox(height: AuraSpace.s16),
          OutlinedButton(
            onPressed: onRetry,
            child: const Text('Try again'),
          ),
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
        children: const [
          Icon(
            Icons.notifications_none,
            size: 32,
            color: AuraSurface.muted,
          ),
          SizedBox(height: AuraSpace.s12),
          _MutedBodyText('No activity yet.'),
          SizedBox(height: AuraSpace.s8),
          _MutedCaptionText(
            'Replies, follows, invitations, and publishing events will appear here.',
          ),
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
          border: Border(
            bottom: BorderSide(color: AuraSurface.divider),
          ),
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
                      style: AuraText.small.copyWith(
                        color: AuraSurface.muted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AuraSpace.s8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  timeLabel,
                  style: AuraText.small.copyWith(
                    color: AuraSurface.muted,
                  ),
                ),
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
      case 'SPACE_INVITE':
      case 'THREAD_INVITE':
      case 'INVITE_ACCEPTED':
        return Icons.mail_outline;
      case 'POST_PUBLISHED':
        return Icons.check_circle_outline;
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
              : Icon(
                  _iconForType(),
                  size: 18,
                  color: AuraSurface.ink,
                ),
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
                border: Border.all(
                  color: AuraSurface.page,
                  width: 1.5,
                ),
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

  switch (type) {
    case 'FOLLOW_REQUEST':
      return '$actorName sent you a follow request';
    case 'FOLLOW_ACCEPTED':
      return '$actorName accepted your follow request';
    case 'FOLLOW':
      return '$actorName followed you';
    case 'LIKE':
      return '$actorName appreciated your post';
    case 'REPLY':
      return '$actorName replied to your post';
    case 'REPOST':
      return '$actorName reposted your post';
    case 'MENTION':
      return '$actorName mentioned you';
    case 'SPACE_INVITE':
      return '$actorName invited you to a space';
    case 'THREAD_INVITE':
      return '$actorName invited you to a thread';
    case 'INVITE_ACCEPTED':
      return '$actorName accepted your invitation';
    case 'POST_PUBLISHED':
      return 'Your post was published';
    case 'POST_PUBLISH_FAILED':
      return 'A post could not be published';
    case 'SYSTEM':
      final title = _stringOf(data['title']);
      return title.isNotEmpty ? title : 'System activity';
    default:
      return 'Activity';
  }
}

String _buildSubtitle(Map<String, dynamic> item) {
  final type = _stringOf(item['type']).toUpperCase();
  final post = _mapOf(item['post']);
  final data = _mapOf(item['data']);

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
      return 'View profile';
    case 'REPLY':
    case 'LIKE':
    case 'REPOST':
    case 'MENTION':
    case 'POST_PUBLISHED':
      return 'Open post';
    case 'SPACE_INVITE':
      return 'Open space';
    case 'THREAD_INVITE':
      return 'Open thread';
    case 'INVITE_ACCEPTED':
      return 'Open correspondence';
    case 'POST_PUBLISH_FAILED':
      return 'Return to your profile';
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

class _MutedBodyText extends StatelessWidget {
  const _MutedBodyText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: AuraText.small.copyWith(
        color: AuraSurface.muted,
      ),
    );
  }
}

class _MutedCaptionText extends StatelessWidget {
  const _MutedCaptionText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: AuraText.small.copyWith(
        color: AuraSurface.muted,
        height: 1.45,
      ),
    );
  }
}
